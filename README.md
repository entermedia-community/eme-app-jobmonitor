# agent_job_monitor

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running against the EME server

```
flutter run -d chrome --dart-define=EME_BASE_URL=http://localhost:8080
```

Sign in with your email: the server mails a 6-digit code, and this browser then registers a
non-extractable signing key (same scheme as `eme_app_fulservice`, see `web/emekey.js` and
`lib/core/auth`). Every request carries `X-tokentype: signature` + `X-token`; a 401 signs you out.
`--dart-define=EME_TOKEN=...` is an optional dev-only bearer token.

The server must allow CORS for the `X-tokentype` and `X-token` headers on `/site/mediadb/services/*`.
The BUK import panel reads `services/module/agentjob/buk/{status,runs,import}.json` and
`logs.json?jobid=buk_sync`. The BUK API token lives only on the server (`FULSERVICE_BUK_API_TOKEN`).
Never commit tokens or `sample.json` (real employee data).
