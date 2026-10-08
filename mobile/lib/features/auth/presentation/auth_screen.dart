import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/brand.dart';
import '../application/auth_controller.dart';
import '../domain/auth_session.dart';
import '../domain/auth_validators.dart';

enum AuthMode { login, register }

/// Що гравець уже ввів — переноситься між входом і реєстрацією.
@immutable
class AuthDraft {
  const AuthDraft({this.email = '', this.password = ''});

  final String email;
  final String password;
}

/// Вхід і реєстрація (docs/design/02-auth.html): одна форма, два режими.
/// Після успіху сюди не повертаємось — роутер сам веде на мету.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.mode, this.draft});

  final AuthMode mode;
  final AuthDraft? draft;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final _email = TextEditingController(text: widget.draft?.email ?? '');
  late final _password = TextEditingController(text: widget.draft?.password ?? '');
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;

  /// Після першої спроби помилки полів оновлюються наживо.
  bool _tried = false;
  String? _emailError;
  String? _passwordError;
  AuthFailure? _failure;

  bool get _isRegister => widget.mode == AuthMode.register;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _validate() {
    _emailError = AuthValidators.email(_email.text);
    _passwordError = AuthValidators.password(_password.text, forRegistration: _isRegister);
  }

  void _onChanged(String _) {
    if (!_tried && _failure == null) return;
    setState(() {
      _failure = null;
      if (_tried) _validate();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _tried = true;
      _failure = null;
      _validate();
    });
    if (_emailError != null || _passwordError != null) {
      (_emailError != null ? _emailFocus : _passwordFocus).requestFocus();
      return;
    }

    setState(() => _submitting = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_isRegister) {
        await auth.signUp(email: _email.text, password: _password.text);
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      TextInput.finishAutofillContext();
    } catch (error) {
      if (!mounted) return;
      final failure = error is AuthException ? error.failure : AuthFailure.server;
      setState(() {
        _submitting = false;
        _failure = failure;
      });
      // Найчастіше помилка саме в паролі.
      if (failure == AuthFailure.invalidCredentials) _passwordFocus.requestFocus();
    }
  }

  void _switchMode({bool keepPassword = true}) {
    context.go(
      _isRegister ? AppRoutes.login : AppRoutes.register,
      extra: AuthDraft(email: _email.text, password: keepPassword ? _password.text : ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.metrics;
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(m.space4, m.space4, m.space4, 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - m.space4 - 36),
              child: IntrinsicHeight(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const MangoBadge(),
                          SizedBox(width: m.space3),
                          const Wordmark(),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(_isRegister ? 'Реєстрація' : 'Вхід', style: text.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Потрібні лише email і пароль.'
                            : 'Увійдіть, щоб бачити мету патча й AI-білди героїв.',
                        style: text.bodyMedium?.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(height: 28),
                      _Field(
                        label: 'Email',
                        child: TextField(
                          key: const Key('auth-email'),
                          controller: _email,
                          focusNode: _emailFocus,
                          enabled: !_submitting,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: _onChanged,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: InputDecoration(
                            hintText: 'player@example.com',
                            errorText: _emailError,
                          ),
                        ),
                      ),
                      SizedBox(height: m.space4),
                      _Field(
                        label: 'Пароль',
                        child: TextField(
                          key: const Key('auth-password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_submitting,
                          obscureText: _obscure,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: [
                            _isRegister ? AutofillHints.newPassword : AutofillHints.password,
                          ],
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: _onChanged,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            errorText: _passwordError,
                            helperText: _isRegister
                                ? 'Щонайменше ${AuthValidators.minPasswordLength} символів'
                                : null,
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Показати пароль' : 'Сховати пароль',
                              isSelected: !_obscure,
                              icon: const Icon(Icons.visibility_outlined),
                              selectedIcon: const Icon(Icons.visibility_off_outlined),
                              onPressed: _submitting ? null : () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                      ),
                      if (_failure != null) ...[
                        SizedBox(height: m.space4),
                        _ErrorBanner(
                          failure: _failure!,
                          onLoginWithEmail: () => _switchMode(keepPassword: false),
                        ),
                      ],
                      SizedBox(height: m.space4),
                      FilledButton(
                        key: const Key('auth-submit'),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(_isRegister ? 'Створюємо акаунт…' : 'Входимо…'),
                                ],
                              )
                            : Text(_isRegister ? 'Створити акаунт' : 'Увійти'),
                      ),
                      SizedBox(height: m.space1),
                      // Wrap, а не Row: на 320 dp і з великим шрифтом посилання переноситься.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isRegister ? 'Вже маєте акаунт?' : 'Немає акаунта?',
                            style: text.bodyMedium?.copyWith(color: colors.textMuted),
                          ),
                          TextButton(
                            onPressed: _submitting ? null : _switchMode,
                            child: Text(_isRegister ? 'Увійти' : 'Зареєструватися'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(height: m.space6),
                      Text(
                        'Мету рахує OpenDota, білди пише Gemini.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(color: colors.textSubtle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Підпис над полем, а не плаваючий: його видно й у заповненому полі.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600, fontVariations: wght(FontWeight.w600),
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.failure, required this.onLoginWithEmail});

  final AuthFailure failure;
  final VoidCallback onLoginWithEmail;

  String get _message => switch (failure) {
        AuthFailure.invalidCredentials =>
          'Невірний email або пароль. Перевірте, чи увімкнена англійська розкладка.',
        AuthFailure.emailTaken => 'Акаунт з цим email уже існує.',
        AuthFailure.invalidEmail => 'Сервер не прийняв цей email. Перевірте, чи немає в ньому помилки.',
        AuthFailure.passwordTooShort => 'Пароль закороткий: потрібно щонайменше 6 символів.',
        AuthFailure.passwordTooLong => 'Пароль задовгий: не більше 128 символів.',
        AuthFailure.invalidData => 'Сервер не прийняв ці дані. Перевірте email і пароль.',
        AuthFailure.network => 'Немає з’єднання з сервером. Перевірте інтернет і спробуйте ще раз.',
        AuthFailure.server => 'Сервер не відповідає. Спробуйте ще раз за хвилину.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(m.space3),
        decoration: BoxDecoration(
          color: colors.salve.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(m.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              failure == AuthFailure.network ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 18,
              color: colors.salve,
            ),
            SizedBox(width: m.space2 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_message, style: context.text.bodyMedium),
                  if (failure == AuthFailure.emailTaken)
                    TextButton(
                      onPressed: onLoginWithEmail,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(0, m.hitTarget),
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text('Увійти з цим email'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
