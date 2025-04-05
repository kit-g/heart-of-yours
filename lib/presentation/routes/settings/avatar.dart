part of 'settings.dart';

class AvatarPage extends StatelessWidget {
  final VoidCallback onBack;

  const AvatarPage({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Auth.watch(context);
    final user = auth.user;
    if (user == null) return const Scaffold();
    final User(:avatar, :localAvatar) = user;
    final size = MediaQuery.sizeOf(context);
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: BackButton(
            onPressed: onBack,
            color: Colors.white,
          ),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: SizedBox.square(
            dimension: size.width - 100,
            child: Hero(
              tag: 'avatar',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
    );
  }
}
