import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:linkify/linkify.dart';

/// A message's words with its time set beside the last line when there is
/// room, and under it when there isn't, the way chat apps set them.
///
/// One render object lays out both, so whatever is drawn around it is exactly
/// as wide as the longest line, or the last line with the time, and never the
/// full width a wrapping [Text] reports. Links, with their scheme or `www.`,
/// and email addresses open through [onLink], and a screen reader is offered
/// each as an action.
///
/// From `TimestampedChatBubble`, written for another app of ours.
class MessageText extends LeafRenderObjectWidget {
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  /// When it was written, as shown.
  final String time;
  final TextStyle timeStyle;

  /// After the time: where the message stands.
  final IconData? status;

  /// Before the words: what a message that didn't open shows in their place.
  final IconData? leading;

  /// Null leaves links as words.
  final ValueChanged<Uri>? onLink;

  /// What a screen reader says for the whole message.
  final String semanticsLabel;

  /// What a screen reader calls the action that opens [link].
  final String Function(String link)? linkAction;

  /// Between the last line and the time.
  final double gap;

  const new({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.time,
    required this.timeStyle,
    required this.semanticsLabel,
    this.status,
    this.leading,
    this.onLink,
    this.linkAction,
    this.gap = 8,
  });

  @override
  RenderMessageText createRenderObject(BuildContext context) {
    return RenderMessageText(
      text: text,
      style: style,
      linkStyle: linkStyle,
      time: time,
      timeStyle: timeStyle,
      status: status,
      leading: leading,
      onLink: onLink,
      semanticsLabel: semanticsLabel,
      linkAction: linkAction,
      gap: gap,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderMessageText renderObject) {
    renderObject
      ..update(
        text: text,
        style: style,
        linkStyle: linkStyle,
        leading: leading,
        onLink: onLink,
      )
      ..updateTime(time: time, timeStyle: timeStyle, status: status)
      ..semanticsLabel = semanticsLabel
      ..linkAction = linkAction
      ..gap = gap
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

/// Where a layout put the words and the time, for the width it was given.
typedef _Placement = ({Size size, Offset words, Offset time, double width});

/// Lays out and paints [MessageText].
class RenderMessageText extends RenderBox {
  String _text;
  TextStyle _style;
  TextStyle _linkStyle;
  IconData? _leading;
  ValueChanged<Uri>? _onLink;
  String _time;
  TextStyle _timeStyle;
  IconData? _status;
  String _semanticsLabel;
  String Function(String link)? _linkAction;
  double _gap;
  TextDirection _textDirection;
  TextScaler _textScaler;

  // the longest line, not the width given: what a bubble wraps
  late final _words = TextPainter(
    textDirection: _textDirection,
    textScaler: _textScaler,
    textWidthBasis: .longestLine,
  );
  late final _meta = TextPainter(textDirection: _textDirection, textScaler: _textScaler, maxLines: 1);

  /// Each link's recognizer, owned here and disposed with each rebuild.
  final _links = <(Uri, TapGestureRecognizer)>[];

  _Placement? _placement;

  new({
    required this._text,
    required this._style,
    required this._linkStyle,
    required this._time,
    required this._timeStyle,
    required this._semanticsLabel,
    required this._textDirection,
    required this._textScaler,
    this._status,
    this._leading,
    this._onLink,
    this._linkAction,
    this._gap = 8,
  }) {
    _buildWords();
    _buildMeta();
  }

  void update({
    required String text,
    required TextStyle style,
    required TextStyle linkStyle,
    required IconData? leading,
    required ValueChanged<Uri>? onLink,
  }) {
    final links = onLink != null;
    final same =
        text == _text &&
        style == _style &&
        linkStyle == _linkStyle &&
        leading == _leading &&
        links == (_onLink != null);
    // a new callback for the same words: the recognizers read it as they fire
    _onLink = onLink;
    if (same) return;
    _text = text;
    _style = style;
    _linkStyle = linkStyle;
    _leading = leading;
    _buildWords();
    _relayout();
  }

  void updateTime({required String time, required TextStyle timeStyle, required IconData? status}) {
    if (time == _time && timeStyle == _timeStyle && status == _status) return;
    _time = time;
    _timeStyle = timeStyle;
    _status = status;
    _buildMeta();
    _relayout();
  }

  set semanticsLabel(String value) {
    if (value == _semanticsLabel) return;
    _semanticsLabel = value;
    markNeedsSemanticsUpdate();
  }

  set linkAction(String Function(String link)? value) {
    if (value == _linkAction) return;
    _linkAction = value;
    markNeedsSemanticsUpdate();
  }

  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    _relayout();
  }

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _words.textDirection = value;
    _meta.textDirection = value;
    _relayout();
  }

  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _words.textScaler = value;
    _meta.textScaler = value;
    _relayout();
  }

