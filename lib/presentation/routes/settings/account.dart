part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
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
                // Navigator.of(context).pop();
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
                Navigator.of(context).pop();
              },
            ),
          ],
        )
      ],
    );
  }
}
