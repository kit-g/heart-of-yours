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
                    // spacing: 24,
                    children: [
                      _Form(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        onLogin: _logInWithEmail,
                        obscurityController: _passwordObscurityController,
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
                          bool hasAppleSignIn =
                              _isIos(context) && !snapshot.hasError && snapshot.hasData && snapshot.data!;
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
    );
  }

  Future<void> _logIn(AsyncCallback callback) async {
    try {
      startLoading();
      await callback();
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
      () async {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        Auth.of(context).loginWithEmailAndPassword(email: email, password: password);
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

  const _Form({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.obscurityController,
  });

  @override
  Widget build(BuildContext context) {
    final L(:logIn, :email, :password, :cannotBeEmpty, :showPassword, :hidePassword) = L.of(context);
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
            spacing: 12,
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(hintText: email),
                keyboardType: TextInputType.emailAddress,
                validator: validator,
              ),
              TextFormField(
                controller: passwordController,
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
