part of 'workout.dart';

class GalleryPage extends StatelessWidget {
  final String? remote;
  final Uint8List? bytes;
  final String? title;

  const GalleryPage({
    super.key,
    required this.remote,
    required this.bytes,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          color: Colors.white,
          icon: const Icon(Icons.close_rounded),
        ),
        title: switch (title) {
          String t => Text(t, style: TextStyle(color: Colors.white),),
          null => null,
        },
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleFactor: 2,
          scaleEnabled: true,
          child: AppImage(
            url: remote,
            bytes: bytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
