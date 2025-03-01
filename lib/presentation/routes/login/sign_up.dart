part of 'login.dart';

class SignUpPage extends StatefulWidget {
  final String? address;
  final void Function(String?) onLogin;

  const SignUpPage({
    super.key,
    required this.onLogin,
    this.address,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with LoadingState<SignUpPage>, HasError<SignUpPage>, AsyncState<SignUpPage> {
  late Future<bool> _isAppleSignNnAvailable;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordObscurityController = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    _isAppleSignNnAvailable = Auth.isAppleSignInAvailable();

    if (widget.address case String s when s.isNotEmpty) {
      _emailController.text = s;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:signUpWithGoogle, :signUpWithApple, :orConnector, :signUp, :logIn) = L.of(context);

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
                                  nameController: _nameController,
                                  onAction: _signUpWithEmail,
                                  obscurityController: _passwordObscurityController,
                                  error: error,
                                  needsName: true,
                                  actionButtonCopy: signUp,
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
                                          Text(signUpWithGoogle),
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
                                                    Text(signUpWithApple),
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
                                    widget.onLogin(_emailController.text);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(logIn),
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

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    return run(
      () {
        return Auth.of(context).signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
      },
      onEmailExists: () async {
        final shouldProceed = await _showConfirmSignInDialog(context, email) ?? false;
        if (!shouldProceed) return;

        return run(
          () {
            return Auth.of(context).logInWithEmailAndPassword(
              email: email,
              password: password,
            );
          },
        );
      },
    );
  }

  Future<bool?> _showConfirmSignInDialog(BuildContext context, String email) async {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(
      :emailExistsTitle,
      :emailExistsBody,
      :emailExistsCancelButton,
      :emailExistsOkButton,
    ) = L.of(context);
    return showBrandedDialog(
      context,
      title: Text(emailExistsTitle),
      titleTextStyle: textTheme.titleMedium,
      content: Text(
        emailExistsBody(email),
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(emailExistsCancelButton),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  emailExistsOkButton,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop(true);
              },
            ),
          ],
        ),
      ],
    );
  }
}
