import 'dart:async';

import 'package:flutter/material.dart';

void snack(
  BuildContext context,
  String content, {
  SnackBarAction? action,
  Duration? duration,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(content),
      showCloseIcon: true,
      action: action,
      duration: duration = const Duration(seconds: 4),
    ),
  );
}

void snackOnError(BuildContext context, dynamic error) {
  return switch (error) {
    ArgumentError(:var message) => snack(context, message.toString()),
    _ => snack(context, error.toString()),
  };
}

extension SnackOnError on BuildContext {
  FutureOr<Null> showSnackOnError(dynamic error) async {
    if (!mounted) return;
    snack(this, error.toString());
  }
}

mixin ShowsSnackOnError<T extends StatefulWidget> on State<T> {
  FutureOr<Null> showSnack(dynamic error) {
    return context.showSnackOnError(error);
  }
}

mixin LoadingState<T extends StatefulWidget> on State<T> {
  final loader = ValueNotifier<bool>(false);

  void startLoading() => loader.value = true;

  void stopLoading() => loader.value = false;

  bool get isLoading => loader.value;

  @override
  void dispose() {
    loader.dispose();
    super.dispose();
  }
}

class FixedHeightHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  const FixedHeightHeaderDelegate({
    required this.child,
    required this.height,
    this.backgroundColor,
    this.borderRadius = BorderRadius.zero,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Padding(
        padding: padding,
        child: SizedBox.expand(child: child),
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant FixedHeightHeaderDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor || child != oldDelegate.child;
  }
}
