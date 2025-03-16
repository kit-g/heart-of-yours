part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const AccountManagementPage({super.key, this.onError});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage>
    with LoadingState<AccountManagementPage>, HasHaptic<AccountManagementPage> {
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _obscurityController = ValueNotifier(true);

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _obscurityController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :accountControl,
      :deleteAccount,
      :dangerZone,
      :name,
      :saveName,
      :changeName,
      :resetPassword,
      :noConnectivity,
      :recoveryLinkMessageSent,
    ) = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(accountControl),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: loader,
        builder: (_, loading, child) {
          if (loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final auth = Auth.watch(context);

          if (auth.user?.displayName case String name) {
            _nameController.text = name;
          }

          return ListView(
            children: [
              const SizedBox(height: 8),
              ListTile(
                title: Text(resetPassword),
                onTap: () async {
                  if (auth.user?.email case String email) {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      startLoading();
                      await auth.sendPasswordRecoveryEmail(email);
                      messenger.snack(recoveryLinkMessageSent);
                    } on AuthException catch (e, s) {
                      switch (e.reason) {
                        case AuthExceptionReason.networkRequestFailed:
                          messenger.snack(noConnectivity);
                        default:
                          widget.onError?.call(e, stacktrace: s);
                      }
                    } finally {
                      stopLoading();
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  changeName,
                  style: textTheme.titleMedium,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (_, value, __) {
                  return ListenableBuilder(
                    listenable: _nameFocusNode,
                    builder: (context, __) {
                      final current = value.text.trim();
                      final hasChangedName = auth.user?.displayName != current;
                      final shouldSave = current.isNotEmpty && hasChangedName;
                      return ListTile(
                        title: TextField(
                          autocorrect: false,
                          focusNode: _nameFocusNode,
                          controller: _nameController,
                          onSubmitted: (_) {
                            buzz();
                            if (shouldSave) {
                              auth.updateName(current);
                            }
                            _nameFocusNode.unfocus();
                          },
                          decoration: InputDecoration.collapsed(hintText: name),
                        ),
                        trailing: switch (_nameFocusNode.hasFocus) {
                          false => null,
                          true => IconButton(
                              tooltip: saveName,
                              icon: const Icon(Icons.check_circle_rounded),
                              onPressed: switch (shouldSave) {
                                true => () {
                                    buzz();
                                    auth.updateName(current);
                                    _nameFocusNode.unfocus();
                                  },
                                false => null,
                              },
                            ),
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  dangerZone,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.error),
                ),
              ),
              ListTile(
                onTap: () {
                  _onDeleteAccount(context);
                },
                leading: Icon(
                  Icons.auto_delete_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  deleteAccount,
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _onDeleteAccount(BuildContext context) async {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :deleteAccountTitle,
      :deleteAccountBody,
      :deleteAccountCancelMessage,
      :deleteAccountConfirmMessage,
    ) = L.of(context);

    return showBrandedDialog(
      context,
      title: Text(
        deleteAccountTitle,
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          deleteAccountBody(AppConfig.accountDeletionDeadline),
          textAlign: TextAlign.center,
        ),
      ),
      icon: Icon(
        Icons.auto_delete_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(deleteAccountCancelMessage),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteAccountConfirmMessage,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _onConfirmDeleteAccount(context);
              },
            ),
          ],
        )
      ],
    );
  }

  Future<void> _onConfirmDeleteAccount(BuildContext context) async {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :confirmDeleteAccountTitle,
      :yourPassword,
      :hidePassword,
      :showPassword,
      confirmDeleteAccountCancelMessage: cancel,
      confirmDeleteAccountOkMessage: ok,
    ) = L.of(context);

    return showBrandedDialog(
      context,
      title: Text(
        confirmDeleteAccountTitle,
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: _obscurityController,
          builder: (_, hide, __) {
            return TextField(
              autocorrect: false,
              controller: _passwordController,
              obscureText: hide,
              decoration: InputDecoration(hintText: yourPassword),
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
      icon: Icon(
        Icons.auto_delete_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  ok,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _requestAccountDeletion(context);
              },
            ),
          ],
        )
      ],
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    startLoading();
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    try {
      await Auth.of(context).scheduleAccountForDeletion(
        password: _passwordController.text.trim(),
        onAuthenticate: (token) {
          if (token != null) {
            Api.instance.authenticate(
              headers(
                sessionToken: token,
                appVersion: AppInfo.of(context).fullVersion,
              ),
            );
          }
        },
      );
      _passwordController.clear();
    } on AuthException {
      messenger.snack(l.invalidCredentials);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }
}
