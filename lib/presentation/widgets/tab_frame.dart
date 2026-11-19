import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:material_ui/material_ui.dart';

/// One tab of a [TabFrame]: what it is called, its icon, built where the bar
/// or the rail wants it, and the [StatefulNavigationShell] branch it opens.
///
/// The branch, not the place in the bar: a space can leave a tab out (#608),
/// and the tabs after it move up a place while their branches stay put.
typedef TabDestination = ({String label, WidgetBuilder icon, int branch});

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

  /// A tab tapped while it is already the one showing, by its branch: the
  /// space decides what that does (`docs/style.md`: a navbar button is a back
  /// action).
  final void Function(BuildContext context, int branch) onReselect;

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

  /// Where the branch on screen sits in the bar. A branch with no tab (one
  /// the space has just left out) reads as the first, for the frame the space
  /// takes to move off it.
  int get _selected {
    return switch (destinations.indexWhere((each) => each.branch == shell.currentIndex)) {
      -1 => 0,
      final position => position,
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
              branches: [for (final each in destinations) each.branch],
              selected: _selected,
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
                      currentIndex: _selected,
                      onTap: (position) => _onTap(context, position),
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
              branches: [for (final each in destinations) each.branch],
              selected: _selected,
              onReselect: onReselect,
              child: Scaffold(
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: Row(
                    children: [
                      NavigationRail(
                        key: AppKeys.navigationRail,
                        selectedIndex: _selected,
                        onDestinationSelected: (position) => _onTap(context, position),
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

  Future<void> _onTap(BuildContext context, int position) async {
    HapticFeedback.mediumImpact();
    final branch = destinations[position].branch;
    if (shell.currentIndex != branch) {
      // switch to that navigation stack unless already there
      return shell.goBranch(branch);
    }
    onReselect(context, branch);
  }
}

/// `[` and `]` for the tab either side, and ⌘1 onwards for each tab by place:
/// places in the bar, which [branches] maps to the shell's.
class _KeyMap extends StatelessWidget {
  final Widget child;
  final StatefulNavigationShell shell;
  final List<int> branches;

  /// The place in the bar of the tab on screen, as the bar shows it.
  final int selected;
  final void Function(BuildContext context, int branch) onReselect;

  const new({
    required this.child,
    required this.shell,
    required this.branches,
    required this.selected,
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
        for (final (position, digit) in _digits.take(branches.length).indexed)
          LogicalKeySet(.meta, digit): _TabIntent(position),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) => _changeTab(context, (selected + 1) % branches.length),
          ),
          _PreviousTabIntent: CallbackAction<_PreviousTabIntent>(
            onInvoke: (_) => _changeTab(context, (selected - 1 + branches.length) % branches.length),
          ),
          _TabIntent: CallbackAction<_TabIntent>(
            onInvoke: (intent) => _changeTab(context, intent.position),
          ),
        },
        child: child,
      ),
    );
  }

  void _changeTab(BuildContext context, int position) {
    final branch = branches[position];
    if (branch != shell.currentIndex) {
      shell.goBranch(branch);
    } else {
      onReselect(context, branch);
    }
  }
}

class _NextTabIntent extends Intent;

class _PreviousTabIntent extends Intent;

class _TabIntent extends Intent {
  final int position;

  const new(this.position);
}

/// The way between spaces at the foot of a [TabFrame]'s rail (#685): the same
/// place and the same shape on both sides, so the user finds it where they
/// left it. In words under its icon, as the rail's own tabs are: it is the
/// one way across, and an icon alone could pass for one more tab.
class SpaceSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const new({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(bottom: 16),
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: const .all(.circular(12)),
            child: ConstrainedBox(
              // two lines rather than a wider rail: the rail is as wide on
              // both sides, so the tabs don't shift on the way across
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 88, minHeight: 56),
              child: Padding(
                padding: const .symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisSize: .min,
                  spacing: 4,
                  children: [
                    Icon(icon),
                    Text(label, style: Theme.of(context).textTheme.labelMedium, textAlign: .center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
