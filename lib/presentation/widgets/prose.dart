import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// Markdown text — headings, paragraphs, emphasis, lists — set in the theme's
/// own type and tokens.
///
/// `MarkdownConfig.defaultConfig` would not do. Its colours happen to inherit,
/// but its type is its own: fixed sizes (24 for `##`, 16 for body), bold, all
/// in the ambient body font, so a preset's heading face and scale never reach
/// it. `#` and `##` also draw a divider whose colour is none of the tokens.
/// Here headings take the title roles the surrounding pages use, and carry no
/// rule.
///
/// Headings announce themselves as headers, so a screen reader can jump from
/// one section of an exercise's instructions to the next.
///
/// Links render as the plain text they wrap. The ones What's new carries are
/// app routes, and until something handles them a link is a dead control —
/// worse, markdown_widget's default tap hands the path to `launchUrl`, which
/// would try to open `/history` outside the app.
class Prose extends StatelessWidget {
  final String data;

  /// Off where a caller merges the text into one semantics node (What's new):
  /// selection splits it into its own nodes.
  final bool selectable;

  const new(this.data, {super.key, this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final small = textTheme.titleSmall ?? const TextStyle();
    return MarkdownBlock(
      data: data,
      selectable: selectable,
      generator: _generator,
      config: MarkdownConfig(
        configs: [
          PConfig(textStyle: textTheme.bodyMedium ?? const TextStyle()),
          H1Config(style: textTheme.titleLarge ?? const TextStyle()),
          H2Config(style: textTheme.titleMedium ?? const TextStyle()),
          H3Config(style: small),
          H4Config(style: small),
          H5Config(style: small),
          H6Config(style: small),
          HrConfig(height: 1, color: colorScheme.outlineVariant),
          // the stock number sits flush right with a 1pt gap, which reads as
          // "1.Slowly roll…"; bullets keep the stock dot (null falls back)
          ListConfig(
            marker: (isOrdered, _, index) => switch (isOrdered) {
              true => Padding(
                padding: const .only(right: 6),
                child: Align(
                  alignment: .topRight,
                  child: Text('${index + 1}.', style: textTheme.bodyMedium),
                ),
              ),
              false => null,
            },
          ),
        ],
      ),
    );
  }
}

final _generator = MarkdownGenerator(
  linesMargin: const .symmetric(vertical: 4),
  generators: [
    SpanNodeGeneratorWithTag(tag: MarkdownTag.a.name, generator: (_, _, _) => ConcreteElementNode()),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h1.name, generator: (_, config, visitor) => _Heading(config.h1, visitor)),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h2.name, generator: (_, config, visitor) => _Heading(config.h2, visitor)),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h3.name, generator: (_, config, visitor) => _Heading(config.h3, visitor)),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h4.name, generator: (_, config, visitor) => _Heading(config.h4, visitor)),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h5.name, generator: (_, config, visitor) => _Heading(config.h5, visitor)),
    SpanNodeGeneratorWithTag(tag: MarkdownTag.h6.name, generator: (_, config, visitor) => _Heading(config.h6, visitor)),
  ],
);

/// A heading as a header node, with no divider under it.
///
/// markdown_widget builds a heading as bare text spans, which a screen reader
/// cannot tell from a paragraph; the only way to mark it is to lift it into a
/// widget of its own.
class _Heading extends HeadingNode {
  new(super.headingConfig, super.visitor);

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: Padding(
        padding: headingConfig.padding,
        child: Semantics(header: true, child: Text.rich(childrenSpan)),
      ),
    );
  }
}
