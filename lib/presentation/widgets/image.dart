import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String? url;
  final BoxFit? fit;
  final Widget Function(BuildContext context, String url, DownloadProgress progress)? progressIndicatorBuilder;
  final Widget Function(BuildContext context, String url, Object error)? errorWidget;

  const AppImage({
    super.key,
    this.url,
    this.fit,
    this.progressIndicatorBuilder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return switch (url) {
      (String url) when url.startsWith('https') => CachedNetworkImage(
          httpHeaders: _headers,
          imageUrl: url,
          fit: fit,
          progressIndicatorBuilder: progressIndicatorBuilder,
          errorWidget: errorWidget,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static set headers(Map<String, String> v) => _headers = v;
}

var _headers = <String, String>{};
