import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:material_ui/material_ui.dart';

/// What a push that arrived with the app open says (#724), in the app's
/// words: [serial] tells one arrival from the next, so the same words twice
/// are two notes.
typedef PushNote = ({int serial, IconData icon, String title, String? line});

/// Where the bottom of the push note is on screen, in global coordinates,
/// while one shows: the live records note (#160) sits under it rather than
/// beneath it.
final pushNoteBottom = ValueNotifier<double?>(null);

/// [child] with the push note over its top edge: the app's own look for a
/// push with the app open, where the system would have drawn a banner.
///
/// Only the note takes touches, and only where it is: everything around it,
/// a workout in progress included, works as it did. A tap opens what it
/// names, a swipe up puts it away, and with less motion asked for it simply
/// appears and goes.
class PushNoteHost extends StatefulWidget {
  final ValueListenable<PushNote?> note;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Widget child;

  const new({super.key, required this.note, required this.onTap, required this.onDismiss, required this.child});

  @override
  State<PushNoteHost> createState() => _PushNoteHostState();
}

class _PushNoteHostState extends State<PushNoteHost> {
  final _card = GlobalKey();

  /// How wide the note grows: a banner, not a sheet, on a tablet's width.
  static const _width = 420.0;

  /// Between the top's safe area and the note.
  static const _gap = 8.0;

  @override
  void initState() {
    super.initState();
    widget.note.addListener(_measure);
  }

  @override
  void didUpdateWidget(PushNoteHost old) {
    super.didUpdateWidget(old);
    if (identical(old.note, widget.note)) return;
    old.note.removeListener(_measure);
    widget.note.addListener(_measure);
  }

  @override
  void dispose() {
    widget.note.removeListener(_measure);
    pushNoteBottom.value = null;
    super.dispose();
  }

  /// After the frame that lays the note out: where its bottom edge rests,
  /// the slide it comes in with aside. The host spans the window from its
  /// top, so its own coordinates are the screen's.
  void _measure() {
    if (widget.note.value == null) {
      pushNoteBottom.value = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final top = MediaQuery.paddingOf(context).top + _gap;
      pushNoteBottom.value = switch ((widget.note.value, _card.currentContext?.findRenderObject())) {
        (PushNote(), final RenderBox box) when box.hasSize => top + box.size.height,
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = lessMotion(context);
    return Stack(
      fit: .expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const .fromLTRB(16, _gap, 16, 0),
              child: Align(
                alignment: .topCenter,
                child: ConstrainedBox(
                  // the switcher's, not a note's: two notes share it while
                  // one makes way for the next
                  key: _card,
                  constraints: const BoxConstraints(maxWidth: _width),
                  child: ValueListenableBuilder<PushNote?>(
                    valueListenable: widget.note,
                    builder: (context, note, _) {
                      return AnimatedSwitcher(
                        duration: still ? Duration.zero : const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, -.3), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (note) {
                          final PushNote note => Dismissible(
                            key: ValueKey(note.serial),
                            direction: .up,
                            movementDuration: still ? Duration.zero : const Duration(milliseconds: 200),
                            onDismissed: (_) => widget.onDismiss(),
                            // gone at the end of the swipe, with nothing
                            // left to close up under it
                            resizeDuration: null,
                            child: _PushNoteCard(
                              note: note,
                              onTap: widget.onTap,
                              onDismiss: widget.onDismiss,
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
      ],
    );
  }
}

/// The note itself, as the live records note looks: a quiet card, the accent
/// only on the glyph and the heading, said to a screen reader as it arrives.
class _PushNoteCard extends StatelessWidget {
  final PushNote note;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const new({required this.note, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    const radius = BorderRadius.all(.circular(12));
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
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            border: .all(color: colorScheme.outlineVariant, width: .5),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(color: colorScheme.shadow.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
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
