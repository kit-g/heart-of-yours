import 'package:flutter/material.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with LoadingState<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final L(:logInWithGoogle) = L.of(context);
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: loader,
          builder: (_, loading, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (loading) {
                    false => child!,
                    true => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                  },
                ),
              ],
            );
          },
          child: OutlinedButton(
            onPressed: () => _logIn(context),
            child: Text(logInWithGoogle),
          ),
        ),
      ),
    );
  }

  Future<void> _logIn(BuildContext context) async {
    try {
      startLoading();
      await Auth.of(context).loginWithGoogle();
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
    } finally {
      stopLoading();
    }
  }
}
