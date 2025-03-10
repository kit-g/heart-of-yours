part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> with LoadingState<AccountManagementPage> {
  final _passwordController = TextEditingController();
  final _obscurityController = ValueNotifier(false);
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _obscurityController.dispose();
    _passwordFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:accountControl, :deleteAccount) = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(accountControl),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: ListView(
        children: [
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
      content: Text(
        deleteAccountBody(AppConfig.accountDeletionDeadline),
        textAlign: TextAlign.center,
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
              controller: _passwordController,
              obscureText: hide,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                hintText: yourPassword,
                suffixIcon: ListenableBuilder(
                  listenable: _passwordFocusNode,
                  builder: (_, __) {
                    return Offstage(
                      offstage: !_passwordFocusNode.hasFocus,
                      child: IconButton(
                        tooltip: hide ? showPassword : hidePassword,
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                        visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
                        onPressed: () {
                          _obscurityController.value = !_obscurityController.value;
                        },
                        icon: Icon(
                          hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                Navigator.of(context).pop();
              },
            ),
          ],
        )
      ],
    );
  }
}
