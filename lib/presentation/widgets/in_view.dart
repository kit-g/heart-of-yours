import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// What a page can be showing that news can be about (#724).
enum ShownKind { thread, program }

/// One thing on screen: a conversation by its connection, a program by its id.
typedef Shown = (ShownKind, String);

/// Whether [subject] is in front of the person now: a push about it would say
/// what they are reading already.
bool inView(Shown subject) => _shown[subject]?.any((each) => each._inView) ?? false;

final _shown = <Shown, Set<_InViewState>>{};

/// Marks [child] as showing [subject], while [shown], for [inView].
///
/// In front is more than built. A shell branch that isn't showing keeps its
/// pages, tickers off; a page under another keeps its place, no longer
/// current; and a page in a shell sits under whatever the root navigator
/// pushed over the shell (the workout sheet), which the router's top page
/// says.
class InView extends StatefulWidget {
  final Shown subject;
  final bool shown;
  final Widget child;

  const new({super.key, required this.subject, this.shown = true, required this.child});

  @override
  State<InView> createState() => _InViewState();
}

class _InViewState extends State<InView> {
  ValueListenable<TickerModeData>? _ticking;
  ModalRoute<Object?>? _route;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _enlist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // looked up here, once per change, so asking costs nobody a rebuild
    _ticking = TickerMode.getValuesNotifier(context);
    _route = ModalRoute.of(context);
    _router = GoRouter.maybeOf(context);
  }

  @override
  void didUpdateWidget(InView old) {
    super.didUpdateWidget(old);
    if (old.subject == widget.subject && old.shown == widget.shown) return;
    _shown[old.subject]?.remove(this);
    _enlist();
  }

  @override
  void dispose() {
    _shown[widget.subject]?.remove(this);
    super.dispose();
  }

  void _enlist() {
    if (widget.shown) _shown.putIfAbsent(widget.subject, () => {}).add(this);
  }

  bool get _inView {
    if (!mounted || !(_ticking?.value.enabled ?? true)) return false;
    final route = _route;
    if (route != null && !route.isCurrent) return false;
    return switch ((route?.settings, _router)) {
      (Page(:final key), final GoRouter router) => router.state.pageKey == key,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
