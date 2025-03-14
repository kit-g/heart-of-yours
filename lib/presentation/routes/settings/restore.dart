part of 'settings.dart';

class RestoreAccountPage extends StatefulWidget {
  final VoidCallback onUndo;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const RestoreAccountPage({
    super.key,
    required this.onUndo,
    this.onError,
  });

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
            child: switch (auth.user?.scheduledForDeletionAt) {
              DateTime t => Text(
                  accountDeletedBody(
                    RestoreAccountPage._formatDate(t.toLocal()),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              _ => const SizedBox()
            },
          ),
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: loader,
              builder: (__, loading, _) {
                return OutlinedButton(
                  onPressed: switch (loading) {
                    true => null,
                    false => () async {
                        startLoading();

                        try {
                          await auth.deleteAccountDeletionSchedule();
                          widget.onUndo();
                        } catch (e, s) {
                          widget.onError?.call(e, stacktrace: s);
                        } finally {
                          stopLoading();
                        }
                      },
                  },
                  child: Text(accountDeletedAction),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
