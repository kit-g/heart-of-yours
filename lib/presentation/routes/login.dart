import 'package:flutter/material.dart';
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                Auth.of(context).loginWithGoogle();
              },
              child: Text(logInWithGoogle),
            ),
          ],
        ),
      ),
    );
  }
}
