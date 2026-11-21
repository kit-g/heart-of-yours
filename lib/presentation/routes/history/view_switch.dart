part of 'history.dart';

/// How long History takes to turn from one view into the other (#712): as
/// long as crossing between spaces, so the two read as one family of motion.
const _switchDuration = Duration(milliseconds: 300);

/// The share of [_switchDuration] the leaving view takes to fade out before
/// the arriving one fades in: a fade-through, so the two bodies are never
/// both half drawn over each other.
const _fadeOut = 0.35;

/// How far, in logical pixels, the arriving body rises into place.
const _rise = 16.0;

/// History's two views, one turning into the other when the choice changes
/// (#712).
///
/// Each view stays its own scrollable, keyed by view, so neither hands its
/// offset to the other. While they swap both are built, the leaving one under
/// the arriving one. The arriving view's header is drawn whole from the first
/// frame and covers the leaving one's, so the header and its buttons stay put
/// and only the body under it changes. With less motion asked for, or the
/// page off screen (the choice made in Settings), the new view is there at
/// once.
class _ViewSwitch extends StatefulWidget {
  final HistoryView view;

  /// Builds a view. Called for both views only while they swap.
  final Widget Function(HistoryView) builder;

  const new({required this.view, required this.builder});

  @override
  State<_ViewSwitch> createState() => _ViewSwitchState();
}

class _ViewSwitchState extends State<_ViewSwitch> with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(vsync: this, duration: _switchDuration, value: 1)
    ..addStatusListener(_settle);

  late final _fading = _progress.drive(
    Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: const Interval(0, _fadeOut, curve: Curves.easeIn))),
  );

  /// The view on its way out, while it is.
  final _leaving = ValueNotifier<HistoryView?>(null);

  void _settle(AnimationStatus status) {
    if (status.isCompleted) _leaving.value = null;
  }

  @override
  void didUpdateWidget(covariant _ViewSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view == widget.view) return;
    if (lessMotion(context) || !TickerMode.valuesOf(context).enabled) {
      _progress.value = 1;
      _leaving.value = null;
      return;
    }
    _leaving.value = oldWidget.view;
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    _leaving.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _leaving,
      builder: (context, leaving, _) => Stack(
        fit: .expand,
        children: [
          if (leaving case final HistoryView view) _slot(view, leaving: true),
          _slot(widget.view, leaving: false),
        ],
      ),
    );
  }

  // The same shape arriving or leaving, keyed by view: a view going from one
  // to the other keeps its state, its scroll and its calendar's months.
  Widget _slot(HistoryView view, {required bool leaving}) {
    return KeyedSubtree(
      key: ValueKey(view),
      child: FadeTransition(
        opacity: leaving ? _fading : kAlwaysCompleteAnimation,
        child: IgnorePointer(
          ignoring: leaving,
          child: ExcludeSemantics(
            excluding: leaving,
            child: _ViewPhase(
              progress: leaving ? kAlwaysCompleteAnimation : _progress,
              child: widget.builder(view),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far the view under it is into arriving: complete, unless it is
/// arriving now.
class _ViewPhase extends InheritedWidget {
  final Animation<double> progress;

  const new({required this.progress, required super.child});

  static Animation<double> of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ViewPhase>()?.progress ?? kAlwaysCompleteAnimation;
  }

  @override
  bool updateShouldNotify(_ViewPhase oldWidget) => progress != oldWidget.progress;
}

/// A part of a view's body, fading in and rising into place as its view
/// arrives. The header is never under one: it is there whole from the start.
class _Arriving extends StatelessWidget {
  final Widget sliver;

  const new({required this.sliver});

  @override
  Widget build(BuildContext context) {
    final arrival = _ViewPhase.of(
      context,
    ).drive(CurveTween(curve: const Interval(_fadeOut, 1, curve: Curves.easeOutCubic)));
    return SliverFadeTransition(
      opacity: arrival,
      sliver: _SliverRise(arrival: arrival, sliver: sliver),
    );
  }
}

/// Paints [sliver] [_rise] pixels low at the start of [arrival], and in place
/// at its end. Paint only: the layout, and so the scroll extent and what the
/// calendar measures under the header, never moves.
class _SliverRise extends SingleChildRenderObjectWidget {
  final Animation<double> arrival;

  const new({required this.arrival, required Widget sliver}) : super(child: sliver);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverRise(arrival);

  @override
  void updateRenderObject(BuildContext context, _RenderSliverRise renderObject) {
    renderObject.arrival = arrival;
  }
}

// History's views scroll down the screen, so low is down.
class _RenderSliverRise extends RenderProxySliver {
  Animation<double> _arrival;

  new(this._arrival);

  set arrival(Animation<double> value) {
    if (value == _arrival) return;
    if (attached) {
      _arrival.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _arrival = value;
    markNeedsPaint();
  }

  double get _drop => (1 - _arrival.value) * _rise;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _arrival.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _arrival.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child case final RenderSliver child when child.geometry!.visible) {
      context.paintChild(child, offset.translate(0, _drop));
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    transform.translateByDouble(0, _drop, 0, 1);
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    return switch (child) {
      final RenderSliver child when child.geometry!.hitTestExtent > 0 => child.hitTest(
        result,
        mainAxisPosition: mainAxisPosition - _drop,
        crossAxisPosition: crossAxisPosition,
      ),
      _ => false,
    };
  }
}

/// The switch's glyph: the view it offers, turning from the one it offered
/// as the view arrives.
class _ViewSwitchIcon extends StatelessWidget {
  /// The view on screen.
  final HistoryView view;

  const new({required this.view});

  static IconData _offering(HistoryView view) => switch (view) {
    .list => Icons.calendar_month_rounded,
    .calendar => Icons.view_agenda_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final turn = _ViewPhase.of(context).drive(CurveTween(curve: Curves.easeInOutCubic));
    final gone = ReverseAnimation(turn);
    return Stack(
      alignment: .center,
      children: [
        FadeTransition(
          opacity: gone,
          child: ScaleTransition(
            scale: gone.drive(Tween(begin: .6, end: 1.0)),
            child: Icon(
              _offering(switch (view) {
                .list => .calendar,
                .calendar => .list,
              }),
            ),
          ),
        ),
        FadeTransition(
          opacity: turn,
          child: ScaleTransition(
            scale: turn.drive(Tween(begin: .6, end: 1.0)),
            child: Icon(_offering(view)),
          ),
        ),
      ],
    );
  }
}
