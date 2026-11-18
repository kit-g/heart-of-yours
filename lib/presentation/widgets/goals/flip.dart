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
class _FlipCard extends StatelessWidget {
  final bool showsBack;
  final Widget front;
  final Widget back;

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
      builder: (_, turn, _) {
        final past = turn >= .5;
        return Transform(
          alignment: .center,
          transform: Matrix4.identity()
            // a little perspective, or the card scales rather than turns
            ..setEntry(3, 2, .0012)
            ..rotateY(turn * pi),
          child: _Faces(
            showsBack: past,
            front: ExcludeFocus(excluding: past, child: front),
            back: ExcludeFocus(
              excluding: !past,
              child: Transform(
                alignment: .center,
                transform: Matrix4.identity()..rotateY(pi),
                child: back,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Both faces of the card, laid out at the taller one's height, with only the
/// one turned up painted, hit or read out (#687).
///
/// Swapping one face for the other resized the card mid-turn whenever the two
/// lists differed in length, and everything under it on the profile jumped.
/// Both stay laid out instead, so the card takes the same room on either side,
/// and the shorter face stretches to it rather than leaving a step.
class _Faces extends MultiChildRenderObjectWidget {
  final bool showsBack;

  new({required this.showsBack, required Widget front, required Widget back}) : super(children: [front, back]);

  @override
  MultiChildRenderObjectElement createElement() => _FacesElement(this);

  @override
  _RenderFaces createRenderObject(BuildContext context) => _RenderFaces(showsBack: showsBack);

  @override
  void updateRenderObject(BuildContext context, _RenderFaces renderObject) {
    renderObject.showsBack = showsBack;
  }
}

/// Lets finders treat the face turned down as offstage, as [Offstage] does:
/// it is laid out for its height and never seen.
class _FacesElement extends MultiChildRenderObjectElement {
  new(_Faces super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = (widget as _Faces).showsBack ? 1 : 0;
    if (children.elementAtOrNull(shown) case final Element face) visitor(face);
  }
}

class _FaceParentData extends ContainerBoxParentData<RenderBox>;

class _RenderFaces extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FaceParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FaceParentData> {
  new({required this._showsBack});

  bool _showsBack;

  set showsBack(bool value) {
    if (value == _showsBack) return;
    _showsBack = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  RenderBox? get _shown => _showsBack ? lastChild : firstChild;

  Iterable<RenderBox> get _faces sync* {
    var child = firstChild;
    while (child != null) {
      yield child;
      child = childAfter(child);
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FaceParentData) child.parentData = _FaceParentData();
  }

  double _most(double Function(RenderBox face) measure) => _faces.map(measure).fold(0, max);

  @override
  double computeMinIntrinsicWidth(double height) => _most((face) => face.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) => _most((face) => face.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) => _most((face) => face.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _most((face) => face.getMaxIntrinsicHeight(width));

  @override
  void performLayout() {
    // each at its own height first, then both again at least the taller one's
    final tallest = _most((face) {
      face.layout(constraints, parentUsesSize: true);
      return face.size.height;
    });
    size = constraints.constrain(Size(constraints.maxWidth, tallest));
    // a floor rather than a tight height: a tight face is a relayout boundary,
    // and a row that grows once its reading arrives would overflow the card
    // instead of coming back here to be measured again
    final fitted = constraints.copyWith(minHeight: size.height);
    for (final face in _faces) {
      face.layout(fitted, parentUsesSize: true);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shown case final RenderBox face) context.paintChild(face, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return switch (_shown) {
      final RenderBox face => face.hitTest(result, position: position),
      null => false,
    };
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_shown case final RenderBox face) visitor(face);
  }
}
