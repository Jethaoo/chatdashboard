import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/auth_error_messages.dart';
import '../utils/ui_feedback.dart';
import '../widgets/app_brand_title.dart';

enum _AuthMode { signIn, signUp }

class LoginView extends StatefulWidget {
  final String title;
  const LoginView({super.key, required this.title});

  @override
  LoginViewState createState() => LoginViewState();
}

class LoginViewState extends State<LoginView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  _AuthMode _mode = _AuthMode.signIn;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String value) {
    final trimmed = value.trim();
    if (_mode == _AuthMode.signUp && trimmed.isEmpty) {
      return 'Enter your name.';
    }
    return null;
  }

  String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your email.';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<void> _submit() async {
    final nameErr = _validateName(_nameCtrl.text);
    final emailErr = _validateEmail(_emailCtrl.text);
    final passErr = _validatePassword(_passwordCtrl.text);
    if (nameErr != null || emailErr != null || passErr != null) {
      showTopErrorMessage(context, nameErr ?? emailErr ?? passErr!);
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (_mode == _AuthMode.signIn) {
        await auth.signIn(email, password);
      } else {
        await auth.signUp(email, password, name: name);
      }
    } catch (e) {
      if (!mounted) return;
      showTopErrorMessage(context, messageForAuthException(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final emailErr = _validateEmail(_emailCtrl.text);
    if (emailErr != null) {
      showTopErrorMessage(context, emailErr);
      return;
    }

    try {
      await Provider.of<AuthService>(context, listen: false)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      showTopSuccessMessage(
        context,
        'Password reset email sent. Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;
      showTopErrorMessage(context, messageForAuthException(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBrandTitle()),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _mode == _AuthMode.signIn ? 'Sign in' : 'Create account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment<_AuthMode>(
                    value: _AuthMode.signIn,
                    label: Text('Sign in'),
                  ),
                  ButtonSegment<_AuthMode>(
                    value: _AuthMode.signUp,
                    label: Text('Sign up'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const SizedBox(height: 24),
              if (_mode == _AuthMode.signUp) ...[
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              if (_mode == _AuthMode.signIn)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 12),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(_mode == _AuthMode.signIn ? 'Sign in' : 'Create account'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
