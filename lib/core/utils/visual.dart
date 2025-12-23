import 'dart:async';

import 'package:flutter/cupertino.dart';
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

extension ScaffoldMessengerStateExtension on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> snack(
    String content, {
    SnackBarAction? action,
    Duration? duration,
  }) {
    return showSnackBar(
      SnackBar(
        content: Text(content),
        showCloseIcon: true,
        action: action,
        duration: duration = const Duration(seconds: 4),
      ),
    );
  }
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

mixin HasError<T extends StatefulWidget> on State<T> {
  final error = ValueNotifier<String?>(null);

  @override
  void dispose() {
    error.dispose();
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

Future<T?> showBrandedDialog<T>(
  BuildContext context, {
  required Widget title,
  Widget? content,
  Widget? icon,
  TextStyle? titleTextStyle,
  TextStyle? contentTextStyle,
  List<Widget>? actions,
  EdgeInsetsGeometry padding = const .only(left: 16, right: 16, bottom: 12),
}) {
  final ThemeData(:textTheme, :scaffoldBackgroundColor) = Theme.of(context);

  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        contentPadding: padding,
        icon: icon,
        title: title,
        titleTextStyle: titleTextStyle ?? textTheme.titleMedium,
        content: content,
        contentTextStyle: contentTextStyle,
        actions: actions,
      );
    },
  );
}

class BottomMenuAction {
  final String title;
  final Widget? icon;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const BottomMenuAction({
    required this.title,
    this.icon,
    this.onPressed,
    this.isDestructive = false,
  });
}

Future<T?> showBottomMenu<T>(BuildContext context, List<BottomMenuAction> actions) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return showCupertinoModalPopup<T>(
        useRootNavigator: false,
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: actions.map(
            (action) {
              return CupertinoActionSheetAction(
                onPressed: action.onPressed ?? () {},
                isDestructiveAction: action.isDestructive,
                child: Text(action.title),
              );
            },
          ).toList(),
        ),
      );
    case _:
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Wrap(
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                ...actions.map(
                  (action) {
                    return ListTile(
                      onTap: action.onPressed,
                      leading: action.icon,
                      title: Text(
                        action.title,
                        style: TextStyle(
                          color: action.isDestructive ? Theme.of(context).colorScheme.error : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
  }
}
