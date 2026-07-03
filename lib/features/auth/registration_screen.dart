import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/logo_mark.dart';
import 'flowing_paths.dart';

/// Registration / sign-in screen — the first thing a new user sees, before
/// project linking and onboarding. Two-column: animated ember hero (left),
/// auth form (right). Google/GitHub buttons are decorative for the MVP.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.auth,
    required this.onAuthenticated,
  });

  final AuthService auth;
  final VoidCallback onAuthenticated;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  bool _signInMode = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _signInMode
        ? await widget.auth
            .signIn(email: _email.text, password: _password.text)
        : await widget.auth.register(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            confirm: _confirm.text,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      widget.onAuthenticated();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 5, child: _hero()),
        Expanded(flex: 4, child: _form()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Left — animated hero.
  // ---------------------------------------------------------------------------
  Widget _hero() {
    return Container(
      color: AppTheme.bgVoid,
      child: Stack(
        children: [
          const Positioned.fill(child: FlowingPaths()),
          Positioned(
            top: 28,
            left: 28,
            child: Row(children: [
              const LogoMark(size: 26),
              const SizedBox(width: 8),
              Text('Extra AI',
                  style: AppTheme.display(size: 15, weight: FontWeight.w600)),
            ]),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Point at what's wrong.\nGet the exact prompt to fix it.",
                  style: AppTheme.display(
                    size: 26,
                    weight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ).copyWith(fontStyle: FontStyle.italic, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text('Extra AI',
                    style: AppTheme.ui(size: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right — auth form.
  // ---------------------------------------------------------------------------
  Widget _form() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_signInMode ? 'Welcome back' : 'Get started',
                  style: AppTheme.display(size: 30, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                _signInMode
                    ? 'Sign in to your Extra AI account'
                    : 'Create your account to get started',
                style: AppTheme.ui(size: 13, color: AppTheme.textDim),
              ),
              const SizedBox(height: 22),

              // Decorative OAuth buttons (do not authenticate in the MVP).
              _oauthButton('Continue with Google', Icons.g_mobiledata),
              const SizedBox(height: 10),
              _oauthButton('Continue with GitHub', Icons.code),
              const SizedBox(height: 18),
              _orDivider(),
              const SizedBox(height: 18),

              if (!_signInMode) ...[
                _field('Full Name', _name),
                const SizedBox(height: 12),
              ],
              _field('Email Address', _email),
              const SizedBox(height: 12),
              _field('Password', _password,
                  obscure: !_showPassword,
                  toggleObscure: () =>
                      setState(() => _showPassword = !_showPassword),
                  obscured: !_showPassword),
              if (!_signInMode) ...[
                const SizedBox(height: 12),
                _field('Confirm Password', _confirm,
                    obscure: !_showConfirm,
                    toggleObscure: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    obscured: !_showConfirm),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        AppTheme.ui(size: 12, color: AppTheme.signalRed)),
              ],
              const SizedBox(height: 20),
              GradientButton(
                label: _busy
                    ? 'Please wait...'
                    : (_signInMode ? 'Sign In' : 'Create Account'),
                enabled: !_busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 16),
              Center(
                child: PressableScale(
                  onTap: () => setState(() {
                    _signInMode = !_signInMode;
                    _error = null;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: AppTheme.ui(size: 13, color: AppTheme.textDim),
                      children: [
                        TextSpan(
                            text: _signInMode
                                ? "Don't have an account? "
                                : 'Already have an account? '),
                        TextSpan(
                          text: _signInMode ? 'Create one' : 'Sign In',
                          style: AppTheme.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppTheme.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oauthButton(String label, IconData icon) {
    return PressableScale(
      onTap: () {}, // decorative — MVP does not wire real OAuth
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: AppTheme.ui(size: 13, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(children: [
      const Expanded(child: Divider(color: AppTheme.borderSubtle)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child:
            Text('OR', style: AppTheme.ui(size: 11, color: AppTheme.textDim)),
      ),
      const Expanded(child: Divider(color: AppTheme.borderSubtle)),
    ]);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    VoidCallback? toggleObscure,
    bool obscured = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: AppTheme.ui(size: 13),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.bgVoid.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: toggleObscure == null
                ? null
                : IconButton(
                    onPressed: toggleObscure,
                    icon: Icon(
                      obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                      color: AppTheme.textDim,
                    ),
                  ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderFocus),
            ),
          ),
        ),
      ],
    );
  }
}
