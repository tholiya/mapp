import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/api_exception.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/secure_store.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/field_error.dart';

/// Native login — mirrors react/app/login/page.tsx. Field-level errors render
/// inline below the inputs (project convention); a general auth failure shows a
/// banner above the form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _emailError;
  String? _passwordError;
  String? _banner;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _banner = null;
      _loading = true;
    });

    final auth = context.read<AuthService>();
    final session = context.read<SessionController>();
    final notifications = context.read<NotificationService>();
    final biometric = context.read<BiometricService>();
    final store = context.read<SecureStore>();

    try {
      await auth.login(_email.text, _password.text);

      // After login: request notification permission (best-effort).
      await notifications.requestPermission();

      // Enable biometric app-unlock by default when the device supports it.
      if (await biometric.isAvailable()) {
        await store.setBiometricEnabled(true);
      }

      await session.onLoginSuccess();
    } on ApiException catch (e) {
      if (!_applyFieldErrors(e)) {
        setState(() => _banner = e.message);
      }
    } catch (_) {
      setState(() => _banner = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Maps envelope `errors[]` onto the inputs. Returns true if any matched.
  bool _applyFieldErrors(ApiException e) {
    bool matched = false;
    for (final v in e.validationErrors) {
      if (v.field == 'email') {
        _emailError = v.message;
        matched = true;
      } else if (v.field == 'password') {
        _passwordError = v.message;
        matched = true;
      }
    }
    if (matched) setState(() {});
    return matched;
  }

  Future<void> _forgotPassword() async {
    // No backend reset endpoint yet — open the web app's login page so the user
    // can use the web reset flow once it exists. (See plan: forgot-password.)
    final uri = Uri.parse('${AppConfig.appUrl}/login');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const BrandLockup(),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BrandColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BrandColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_banner != null) ...[
                          _Banner(_banner!),
                          const SizedBox(height: 16),
                        ],
                        const _Label('Email address'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'admin@example.com',
                            errorText: null,
                            enabledBorder: _emailError != null
                                ? _errorBorder()
                                : null,
                          ),
                        ),
                        FieldError(_emailError),
                        const SizedBox(height: 16),
                        const _Label('Password'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _loading ? null : _submit(),
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            enabledBorder: _passwordError != null
                                ? _errorBorder()
                                : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: BrandColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        FieldError(_passwordError),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _errorBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BrandColors.danger),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: BrandColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _Banner extends StatelessWidget {
  final String message;
  const _Banner(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BrandColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BrandColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: BrandColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: BrandColors.danger, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
