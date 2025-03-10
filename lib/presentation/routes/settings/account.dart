part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  @override
  Widget build(BuildContext context) {
    final L(:accountManagement) = L.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(accountManagement),
      ),
      body: ListView(
        children: const [
          LogoStripe()
        ],
      ),
    );
  }
}
