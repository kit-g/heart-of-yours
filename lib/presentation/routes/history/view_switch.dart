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

/// History's header, open. Pinned, it folds to the toolbar as a view scrolls.
const _headerHeight = 80.0;

/// History's views, one turning into the other when the choice changes
/// (#712).
///
/// Each view is its own scrollable. While they swap both are built: the
/// arriving one on top, the leaving one under it, faded out and taking no
/// taps. The arriving view's header is drawn whole from the first frame,
/// folded as far as the leaving one's was, and opens from there, so the header
/// and its buttons never jump. Changing the choice back mid-swap runs the same
/// swap backwards from where it is. With less motion asked for, or History off
/// screen (the choice made in Settings), the new view is there at once.
class _ViewSwitch extends StatefulWidget {
  final HistoryView view;

  /// Builds a view. The view chosen is built afresh each time; the other one,
  /// while it is still on screen, is kept as it was last built.
  final Widget Function(HistoryView) builder;

  const new({required this.view, required this.builder});

  @override
  State<_ViewSwitch> createState() => _ViewSwitchState();
}

class _ViewSwitchState extends State<_ViewSwitch> with SingleTickerProviderStateMixin {
  /// 1 when the view on top is all there is; 0 when the one under it is.
  late final _progress = AnimationController(vsync: this, duration: _switchDuration, value: 1)
    ..addStatusListener(_settle);

  late final _arrival = CurvedAnimation(
    parent: _progress,
    curve: const Interval(_fadeOut, 1, curve: Curves.easeOutCubic),
  );

  late final _fading = CurvedAnimation(
    parent: _progress,
    curve: const Interval(0, _fadeOut, curve: Curves.easeIn),
  );

  late final _leaving = ReverseAnimation(_fading);

  /// From the leaving header's height to open; its start is set per swap.
  final _opening = Tween(begin: _headerHeight, end: _headerHeight);

  late final _header = _progress.drive(_opening.chain(CurveTween(curve: Curves.easeOutCubic)));

  /// Whether the arriving header's switch shows its new glyph yet: one frame
  /// of the old, so the glyph has something to turn from.
  final _turned = ValueNotifier(true);

  /// The view on top, and the one under it while the two swap.
  late final _views = ValueNotifier<(HistoryView, HistoryView?)>((widget.view, null));

  /// Each view as last built, so the one leaving is faded, not rebuilt: the
  /// list is a pass over all of history.
  final _built = <HistoryView, Widget>{};

  /// How far each view's own scrollable is scrolled, which says how far its
  /// header is folded. A plain map: it never needs a frame.
  final _offsets = <HistoryView, double>{};

  late final _steady = _Phase(
    arrival: kAlwaysCompleteAnimation,
    header: const AlwaysStoppedAnimation(_headerHeight),
    turned: _turned,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // gone off screen mid-swap: nothing would finish it
    if (!TickerMode.valuesOf(context).enabled && _views.value.$2 != null) _settleOn(widget.view);
  }

