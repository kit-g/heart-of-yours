import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;

  final BoxFit? fit;
  final Widget Function(BuildContext context, String url, DownloadProgress progress)? progressIndicatorBuilder;
  final Widget Function(BuildContext context, Object error)? errorWidget;

  const AppImage({
    super.key,
    this.url,
    this.bytes,
    this.fit,
    this.progressIndicatorBuilder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return switch ((url, bytes)) {
      (_, Uint8List bytes) => Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, _) {
            return errorWidget?.call(context, error) ?? const SizedBox.shrink();
          },
        ),
      // something is off with CachedNetworkImage, gifs and Flutter 3.29+, it seems
      (String url, _) when kIsWeb && url.endsWith('.gif') => Image.network(
          url,
          headers: _headers,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            return switch (progress) {
              ImageChunkEvent(:var expectedTotalBytes, :var cumulativeBytesLoaded) => progressIndicatorBuilder?.call(
                    context,
                    url,
                    DownloadProgress(
                      url,
                      expectedTotalBytes,
                      cumulativeBytesLoaded,
                    ),
                  ) ??
                  const SizedBox.shrink(),
              _ => child,
            };
          },
          errorBuilder: (context, error, _) {
            return errorWidget?.call(context, error) ?? const SizedBox.shrink();
          },
        ),
      (String url, _) when url.startsWith('https') => CachedNetworkImage(
          fadeInDuration: const Duration(milliseconds: 200),
          httpHeaders: _headers,
          imageUrl: url,
          fit: fit,
          progressIndicatorBuilder: progressIndicatorBuilder,
          errorWidget: (context, _, error) {
            return errorWidget?.call(context, error) ?? const SizedBox.shrink();
          },
        ),
      _ => const SizedBox.shrink(),
    };
  }

  static set headers(Map<String, String> v) => _headers = v;
}

var _headers = <String, String>{};
