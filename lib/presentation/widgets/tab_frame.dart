import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:material_ui/material_ui.dart';

/// One tab of a [TabFrame]: what it is called, and its icon, built where the
/// bar or the rail wants it.
typedef TabDestination = ({String label, WidgetBuilder icon});

/// A space's tabs around its [shell]: a bottom bar on a compact window, a rail
/// on a wide one. The app's own space and the Coaching space (#566) share it,
/// so both get the same label fitting, rail and keyboard.
class TabFrame extends StatelessWidget {
  /// `BottomNavigationBar`'s own defaults, named so the scale below has
  /// something to scale.
  static const _selectedLabel = 14.0;
  static const _unselectedLabel = 12.0;

  /// Below this the labels stop being words, so nothing is gained by shrinking
  /// further — the bar keeps its icons and lets the longest label ellipsise.
  static const _floor = 0.7;

  /// What the bar keeps for itself either side of a label.
  ///
  /// Measured on a 393pt phone with four destinations: the label box came out
  /// 67pt against the 98pt each item nominally gets. `BottomNavigationBar`
  /// gives the selected destination more room than the rest, so the unselected
  /// width is what has to fit.
  static const _itemPadding = 31.0;

  final StatefulNavigationShell shell;
  final List<TabDestination> destinations;

  /// A tab tapped while it is already the one showing: the space decides what
  /// that does (`docs/style.md`: a navbar button is a back action).
  final void Function(BuildContext context, int index) onReselect;

  /// Under the rail's destinations on a wide window, such as the way between
  /// spaces. Absent on a compact one, where the space puts it in its pages.
  final Widget? railFooter;

  /// Across the bottom of the space, over every tab and above the bar: absent
  /// unless the space has something to say wherever the user is in it. At the
  /// bottom, the pages' app bars keep the status bar to themselves.
  final Widget? banner;

  const new({
    super.key,
    required this.shell,
    required this.destinations,
    required this.onReselect,
    this.railFooter,
    this.banner,
  });

  /// How much the destination labels have to shrink to all fit on one line.
  ///
  /// `BottomNavigationBarItem.label` is a `String`, so the bar builds the text
  /// itself and ellipsises what does not fit — which is what Russian met:
  /// `Тренировка` and `Упражнения` came out as `Трениров…` and `Упражне…`,
  /// and which two were cut changed with the selection, because the selected
  /// destination is given more room. English, Spanish and French fit at full
  /// size and are untouched by this.
  ///
  /// Measured rather than guessed, and applied to all of them at once: a bar
  /// with one smaller label would read as a mistake.
  static double _labelScale(BuildContext context, Iterable<String> labels, double width, TextStyle style) {
    final direction = Directionality.of(context);

    // the bar divides its width evenly and each item keeps a little air
    final room = width / labels.length - _itemPadding;

    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      widest = switch (painter.width > widest) {
        true => painter.width,
        false => widest,
      };
    }

    if (widest <= room) return 1;
    return switch (room / widest) {
      final scale when scale >= _floor => scale,
      _ => _floor,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutProvider(
      currentStack: shell.currentIndex,
      builder: (context, layout, stackIndex) {
        final ThemeData(:brightness) = Theme.of(context);
        final isDark = brightness == .dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? .light : .dark,
          statusBarBrightness: brightness, // iOS hint
          systemNavigationBarIconBrightness: isDark ? .light : .dark,
        );
        final body = switch (banner) {
          final Widget banner => Column(
            children: [
              Expanded(child: shell),
              banner,
            ],
          ),
          null => shell,
        };
        switch (layout) {
          case LayoutSize.compact:
            return _KeyMap(
              shell: shell,
              tabs: destinations.length,
              onReselect: onReselect,
              child: Scaffold(
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: body,
                ),
                bottomNavigationBar: LayoutBuilder(
                  builder: (context, constraints) {
                    final bar = Theme.of(context).bottomNavigationBarTheme;
                    final selected = bar.selectedLabelStyle ?? const TextStyle(fontSize: _selectedLabel);
                    final unselected = bar.unselectedLabelStyle ?? const TextStyle(fontSize: _unselectedLabel);
                    final scale = _labelScale(
                      context,
                      destinations.map((d) => d.label),
                      constraints.maxWidth,
                      unselected,
                    );
                    return BottomNavigationBar(
                      type: BottomNavigationBarType.shifting,
                      currentIndex: shell.currentIndex,
                      onTap: (index) => _onTap(context, index),
                      // through the styles, not `selectedFontSize`: the theme
                      // sets both label styles, and a style's own `fontSize`
                      // wins over the widget's size parameters
                      selectedLabelStyle: selected.copyWith(fontSize: (selected.fontSize ?? _selectedLabel) * scale),
                      unselectedLabelStyle: unselected.copyWith(
                        fontSize: (unselected.fontSize ?? _unselectedLabel) * scale,
                      ),
                      items: [
                        for (final d in destinations) BottomNavigationBarItem(icon: d.icon(context), label: d.label),
                      ],
                    );
                  },
                ),
              ),
            );

          case LayoutSize.wide:
            return _KeyMap(
              shell: shell,
              tabs: destinations.length,
              onReselect: onReselect,
              child: Scaffold(
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: Row(
                    children: [
                      NavigationRail(
                        key: AppKeys.navigationRail,
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: (index) => _onTap(context, index),
                        labelType: NavigationRailLabelType.all,
                        // at the bottom of the rail, where the eye doesn't
                        // mistake it for one more tab
                        trailingAtBottom: true,
                        trailing: railFooter,
                        destinations: [
                          for (final d in destinations)
                            NavigationRailDestination(icon: d.icon(context), label: Text(d.label)),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }

  Future<void> _onTap(BuildContext context, int index) async {
    HapticFeedback.mediumImpact();
    if (shell.currentIndex != index) {
      // switch to that navigation stack unless already there
      return shell.goBranch(index);
    }
    onReselect(context, index);
  }
}

/// `[` and `]` for the tab either side, and ⌘1 onwards for each tab by place.
class _KeyMap extends StatelessWidget {
  final Widget child;
  final StatefulNavigationShell shell;
  final int tabs;
  final void Function(BuildContext context, int index) onReselect;

  const new({
    required this.child,
    required this.shell,
    required this.tabs,
    required this.onReselect,
  });

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(.bracketRight): _NextTabIntent(),
        LogicalKeySet(.bracketLeft): _PreviousTabIntent(),
        for (final (index, digit) in _digits.take(tabs).indexed) LogicalKeySet(.meta, digit): _TabIntent(index),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) => _changeTab(context, (shell.currentIndex + 1) % tabs),
          ),
          _PreviousTabIntent: CallbackAction<_PreviousTabIntent>(
            onInvoke: (_) => _changeTab(context, (shell.currentIndex - 1 + tabs) % tabs),
          ),
          _TabIntent: CallbackAction<_TabIntent>(
            onInvoke: (intent) => _changeTab(context, intent.index),
          ),
        },
        child: child,
      ),
    );
  }

  void _changeTab(BuildContext context, int index) {
    if (index != shell.currentIndex) {
      shell.goBranch(index);
    } else {
      onReselect(context, index);
    }
  }
}

class _NextTabIntent extends Intent;

class _PreviousTabIntent extends Intent;

class _TabIntent extends Intent {
  final int index;

  const new(this.index);
}