  void _relayout() {
    _placement = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  static const _options = LinkifyOptions(humanize: false, defaultToHttps: true);

  void _buildWords() {
    _disposeLinks();
    final elements = switch (_onLink) {
      null => [TextElement(_text)],
      _ => linkify(_text, options: _options),
    };
    _words.text = TextSpan(
      style: _style,
      children: [
        if (_leading case final IconData icon) ...[_glyph(icon, _style), const TextSpan(text: ' ')],
        for (final element in elements)
          switch (_uriOf(element)) {
            final Uri uri => TextSpan(text: element.text, style: _linkStyle, recognizer: _recognizer(uri)),
            null => TextSpan(text: element.text),
          },
      ],
    );
  }

  void _buildMeta() {
    _meta.text = TextSpan(
      style: _timeStyle,
      children: [
        TextSpan(text: _time),
        if (_status case final IconData icon) ...[
          // a thin space: the glyph belongs to the time
          const TextSpan(text: ' '),
          _glyph(icon, _timeStyle, scale: 1.2),
        ],
      ],
    );
  }

  TapGestureRecognizer _recognizer(Uri uri) {
    final recognizer = TapGestureRecognizer(debugOwner: this)..onTap = () => _onLink?.call(uri);
    _links.add((uri, recognizer));
    return recognizer;
  }

  void _disposeLinks() {
    for (final (_, recognizer) in _links) {
      recognizer.dispose();
    }
    _links.clear();
  }

  static Uri? _uriOf(LinkifyElement element) {
    return switch (element) {
      EmailElement(:final emailAddress) => Uri(scheme: 'mailto', path: emailAddress),
      UrlElement(:final url) => switch (Uri.tryParse(url)) {
        final Uri uri when uri.scheme == 'http' || uri.scheme == 'https' => uri,
        // `www.` alone: the options' https is applied only to loose links
        final Uri uri when !uri.hasScheme => Uri.tryParse('https://$url'),
        _ => null,
      },
      _ => null,
    };
  }

  /// An icon set as a character of its font, in [style]'s colour.
  static TextSpan _glyph(IconData icon, TextStyle style, {double scale = 1}) {
    return TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        inherit: false,
        color: style.color,
        fontSize: (style.fontSize ?? 14) * scale,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        height: 1,
      ),
    );
  }

  /// Lays both painters out for [maxWidth], and places them.
  _Placement _place(double maxWidth) {
    if (_placement case final _Placement placement when placement.width == maxWidth) return placement;
    _words.layout(maxWidth: maxWidth);
    _meta.layout(maxWidth: maxWidth);
    final last = _words.computeLineMetrics().lastOrNull;
    final lastWidth = last?.width ?? 0;
    final besideWidth = lastWidth + _gap + _meta.width;
    final beside = last != null && besideWidth <= maxWidth;
    final width = math.max(_words.width, switch (beside) {
      true => besideWidth,
      false => _meta.width,
    });
    final metaTop = switch ((beside, last)) {
      // on the last line's baseline, not its bottom: the two sizes of type
      // then read as one line
      (true, final LineMetrics line) => line.baseline - _meta.computeDistanceToActualBaseline(.alphabetic),
      _ => _words.height,
    };
    final height = math.max(_words.height, metaTop + _meta.height);
    final (words, time) = switch (_textDirection) {
      .ltr => (Offset.zero, Offset(width - _meta.width, metaTop)),
      .rtl => (Offset(width - _words.width, 0), Offset(0, metaTop)),
    };
    return _placement = (size: Size(width, height), words: words, time: time, width: maxWidth);
  }

  @override
  void performLayout() {
    final placement = _place(constraints.maxWidth);
    size = constraints.constrain(placement.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.constrain(_place(constraints.maxWidth).size);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _words.layout();
    _meta.layout();
    return math.max(_words.minIntrinsicWidth, _meta.width);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _place(double.infinity).size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _place(width).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _place(width).size.height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final placement = _place(constraints.maxWidth);
    return placement.words.dy + _words.computeDistanceToActualBaseline(baseline);
  }

  /// What this frame was laid out for: intrinsics and dry layouts in between
  /// may have laid the painters out for another width.
  _Placement get _laidOut => _place(constraints.maxWidth);

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent || _links.isEmpty) return;
    final local = entry.localPosition - _laidOut.words;
    if (!(Offset.zero & _words.size).contains(local)) return;
    final span = _words.text?.getSpanForPosition(_words.getPositionForOffset(local));
    if (span case TextSpan(recognizer: final GestureRecognizer recognizer)) recognizer.addPointer(event);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final placement = _laidOut;
    _words.paint(context.canvas, offset + placement.words);
    _meta.paint(context.canvas, offset + placement.time);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _semanticsLabel
      ..textDirection = _textDirection;
    if ((_onLink, _linkAction) case (final ValueChanged<Uri> open, final String Function(String) action)) {
      final actions = <CustomSemanticsAction, VoidCallback>{
        for (final (uri, _) in _links) CustomSemanticsAction(label: action(_shown(uri))): () => open(uri),
      };
      if (actions.isNotEmpty) config.customSemanticsActions = actions;
    }
  }

  /// A link as a person would say it: an email without `mailto:`.
  static String _shown(Uri uri) {
    return switch (uri.scheme) {
      'mailto' => uri.path,
      _ => uri.toString(),
    };
  }

  @override
  void dispose() {
    _disposeLinks();
    _words.dispose();
    _meta.dispose();
    super.dispose();
  }
}
