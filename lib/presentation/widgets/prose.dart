import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// A short markdown text — paragraphs, emphasis, lists — set in the theme's
/// own body style.
///
/// `MarkdownConfig.defaultConfig` would not do: it hardcodes its own sizes and
/// light-mode colours, so a preset's typeface and the dark palette never
/// reach it.
///
/// Links render as the plain text they wrap. The ones What's new carries are
/// app routes, and until something handles them a link is a dead control —
/// worse, markdown_widget's default tap hands the path to `launchUrl`, which
/// would try to open `/history` outside the app.
class Prose extends StatelessWidget {
  final String data;

  const new(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return MarkdownBlock(
      data: data,
      // selection would split the text into its own semantics nodes, and the
      // callers merge theirs into one announcement
      selectable: false,
      generator: _generator,
      config: MarkdownConfig(
        configs: [
          PConfig(textStyle: textTheme.bodyMedium ?? const TextStyle()),
          const ListConfig(marginLeft: 24),
        ],
      ),
    );
  }
}

final _generator = MarkdownGenerator(
  linesMargin: const .symmetric(vertical: 4),
  generators: [
    SpanNodeGeneratorWithTag(tag: MarkdownTag.a.name, generator: (_, _, _) => ConcreteElementNode()),
  ],
);
