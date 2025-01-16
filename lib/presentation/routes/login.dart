import 'package:flutter/foundation.dart';
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
  late Future<bool> _isAppleSignNnAvailable;

  @override
  void initState() {
    super.initState();

    _isAppleSignNnAvailable = Auth.isAppleSignInAvailable();
  }

  @override
  Widget build(BuildContext context) {
    final L(:logInWithGoogle, :logInWithApple) = L.of(context);
    return Scaffold(
      body: Center(
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 24,
            children: [
              OutlinedButton(
                onPressed: () => _logIn(context, Auth.of(context).loginWithGoogle),
                child: Text(logInWithGoogle),
              ),
              FutureBuilder<bool>(
                future: _isAppleSignNnAvailable,
                builder: (_, snapshot) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    child: switch (!snapshot.hasError && snapshot.hasData && snapshot.data!) {
                      false => const SizedBox.shrink(),
                      true => OutlinedButton(
                          onPressed: () => _logIn(context, Auth.of(context).loginWithApple),
                          child: Text(logInWithApple),
                        ),
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logIn(BuildContext context, AsyncCallback callback) async {
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
}
