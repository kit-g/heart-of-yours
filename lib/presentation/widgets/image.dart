import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String? url;
  final BoxFit? fit;

  const AppImage({
    super.key,
    this.url,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return switch (url) {
      (String url) when url.startsWith('https') => CachedNetworkImage(
          imageUrl: url,
          fit: fit,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