  @override
  void didUpdateWidget(covariant _ViewSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view == widget.view) return;
    if (lessMotion(context) || !TickerMode.valuesOf(context).enabled) return _settleOn(widget.view);
    switch (_views.value) {
      case (final HistoryView top, null):
        _swapFrom(top);
      // back to the one leaving: the same swap, backwards from here
      case (_, final HistoryView under) when under == widget.view:
        _progress.reverse();
      case (final HistoryView top, HistoryView _) when top == widget.view:
        _progress.forward();
      // a third, with two still swapping: from the one that was arriving
      case (final HistoryView top, HistoryView _):
        _swapFrom(top);
    }
  }

  void _swapFrom(HistoryView top) {
    final folded = _headerHeight - (_offsets[top] ?? 0);
    // never quite the toolbar: a header whose open and folded heights
    // are the same has nothing to lay its title out between
    _opening.begin = folded.clamp(kToolbarHeight + .5, _headerHeight);
    _offsets.remove(widget.view);
    _views.value = (widget.view, top);
    _turned.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _turned.value = true;
    });
    _progress.forward(from: 0);
  }

  void _settle(AnimationStatus status) {
    switch (status) {
      case .completed:
        _views.value = (_views.value.$1, null);
      // turned all the way back; a swap starting from 0 passes through
      // dismissed too, still headed for the view chosen
      case .dismissed when _views.value.$2 == widget.view:
        _settleOn(widget.view);
      case .dismissed || .forward || .reverse:
        break;
    }
  }

  void _settleOn(HistoryView view) {
    _views.value = (view, null);
    _turned.value = true;
    _progress.value = 1;
  }

  @override
  void dispose() {
    _arrival.dispose();
    _fading.dispose();
    _progress.dispose();
    _turned.dispose();
    _views.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _views,
      builder: (context, views, _) {
        final (top, under) = views;
        _built.removeWhere((view, _) => view != top && view != under);
        return Stack(
          fit: .expand,
          children: [
            if (under case final HistoryView view) _slot(view, top: false, under: null),
            _slot(top, top: true, under: under),
          ],
        );
      },
    );
  }

  Widget _slot(HistoryView view, {required bool top, required HistoryView? under}) {
    if (view == widget.view || !_built.containsKey(view)) _built[view] = widget.builder(view);
    return KeyedSubtree(
      // Keyed by view, so switching replaces the scrollable rather than
      // handing one view's offset and physics to the other, and a view going
      // from top to under keeps its state.
      key: ValueKey(view),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _offsets[view] = notification.metrics.pixels;
          return false;
        },
        child: FadeTransition(
          opacity: top ? kAlwaysCompleteAnimation : _leaving,
          child: IgnorePointer(
            ignoring: !top,
            child: ExcludeSemantics(
              excluding: !top,
              child: _ViewPhase(
                phase: switch (top) {
                  true => _Phase(
                    arrival: _arrival,
                    header: _header,
                    turned: _turned,
                    from: under,
                  ),
                  false => _steady,
                },
                child: _built[view]!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a view stands in a swap.
class _Phase {
  /// How far its body is in: faded and risen.
  final Animation<double> arrival;

  /// How open its header is.
  final Animation<double> header;

  /// Whether its switch shows the glyph for the view it is on.
  final ValueNotifier<bool> turned;

  /// The view it is arriving from, while it is.
  final HistoryView? from;

  const new({required this.arrival, required this.header, required this.turned, this.from});

  bool get settling => from != null;

  @override
  bool operator ==(Object other) {
    return other is _Phase &&
        other.arrival == arrival &&
        other.header == header &&
        other.turned == turned &&
        other.from == from;
  }

  @override
  int get hashCode => Object.hash(arrival, header, turned, from);
}

class _ViewPhase extends InheritedWidget {
  final _Phase phase;

  const new({required this.phase, required super.child});

  static _Phase of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ViewPhase>()!.phase;

  @override
  bool updateShouldNotify(_ViewPhase oldWidget) => phase != oldWidget.phase;
}

/// A view's header, as open as its swap has it.
class _SwitchHeader extends StatelessWidget {
  final Widget Function(double height) builder;

  const new({required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _ViewPhase.of(context).header,
      builder: (context, height, _) => builder(height),
    );
  }
}

/// A view's body, under the header and anything both views share: it fades
/// in and rises into place as its view arrives, and takes no taps until it is
/// all there.
class _Arriving extends StatelessWidget {
  final List<Widget> slivers;

  const new({required this.slivers});

  @override
  Widget build(BuildContext context) {
    final phase = _ViewPhase.of(context);
    return SliverIgnorePointer(
      ignoring: phase.settling,
      sliver: SliverFadeTransition(
        opacity: phase.arrival,
        sliver: _SliverRise(
          arrival: phase.arrival,
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ),
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
      final RenderSliver child when child.geometry!.hitTestExtent > 0 => result.addWithAxisOffset(
        paintOffset: Offset(0, _drop),
        mainAxisOffset: _drop,
        crossAxisOffset: 0,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
        hitTest: child.hitTest,
      ),
      _ => false,
    };
  }
}

/// The switch's glyph: the view on screen, turning from the one it was.
class _SwitchGlyph extends StatelessWidget {
  /// The view on screen.
  final HistoryView view;

  const new({required this.view});

  @override
  Widget build(BuildContext context) {
    final phase = _ViewPhase.of(context);
    return ValueListenableBuilder(
      valueListenable: phase.turned,
      builder: (context, turned, _) {
        final shown = turned ? view : phase.from ?? view;
        return AnimatedSwitcher(
          duration: lessMotion(context) ? Duration.zero : _switchDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation.drive(Tween(begin: .6, end: 1.0)), child: child),
          ),
          child: Icon(shown.icon, key: ValueKey(shown)),
        );
      },
    );
  }
}
