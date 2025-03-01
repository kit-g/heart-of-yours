part of 'login.dart';

class LoginPage extends StatefulWidget {
  final void Function(String?) onPasswordRecovery;
  final void Function(String?) onSignUp;
  final String? address;

  const LoginPage({
    super.key,
    required this.onPasswordRecovery,
    required this.onSignUp,
    this.address,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with LoadingState<LoginPage>, HasError<LoginPage>, HasHaptic<LoginPage>, AsyncState<LoginPage> {
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
    final L(:logInWithGoogle, :logInWithApple, :orConnector, :signUp, :logIn) = L.of(context);

    if (widget.address case String s when s.isNotEmpty) {
      _emailController.text = s;
    }

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
                                    child: CircularProgressIndicator(),
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
                                  onAction: _logInWithEmail,
                                  obscurityController: _passwordObscurityController,
                                  error: error,
                                  onPasswordRecovery: () {
                                    widget.onPasswordRecovery(_emailController.text.trim());
                                  },
                                  needsName: false,
                                  actionButtonCopy: logIn,
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
                                      onPressed: () => run(Auth.of(context).loginWithGoogle),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(logInWithGoogle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                FutureBuilder<bool>(
                                  future: _isAppleSignNnAvailable,
                                  builder: (_, snapshot) {
                                    final AsyncSnapshot(:hasData, :hasError, data: available) = snapshot;
                                    bool hasAppleSignIn = _isApple(context) && !hasError && hasData && available!;
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
                                                onPressed: () => run(Auth.of(context).loginWithApple),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(logInWithApple),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      },
                                    );
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(orConnector),
                                ),
                                TextButton(
                                  onPressed: () {
                                    buzz();
                                    widget.onSignUp(_emailController.text);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(signUp),
                                  ),
                                ),
                                const SizedBox(height: 24),
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

  Future<void> _logInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    return run(
      () {
        return Auth.of(context).logInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      },
    );
  }
}
