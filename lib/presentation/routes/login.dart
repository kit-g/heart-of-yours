import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/icons.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/logo.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with LoadingState<LoginPage> {
  late Future<bool> _isAppleSignNnAvailable;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordObscurityController = ValueNotifier<bool>(true);
  final _loginError = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();

    _isAppleSignNnAvailable = Auth.isAppleSignInAvailable();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:logInWithGoogle, :logInWithApple, :orConnector) = L.of(context);
    final ThemeData(textTheme: TextTheme(titleMedium: style)) = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Logo(),
                      ),
                      Expanded(
                        flex: 5,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: loader,
                          builder: (_, loading, child) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: switch (loading) {
                                false => child!,
                                true => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                              },
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 60.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _Form(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  onLogin: _logInWithEmail,
                                  obscurityController: _passwordObscurityController,
                                  error: _loginError,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(orConnector),
                                ),
                                Stack(
                                  children: [
                                    const Positioned(
                                      top: 0,
                                      bottom: 0,
                                      left: 24,
                                      child: Icon(CustomIcons.google),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _logIn(Auth.of(context).loginWithGoogle),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            logInWithGoogle,
                                            style: style,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                FutureBuilder<bool>(
                                  future: _isAppleSignNnAvailable,
                                  builder: (_, snapshot) {
                                    final AsyncSnapshot(:hasData, :hasError, data: available) = snapshot;
                                    bool hasAppleSignIn = _isIos(context) && !hasError && hasData && available!;
                                    return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 100),
                                      child: switch (hasAppleSignIn) {
                                        false => const SizedBox.shrink(),
                                        true => Stack(
                                            children: [
                                              const Positioned(
                                                top: 0,
                                                bottom: 0,
                                                left: 24,
                                                child: Icon(CustomIcons.appstore),
                                              ),
                                              OutlinedButton(
                                                onPressed: () => _logIn(Auth.of(context).loginWithApple),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      logInWithApple,
                                                      style: style,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      },
                                    );
                                  },
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
          },
        ),
      ),
    );
  }

  Future<void> _logIn(AsyncCallback callback) async {
    _loginError.value = null;
    final l = L.of(context);

    try {
      startLoading();
      await callback();
    } on AuthException catch (error) {
      final copy = switch (error.reason) {
        AuthExceptionReason.invalidEmail => l.invalidCredentials,
        AuthExceptionReason.wrongPassword => l.invalidCredentials,
        AuthExceptionReason.userNotFound => l.invalidCredentials,
        AuthExceptionReason.userDisabled => l.userDisabled,
        AuthExceptionReason.unknown => l.unknownError,
      };
      _loginError.value = copy;
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
    } finally {
      try {
        stopLoading();
      } catch (_) {
        //
      }
    }
  }

  Future<void> _logInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    return _logIn(
      () {
        return Auth.of(context).loginWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      },
    );
  }

  bool _isIos(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.iOS;
  }
}

class _Form extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onLogin;
  final ValueNotifier<bool> obscurityController;
  final ValueNotifier<String?> error;

  const _Form({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.obscurityController,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final L(:logIn, :email, :password, :cannotBeEmpty, :showPassword, :hidePassword, :forgotPassword) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    String? validator(String? value) {
      return (value?.isEmpty ?? true) ? cannotBeEmpty : null;
    }

    return Form(
      key: formKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: obscurityController,
        builder: (_, hide, __) {
          return Column(
            // spacing: 12,
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(hintText: email),
                keyboardType: TextInputType.emailAddress,
                validator: validator,
                autocorrect: false,
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                autocorrect: false,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: password,
                  suffixIcon: IconButton(
                    tooltip: hide ? showPassword : hidePassword,
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
                    onPressed: () {
                      obscurityController.value = !obscurityController.value;
                    },
                    icon: Icon(
                      hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                obscureText: hide,
                validator: validator,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    textStyle: textTheme.bodyMedium,
                  ),
                  child: Text(forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: error,
                builder: (_, error, child) {
                  return _Error(message: error);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onLogin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      logIn,
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String? message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (message) {
        null => const SizedBox.shrink(),
        String error => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.onErrorContainer,
                ),
                Expanded(
                  child: Text(
                    error,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}
