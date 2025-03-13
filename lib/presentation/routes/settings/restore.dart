part of 'settings.dart';

class RestoreAccountPage extends StatefulWidget {
  const RestoreAccountPage({super.key});

  @override
  State<RestoreAccountPage> createState() => _RestoreAccountPageState();

  static String _formatDate(DateTime dt) {
    return DateFormat('EEEE, d MMM y').format(dt);
  }
}

class _RestoreAccountPageState extends State<RestoreAccountPage> with LoadingState<RestoreAccountPage> {
  @override
  Widget build(BuildContext context) {
    final L(:accountDeleted, :accountDeletedBody, :accountDeletedAction, :logOut) = L.of(context);
    final auth = Auth.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(accountDeleted),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
        actions: [
          IconButton.outlined(
            tooltip: logOut,
            onPressed: () => clearState(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64),
            child: Text(
              accountDeletedBody(
                RestoreAccountPage._formatDate(auth.user!.scheduledForDeletionAt!.toLocal()),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: loader,
            builder: (context, loading, _) {
              return OutlinedButton(
                onPressed: () {},
                child: Text(accountDeletedAction),
              );
            },
          ),
        ],
      ),
    );
  }
}
