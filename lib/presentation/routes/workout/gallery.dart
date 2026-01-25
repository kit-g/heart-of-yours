part of 'workout.dart';

class GalleryPage extends StatefulWidget {
  final List<Media> media;
  final String? title;
  final int startingIndex;
  final VoidCallback? onTapTitle;

  const GalleryPage({
    super.key,
    required this.media,
    this.title,
    this.onTapTitle,
    this.startingIndex = 0,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final CarouselController _controller;
  final _currentIndex = ValueNotifier(0);

  @override
  void initState() {
    super.initState();

    _currentIndex.value = widget.startingIndex;
    _controller = CarouselController(initialItem: widget.startingIndex);
    _controller.addListener(_indexListener);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_indexListener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :appBarTheme, :carouselViewTheme) = Theme.of(context);
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: .light,
      statusBarBrightness: .dark, // iOS
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: .light,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Theme(
        data: ThemeData(
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
          textTheme: textTheme,
          carouselViewTheme: carouselViewTheme,
        ),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: Navigator.of(context).pop,
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
            ),
            title: ValueListenableBuilder<int>(
              valueListenable: _currentIndex,
              builder: (_, page, _) {
                switch (widget.title) {
                  case String t:
                    return GestureDetector(
                      onTap: widget.onTapTitle,
                      child: Text(
                        t,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  case null:
                    final currentlyShown = widget.media[page];
                    final date = currentlyShown.timestamp;
                    final title = date != null ? DateFormat('EEEE, MMM d, yyyy').format(date) : null;
                    return switch (title) {
                      String t => Text(
                        t,
                        style: const TextStyle(color: Colors.white),
                      ),
                      null => const SizedBox.shrink(),
                    };
                }
              },
            ),
          ),
          body: CarouselView.weighted(
            flexWeights: [8],
            controller: _controller,
            children: widget.media.map(
              (file) {
                return AppImage(
                  url: file.link,
                  bytes: file.bytes,
                  fit: .cover,
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }

  /// listens to carousel scrolling and calculates which page is currently in viewport
  void _indexListener() {
    final position = _controller.position;
    if (position.hasPixels) {
      // calculate the index by rounding the current pixel offset divided by the item extent
      // use viewportDimension as item extent is dynamic in CarouselView
      final index = (position.pixels / position.viewportDimension).round();
      _currentIndex.value = index;
    }
  }
}
