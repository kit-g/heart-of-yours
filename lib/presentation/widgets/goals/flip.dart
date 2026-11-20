part of 'goals.dart';

/// How long the card takes to turn. Shared so the heading and the buttons
/// resolve on the same beat as the card itself — three separate durations read
/// as three things happening, rather than one card turning over.
const _flipDuration = Duration(milliseconds: 420);

const _flipCurve = Curves.easeInOutCubic;

/// Turns a card over to show what is on the other side.
///
/// A flip rather than a filter or a second screen because the two faces are the
/// same object seen from opposite sides: goals you are working on, and goals you
/// finished. Sliding between them would imply they sit next to each other in a
/// list; a flip says it is one card with a back.
///
/// The halves are swapped at the quarter turn, when the face is edge-on and
/// invisible, so neither is ever seen mirrored. The back is pre-rotated a half
/// turn for the same reason — without it, its content reads backwards.
///
/// The front decides the card's size on both sides (#687): it stays laid out,
/// unseen, while the back is up, and the back fills that size and scrolls
/// within it. Swapping one for the other resized the card mid-turn, and
/// everything under it on the profile jumped; sizing to the taller of the two
/// let a long list of finished goals stretch the live side instead. The back is
/// built only while it is turning or up, so a card nobody turns reads nothing
/// for it.
class _FlipCard extends StatelessWidget {
  final bool showsBack;
  final Widget front;

  /// Fills the front's size, so a list on it scrolls rather than grows.
  final WidgetBuilder back;

  const new({
    required this.showsBack,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: showsBack ? 1 : 0),
      duration: _flipDuration,
      curve: _flipCurve,
      builder: (context, turn, _) {
        final past = turn >= .5;
        return Transform(
          alignment: .center,
          transform: Matrix4.identity()
            // a little perspective, or the card scales rather than turns
            ..setEntry(3, 2, .0012)
            ..rotateY(turn * pi),
          child: Stack(
            // the card's width and, when it has one, its height reach the front
            fit: .passthrough,
            children: [
              _Face(shown: !past, child: front),
              if (turn > 0)
                Positioned.fill(
                  child: _Face(
                    shown: past,
                    child: Transform(
                      alignment: .center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: back(context),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One side of a [_FlipCard]: laid out either way, so the card keeps its
/// size, and while it is turned away neither painted, hit, focused nor read
/// out.
class _Face extends StatelessWidget {
  final bool shown;
  final Widget child;

  const new({required this.shown, required this.child});

  /// Whether the face [context] is on is the one turned up. A row swiped open
  /// closes when its face turns away, as it did when the face was unmounted.
  static bool isShown(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FaceShown>()?.shown ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return _FaceShown(
      shown: shown,
      child: ExcludeFocus(
        excluding: !shown,
        child: _FaceBox(shown: shown, child: child),
      ),
    );
  }
}

class _FaceShown extends InheritedWidget {
  final bool shown;

  const new({required this.shown, required super.child});

  @override
  bool updateShouldNotify(_FaceShown oldWidget) => shown != oldWidget.shown;
}

/// Lays its child out and, while not [shown], keeps it out of paint, hit tests
/// and semantics — and offstage to finders, as [Offstage] is, without giving
/// up the size the card takes from it.
class _FaceBox extends SingleChildRenderObjectWidget {
  final bool shown;

  const new({required this.shown, required Widget super.child});

  @override
  SingleChildRenderObjectElement createElement() => _FaceBoxElement(this);

  @override
  _RenderFaceBox createRenderObject(BuildContext context) => _RenderFaceBox(shown: shown);

  @override
  void updateRenderObject(BuildContext context, _RenderFaceBox renderObject) {
    renderObject.shown = shown;
  }
}

class _FaceBoxElement extends SingleChildRenderObjectElement {
  new(_FaceBox super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if ((widget as _FaceBox).shown) super.debugVisitOnstageChildren(visitor);
  }
}

class _RenderFaceBox extends RenderProxyBox {
  new({required this._shown});

  bool _shown;

  set shown(bool value) {
    if (value == _shown) return;
    _shown = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool paintsChild(RenderBox child) => _shown;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shown) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return _shown && super.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_shown) super.visitChildrenForSemantics(visitor);
  }
}
