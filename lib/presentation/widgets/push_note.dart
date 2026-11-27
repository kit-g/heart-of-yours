import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/note.dart';
import 'package:heart_state/heart_state.dart' show Push;
import 'package:material_ui/material_ui.dart';

/// What a push that arrived with the app open says (#724), in the app's
/// words, and the push it is about. [serial] tells one arrival from the
/// next: the same words twice are two notes, and a tap on one that is on
/// its way out acts on that one, not on the note replacing it.
typedef PushNote = ({int serial, Push push, IconData icon, String title, String? line});

/// Where the bottom of the push note rests on screen, in global coordinates,
/// while one is there, going included: the live records note (#160) sits
/// under it rather than beneath it ([BelowPushNote]).
final pushNoteBottom = ValueNotifier<double?>(null);

/// [child] with the push note over its top edge: the app's own look for a
/// push with the app open, where the system would have drawn a banner.
///
/// Only the note takes touches, and only where it is: everything around it,
/// a workout in progress included, works as it did. A tap opens what it
/// names, a swipe up puts it away. A screen reader meets it first.
class PushNoteHost extends StatelessWidget {
  final ValueListenable<PushNote?> note;
  final void Function(PushNote note) onTap;
  final void Function(PushNote note) onDismiss;
  final Widget child;

  const new({super.key, required this.note, required this.onTap, required this.onDismiss, required this.child});

  /// How wide the note grows: a banner, not a sheet, on a tablet's width.
  static const _width = 420.0;

  @override
  Widget build(BuildContext context) {
    final still = lessMotion(context);
    return Stack(
      fit: .expand,
      children: [
        // after the note in reading order, which otherwise goes by where
        // each starts: the page from the top of the window, the note below it
        Semantics(container: true, sortKey: const OrdinalSortKey(1), child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const .fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: .topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _width),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    container: true,
                    // the switcher's extent, not one note's: it keeps the
                    // going one's until it has faded
                    child: _ReportsBottom(
                      child: ValueListenableBuilder<PushNote?>(
                        valueListenable: note,
                        builder: (context, note, _) {
                          return NoteSwitcher(
                            child: switch (note) {
                              final PushNote note => Dismissible(
                                key: ValueKey(note.serial),
                                direction: .up,
                                movementDuration: still ? Duration.zero : const Duration(milliseconds: 200),
                                // gone at the end of the swipe, with nothing
                                // left to close up under it
                                resizeDuration: null,
                                onDismissed: (_) => onDismiss(note),
                                child: _PushNoteCard(
                                  note: note,
                                  onTap: () => onTap(note),
                                  onDismiss: () => onDismiss(note),
                                ),
                              ),
                              null => const SizedBox.shrink(),
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps [pushNoteBottom] on the bottom edge of its child, wherever layout
/// puts it, as of each paint.
class _ReportsBottom extends SingleChildRenderObjectWidget {
  const new({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportsBottom();
}

class _RenderReportsBottom extends RenderProxyBox {
  double? _reported;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final bottom = size.height > 0 ? localToGlobal(Offset(0, size.height)).dy : null;
    _report(bottom);
  }

  @override
  void detach() {
    _report(null);
    super.detach();
  }

  /// After the frame: a notifier's listeners mark their own render objects,
  /// which a paint may not do.
  void _report(double? bottom) {
    if (bottom == _reported) return;
    _reported = bottom;
    WidgetsBinding.instance.addPostFrameCallback((_) => pushNoteBottom.value = bottom);
  }
}

/// [child], moved down as far as the push note reaches over it, plus [gap]:
/// a note of its own near the top of a page stays readable under a push's.
/// It follows wherever layout puts either of them, as of each paint.
class BelowPushNote extends SingleChildRenderObjectWidget {
  final double gap;

  const new({super.key, this.gap = 8, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderBelowPushNote(gap);

  @override
  void updateRenderObject(BuildContext context, RenderBelowPushNote renderObject) => renderObject.gap = gap;
}

/// [BelowPushNote]'s render object: the shift is worked out as it paints, when
/// layout has put both notes where they go.
class RenderBelowPushNote extends RenderProxyBox {
  double _gap;
  double _shift = 0;

  new(this._gap);

  double get gap => _gap;

  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    pushNoteBottom.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    pushNoteBottom.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _shift = switch (pushNoteBottom.value) {
      final double bottom => math.max(0, bottom + gap - localToGlobal(Offset.zero).dy),
      null => 0,
    };
    super.paint(context, offset.translate(0, _shift));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, _shift),
      position: position,
      hitTest: (result, transformed) => super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, _shift, 0, 1);
}

/// The note itself, as the live records note looks: the accent only on the
/// glyph and the heading, said to a screen reader as it arrives.
class _PushNoteCard extends StatelessWidget {
  final PushNote note;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const new({required this.note, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Semantics(
      key: AppKeys.pushNote,
      container: true,
      liveRegion: true,
      button: true,
      label: [note.title, ?note.line].join('. '),
      onTap: onTap,
      onDismiss: onDismiss,
      excludeSemantics: true,
      child: Material(
        type: .transparency,
        child: Ink(
          decoration: noteDecoration(colorScheme),
          child: InkWell(
            borderRadius: noteRadius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity, minHeight: kMinInteractiveDimension),
              child: Padding(
                padding: const .symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(note.icon, size: 20, color: colorScheme.primary),
                    Expanded(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            note.title,
                            maxLines: 2,
                            overflow: .ellipsis,
                            style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                          ),
                          if (note.line case final String line)
                            Text(
                              line,
                              maxLines: 2,
                              overflow: .ellipsis,
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
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
