import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

void snack(
  BuildContext context,
  String content, {
  SnackBarAction? action,
  Duration? duration,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(content),
      action: action,
      // an action flips SnackBar's `persist` default to true — the bar then
      // stays until tapped and blocks every queued snack behind it. Ours are
      // passing confirmations, so they always time out, action or not.
      persist: false,
      duration: duration ?? const Duration(seconds: 4),
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
        action: action,
        // see `snack` above: never persist, action or not
        persist: false,
        duration: duration ?? const Duration(seconds: 4),
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

  const new({
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
    return height != oldDelegate.height || backgroundColor != oldDelegate.backgroundColor || child != oldDelegate.child;
  }
}

/// Widest a dialog gets before it stops growing with the screen.
///
/// A dialog should read as a panel sitting on top of the app. Left unbounded it
/// takes whatever the screen offers — on an iPad that meant an 825pt card with
/// 5pt of margin either side, which looks like a broken page rather than a
/// dialog. No phone is this wide, so nothing changes there.
const dialogWidth = 560.0;

/// Keeps the seven-column calendar at phone proportions even on tablets: History's
/// calendar view (#609) centres itself in whatever is wider.
const calendarWidth = 400.0;

Future<T?> showBrandedDialog<T>(
  BuildContext context, {
  required Widget title,
  Widget? content,
  Widget? icon,
  TextStyle? titleTextStyle,
  TextStyle? contentTextStyle,
  List<Widget>? actions,
  EdgeInsetsGeometry padding = const .only(left: 16, right: 16, bottom: 12),
  bool scrollable = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      // read inside the builder, so a theme change under an open dialog — a
      // system dark-mode flip, a preset switch — repaints the title with it
      // rather than leaving it in the colours it opened under
      final ThemeData(:textTheme) = Theme.of(context);
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
        contentPadding: padding,
        icon: icon,
        title: title,
        titleTextStyle: titleTextStyle ?? textTheme.titleMedium,
        // An AlertDialog is as wide as its widest part, so content that wants
        // to expand — a picker, a list — dragged the whole dialog out to the
        // screen edge.
        content: switch (content) {
          null => null,
          Widget c => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: dialogWidth),
            child: c,
          ),
        },
        contentTextStyle: contentTextStyle,
        actions: actions,
        // content that can outgrow a short screen, or a large text size,
        // scrolls under the title rather than overflowing it
        scrollable: scrollable,
      );
    },
  );
}

/// Asks before something that can't be undone: [cancel] and [confirm], the
/// latter in the error colour under [key]. Answers whether it was confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  required Key key,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final sure = await showBrandedDialog<bool>(
    context,
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const .new(64, 48)),
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(cancel),
      ),
      TextButton(
        key: key,
        style: TextButton.styleFrom(minimumSize: const .new(64, 48), foregroundColor: colorScheme.error),
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: Text(confirm),
      ),
    ],
  );
  return sure ?? false;
}

class BottomMenuAction {
  final String title;
  final Widget? icon;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const new({
    required this.title,
    this.icon,
    this.onPressed,
    this.isDestructive = false,
  });
}

