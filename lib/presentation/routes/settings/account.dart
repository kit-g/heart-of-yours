part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const AccountManagementPage({super.key, this.onError});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> with LoadingState<AccountManagementPage> {
  final _passwordController = TextEditingController();
  final _obscurityController = ValueNotifier(true);

  @override
  void dispose() {
    _passwordController.dispose();
    _obscurityController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:accountControl, :deleteAccount, :dangerZone) = L.of(context);
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

          return ListView(
            children: [
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
