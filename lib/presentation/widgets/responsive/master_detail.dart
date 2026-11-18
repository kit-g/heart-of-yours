import 'package:heart/core/utils/visual.dart';
import 'package:material_ui/material_ui.dart';

/// How long the detail pane takes to open or close.
const _duration = Duration(milliseconds: 280);

/// A list and, once something in it is picked, its detail beside it (#685):
/// the app's one way of showing a selection on a page wide enough for two.
///
/// Nothing picked, the list has the page to itself, centred and no wider
/// than [maxMasterWidth]; there is no empty pane waiting for a choice.
/// Picking moves the list to the leading edge as it narrows to
/// [masterWidth], and slides the pane in beside it; clearing the pick slides
/// it back out.
/// Picking another item while the pane is open swaps what it shows without
/// moving the list.
///
/// The pane's content goes the moment [detail] does: a nested navigator moves
/// elsewhere in the tree as its pane closes, and a copy kept here for the way
/// out would put its global key in two places at once.
class MasterDetail extends StatelessWidget {
  final Widget master;

  /// What was picked; absent for nothing.
  final Widget? detail;

  /// How wide the list stays with the pane open, from the page's own width.
  final double Function(double width) masterWidth;

  /// How wide the list grows with the page to itself: a list of rows past
  /// this only puts distance between a row's name and its values.
  final double maxMasterWidth;

  const new({
    super.key,
    required this.master,
    required this.masterWidth,
    this.detail,
    this.maxMasterWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:dividerColor) = Theme.of(context);
    final open = detail != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final alone = maxMasterWidth.clamp(0.0, width);
        // never wider beside the pane than on its own
        final narrow = masterWidth(width).clamp(0.0, alone);
        return TweenAnimationBuilder<double>(
          tween: Tween(end: open ? 1.0 : 0.0),
          // asked for less motion, the pane is simply there (`docs/a11y.md`)
          duration: lessMotion(context) ? Duration.zero : _duration,
          curve: Curves.easeOutCubic,
          // the list keeps one child throughout, so its scroll position and
          // state ride through the pane opening and closing
          child: master,
          builder: (context, shown, master) {
            final listWidth = alone + (narrow - alone) * shown;
            final listStart = (width - alone) / 2 * (1 - shown);
            return Stack(
              children: [
                PositionedDirectional(
                  start: listStart,
                  top: 0,
                  bottom: 0,
                  width: listWidth,
                  child: master!,
                ),
                // from the first frame of opening: a nested navigator handed
                // over as [detail] has to be in the tree the moment it leaves
                // the offstage spot it waited in
                if (open || shown > 0)
                  PositionedDirectional(
                    start: listStart + listWidth,
                    top: 0,
                    bottom: 0,
                    // the pane slides in at its full width, from off the edge
                    width: width - narrow,
                    // clipped: a page pushed inside the pane slides within
                    // it, not over the list
                    child: ClipRect(
                      child: DecoratedBox(
                        // over the pane's own opaque page, which hides it
                        // drawn underneath
                        position: .foreground,
                        decoration: BoxDecoration(
                          border: BorderDirectional(start: BorderSide(color: dividerColor)),
                        ),
                        child: Opacity(opacity: shown, child: detail ?? const SizedBox.expand()),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
