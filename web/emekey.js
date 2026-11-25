/*
 * emekey.js — browser key + signature handling for the Fulservice app.
 *
 * Mirrors the EME reference implementation so the server sees the same thing from this app as from the EME pages:
 *   plugins/community/html/default/authentication/authentication.js   (key generation, IndexedDB, signing)
 *   plugins/community/html/default/components/javascript/emedia/ajax/signedheaders.js (X-tokentype / X-token)
 *
 * Flow:
 *   1. createKey()      -> new Ed25519 (fallback P-256) key pair, private key non-extractable, kept as "pending".
 *                          Resolves {alg, publickey} where publickey is base64url X.509 (SPKI) for token.json.
 *   2. commit(user,id)  -> after token.json accepted the public key: the pending key becomes the current key.
 *   3. headers()        -> JSON string of {"X-tokentype":"signature","X-token":"<json>"} or "{}".
 *                          The signature is {username,key_id,timestamp,nonce,signature}; it is reused for 24 h
 *                          (kept in localStorage.emeSignature, same format as the EME pages) and re-signed after.
 *   4. clear()          -> forget the key and the signature (logout / server rejected the key).
 *
 * The signed message is: username + "\n" + key_id + "\n" + timestamp-millis + "\n" + nonce
 * The private key never leaves IndexedDB (stored as a CryptoKey object).
 */
(function () {
  "use strict";
  if (window.emeKey) return;

  var DB_NAME = "fulservicekey",
    STORE = "keys",
    CURRENT = "current",
    PENDING = "pending",
    SIGNATURE_KEY = "emeSignature",
    MAX_AGE = 24 * 60 * 60 * 1000;

  var ED = { name: "Ed25519" };
  var EC = { name: "ECDSA", namedCurve: "P-256" };

  function supported() {
    return !!(window.isSecureContext && window.crypto && crypto.subtle && window.indexedDB);
  }

  function b64url(buffer) {
    var bytes = new Uint8Array(buffer),
      s = "";
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  function nonce() {
    var bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    return Array.prototype.map
      .call(bytes, function (b) {
        return ("0" + b.toString(16)).slice(-2);
      })
      .join("");
  }

  /* ---------- IndexedDB ---------- */
  function openDb() {
    return new Promise(function (resolve, reject) {
      var req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = function () {
        req.result.createObjectStore(STORE);
      };
      req.onsuccess = function () {
        resolve(req.result);
      };
      req.onerror = function () {
        reject(req.error);
      };
    });
  }

  function dbRun(mode, action) {
    return openDb().then(function (db) {
      return new Promise(function (resolve, reject) {
        var tx = db.transaction(STORE, mode),
          result = action(tx.objectStore(STORE));
        tx.oncomplete = function () {
          db.close();
          resolve(result && result.result);
        };
        tx.onerror = function () {
          db.close();
          reject(tx.error);
        };
      });
    });
  }

  var get = function (k) {
    return dbRun("readonly", function (s) {
      return s.get(k);
    });
  };
  var put = function (k, v) {
    return dbRun("readwrite", function (s) {
      return s.put(v, k);
    });
  };
  var del = function (k) {
    return dbRun("readwrite", function (s) {
      return s.delete(k);
    });
  };

  /* ---------- signature cache (same shape as authentication.js / signedheaders.js) ---------- */
  function readSignature() {
    try {
      var v = JSON.parse(localStorage.getItem(SIGNATURE_KEY));
      return v && v.timestamp && v.nonce && v.signature && v.username && v.key_id ? v : null;
    } catch (e) {
      return null;
    }
  }
  function writeSignature(v) {
    try {
      localStorage.setItem(SIGNATURE_KEY, JSON.stringify(v));
    } catch (e) {}
  }
  function clearSignature() {
    try {
      localStorage.removeItem(SIGNATURE_KEY);
    } catch (e) {}
  }

  /* ---------- keys ---------- */
  function generate() {
    return crypto.subtle.generateKey(ED, false, ["sign", "verify"]).then(
      function (pair) {
        return { alg: "Ed25519", pair: pair };
      },
      function () {
        return crypto.subtle.generateKey(EC, false, ["sign", "verify"]).then(function (pair) {
          return { alg: "P-256", pair: pair };
        });
      },
    );
  }

  function sign(record, message) {
    var algo = record.alg === "Ed25519" ? ED : { name: "ECDSA", hash: "SHA-256" };
    return crypto.subtle
      .sign(algo, record.privateKey, new TextEncoder().encode(message))
      .then(b64url);
  }

  function signNew(record) {
    var ts = String(Date.now()),
      n = nonce();
    return sign(record, record.userid + "\n" + record.keyid + "\n" + ts + "\n" + n).then(function (signature) {
      var v = { username: record.userid, key_id: record.keyid, timestamp: ts, nonce: n, signature: signature };
      writeSignature(v);
      return v;
    });
  }

  window.emeKey = {
    supported: supported,

    // -> JSON string {alg, publickey}
    createKey: function () {
      if (!supported()) return Promise.reject(new Error("WebCrypto/IndexedDB need https or localhost"));
      return generate().then(function (g) {
        return put(PENDING, { alg: g.alg, privateKey: g.pair.privateKey }).then(function () {
          return crypto.subtle.exportKey("spki", g.pair.publicKey).then(function (spki) {
            return JSON.stringify({ alg: g.alg, publickey: b64url(spki) });
          });
        });
      });
    },

    // The server accepted the public key: the pending key is now the login key.
    commit: function (userid, keyid) {
      return get(PENDING).then(function (p) {
        if (!p) return false;
        clearSignature();
        return put(CURRENT, { userid: userid, keyid: keyid, alg: p.alg, privateKey: p.privateKey })
          .then(function () {
            return del(PENDING);
          })
          .then(function () {
            return true;
          });
      });
    },

    // -> JSON string {userid, keyid} or "" when there is no key
    current: function () {
      if (!supported()) return Promise.resolve("");
      return get(CURRENT).then(function (r) {
        return r ? JSON.stringify({ userid: r.userid, keyid: r.keyid }) : "";
      });
    },

    // -> JSON string of the headers for every request ("{}" without a key)
    headers: function () {
      if (!supported()) return Promise.resolve("{}");
      var v = readSignature();
      if (v && Date.now() - Number(v.timestamp) < MAX_AGE) {
        return Promise.resolve(JSON.stringify({ "X-tokentype": "signature", "X-token": JSON.stringify(v) }));
      }
      clearSignature();
      return get(CURRENT).then(function (record) {
        if (!record) return "{}";
        return signNew(record).then(function (s) {
          return JSON.stringify({ "X-tokentype": "signature", "X-token": JSON.stringify(s) });
        });
      });
    },

    // The server answered 401 to our signature: stop sending it (the key may be revoked)
    forgetSignature: function () {
      clearSignature();
      return Promise.resolve();
    },

    clear: function () {
      clearSignature();
      return del(CURRENT).then(function () {
        return del(PENDING);
      });
    },
  };
})();