Future<T?> showBottomMenu<T>(BuildContext context, List<BottomMenuAction> actions) {
  final ThemeData(:cupertinoOverrideTheme, :brightness, :colorScheme, :textTheme, :platform) = Theme.of(context);
  switch (platform) {
    case .iOS:
    case .macOS:
      return showCupertinoModalPopup<T>(
        useRootNavigator: false,
        context: context,
        builder: (context) => CupertinoTheme(
          data: CupertinoThemeData(
            brightness: brightness,
            primaryColor: colorScheme.primary,
            textTheme: CupertinoTextThemeData(
              primaryColor: colorScheme.primary,
              textStyle: textTheme.titleLarge,
              actionTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
            ),
          ),
          child: CupertinoActionSheet(
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
        ),
      );
    case .linux:
    case .windows:
    case .android:
    case .fuchsia:
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

extension SectionHeaderStyle on ThemeData {
  /// The face of a list's section names: History's months, the exercise
  /// picker's Recent and All exercises. Set in capitals by the caller.
  TextStyle? get sectionHeader {
    return textTheme.labelLarge?.copyWith(
      color: colorScheme.primary,
      fontWeight: .bold,
    );
  }
}

/// Where a menu opens under whatever [context] belongs to, as wide as it.
/// Where a menu opens at a point, as a long press's: [at] in global terms,
/// against the overlay the menu is laid out in.
RelativeRect menuAt(BuildContext context, Offset at) {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return RelativeRect.fill;
  return RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size);
}

/// Measured against the navigator's overlay, as [menuUnderValue] is.
RelativeRect menuUnder(BuildContext context) {
  final box = context.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return RelativeRect.fill;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  return RelativeRect.fromRect(rect.bottomLeft & Size(rect.width, 0), Offset.zero & overlay.size);
}

/// Where a menu opens off a trailing value: under it, its right edge on the
/// value's. `Position.position()` hangs a menu off a widget's *left* edge,
/// which is right for a leading button and wrong for a trailing value, where
/// the menu then runs past the column.
///
/// Measured against the navigator's overlay, not the window: `showMenu` lays
/// the menu out in that overlay, and inside the two-pane shell the overlay
/// starts after the rail, so a window offset lands the menu a rail's width to
/// the right of the value.
RelativeRect menuUnderValue(BuildContext context, GlobalKey key, {required double width}) {
  return switch (key.currentContext) {
    BuildContext value => menuEndingUnder(value, width: width),
    null => RelativeRect.fill,
  };
}

/// [menuUnderValue] for the widget [context] belongs to: a menu [width] wide
/// under it, its right edge on the widget's — for a trailing button that has
/// its own context to hand and no key.
RelativeRect menuEndingUnder(BuildContext context, {required double width}) {
  final box = context.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return RelativeRect.fill;
  final Offset(:dx, :dy) = box.localToGlobal(Offset.zero, ancestor: overlay);
  final Size(width: w, height: h) = box.size;
  return RelativeRect.fromLTRB(dx + w - width, dy + h, overlay.size.width - (dx + w), dy + h);
}

/// The widest a menu ending under the widget [context] belongs to can be and
/// still hang from it: from the overlay's start, short of the popup's own 8pt
/// margin and the safe area it keeps clear of, to the widget's right edge.
/// Wider, the popup is pushed right past the widget — at the 600pt
/// breakpoint, out of the master pane and into the detail.
double menuRoomEndingUnder(BuildContext context) {
  final box = context.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context;
  final overlayBox = overlay?.findRenderObject();
  if (box is! RenderBox || overlay == null || overlayBox is! RenderBox) return double.infinity;
  final Offset(:dx) = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final inset = MediaQuery.maybePaddingOf(overlay)?.left ?? 0;
  return dx + box.size.width - 8 - inset;
}

/// Where a menu opens over [box]: its rect in the navigator's overlay, which
/// is where [showMenu] lays the menu out. The window's coordinates are not:
/// inside the two-pane shell the overlay starts after the rail (see
/// [menuUnderValue]).
RelativeRect menuOver(BuildContext context, RenderBox box) {
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (overlay is! RenderBox) return RelativeRect.fill;
  return RelativeRect.fromRect(
    box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
    Offset.zero & overlay.size,
  );
}

/// Whether the user asked for less motion: Android's "Remove animations", or
/// iOS's Reduce Motion.
///
/// Those are two flags, and `MediaQuery.disableAnimationsOf` alone reads only
/// the first. On iOS Reduce Motion arrives as `reduceMotion`, which never sets
/// `disableAnimations`. Every reveal, pulse and burst that checked only the
/// first went on moving for the iPhone and iPad users who asked it not to (#595).
/// Ask this, not either flag.
///
/// No `MediaQuery` above (a bare widget test) reads as no preference.
bool lessMotion(BuildContext context) {
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || (MediaQuery.maybeReduceMotionOf(context) ?? false);
}

/// One line of [style] at [scaler]'s size: what a row of text takes, for a
/// layout that has to know its extent before it lays the text out.
double lineExtent(TextStyle? style, TextScaler scaler) {
  return scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.4);
}

/// How wide [text] lays out on one line where [context] is, as a `Text`
/// there draws it: the ambient style merged with [style], bold when the
/// platform asks for bold text, at [textScaler] (the reader's by default).
/// Measuring at the plain weight undercounts: bold digits run 5–8% wider in
/// some presets' faces.
double lineWidth(BuildContext context, String text, {TextStyle? style, TextScaler? textScaler}) {
  final bold = MediaQuery.boldTextOf(context);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style).merge(bold ? const TextStyle(fontWeight: .bold) : null),
    ),
    textDirection: Directionality.of(context),
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
