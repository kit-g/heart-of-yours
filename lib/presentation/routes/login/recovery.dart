part of 'login.dart';

class RecoveryPage extends StatefulWidget {
  final void Function(String) onLinkSent;
  final String? address;
  final bool isWideScreen;

  const RecoveryPage({
    super.key,
    required this.onLinkSent,
    this.address,
    this.isWideScreen = false,
  });

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage>
    with LoadingState<RecoveryPage>, HasError<RecoveryPage>, HasHaptic<RecoveryPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    if (widget.address case String s when s.isNotEmpty) {
      _emailController.text = s;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:forgotPassword, :cannotBeEmpty, :email, :sendResetLink, :sendResetLinkBody) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    String? validator(String? value) {
      return (value?.isEmpty ?? true) ? cannotBeEmpty : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(forgotPassword),
        leading: switch (widget.isWideScreen) {
          false => null,
          true => BackButton(
              onPressed: () {
                widget.onLinkSent(_emailController.text.trim());
              },
            ),
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: LogoTitle(fontSize: 32),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                spacing: 12,
                children: [
                  Text(
                    sendResetLinkBody,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: email,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      validator: validator,
                      autocorrect: false,
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: error,
                    builder: (_, error, _) {
                      return _Error(message: error);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _emailController,
                    builder: (_, value, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: loader,
                        builder: (_, loading, child) {
                          if (loading) return child!;
                          return OutlinedButton(
                            onPressed: switch (value.text.isEmpty) {
                              true => null,
                              false => _resetPassword,
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(sendResetLink),
                              ],
                            ),
                          );
                        },
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    buzz();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final focus = FocusScope.of(context);
    final l = L.of(context);

    error.value = null;

    try {
      focus.unfocus();
      startLoading();
      await Auth.of(context).sendPasswordRecoveryEmail(_emailController.text.trim());

      widget.onLinkSent(_emailController.text.trim());
      await Future.delayed(const Duration(milliseconds: 500));

      messenger.showSnackBar(
        SnackBar(
          content: Text(l.recoveryLinkMessage),
        ),
      );
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
}
