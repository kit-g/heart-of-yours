part of 'login.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onPasswordRecovery;

  const LoginPage({super.key, required this.onPasswordRecovery});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with LoadingState<LoginPage>, HasError<LoginPage> {
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
                                  onLogin: _logInWithEmail,
                                  obscurityController: _passwordObscurityController,
                                  error: error,
                                  onPasswordRecovery: widget.onPasswordRecovery,
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
    error.value = null;
    final l = L.of(context);

    try {
      startLoading();
      await callback();
    } on AuthException catch (e) {
      error.value = _errorCopy(l, e.reason);
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
