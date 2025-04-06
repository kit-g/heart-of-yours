part of 'settings.dart';

class AvatarPage extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const AvatarPage({
    super.key,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Auth.watch(context);
    final user = auth.user;
    if (user == null) return const Scaffold();
    final L(:edit) = L.of(context);
    final User(remoteAvatar: avatar, :localAvatar) = user;
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            onPressed: onBack,
            color: Colors.white,
            icon: const Icon(Icons.close_rounded),
          ),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: edit,
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_rounded,
              ),
            )
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Hero(
              tag: 'avatar',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleFactor: 2,
                  scaleEnabled: true,
                  child: AppImage(
                    url: avatar,
                    bytes: localAvatar,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
