import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';

/// Email -> 6-digit code. Signing in also registers this browser's key, so later visits need no code.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on AuthException catch (e) {
      _error = _message(e);
    } catch (_) {
      _error = 'Could not reach the server.';
    }
    if (mounted) setState(() => _busy = false);
  }

  String _message(AuthException e) => switch (e.error) {
    AuthError.noUser => 'No account found for that email.',
    AuthError.sendFailed =>
      'Could not send the code${e.detail == null ? '' : ' (${e.detail})'}.',
    AuthError.noSecureKeys =>
      'This browser cannot create a secure key. Use https or localhost.',
    AuthError.badCode => e.detail ?? 'Wrong or expired code.',
  };

  Future<void> _sendCode() => _run(() async {
    await widget.auth.requestCode(_email.text);
    _codeSent = true;
  });

  Future<void> _login() =>
      _run(() => widget.auth.loginWithCode(_email.text, _code.text));

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'AGENT JOB MONITOR',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 16),
                    Text('Sign in', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      _codeSent
                          ? 'We sent a 6-digit code to ${_email.text.trim()}.'
                          : 'Enter your email and we will send you a one-time code.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('login-email'),
                      controller: _email,
                      enabled: !_codeSent && !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _sendCode(),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('login-code'),
                        controller: _code,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('login-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _busy
                          ? null
                          : (_codeSent ? _login : _sendCode),
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : (_codeSent ? 'Sign in' : 'Send code'),
                      ),
                    ),
                    if (_codeSent)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _codeSent = false;
                                _code.clear();
                                _error = null;
                              }),
                        child: const Text('Use a different email'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
