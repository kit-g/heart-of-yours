import 'package:flutter/material.dart';

class AppBarTextField extends StatelessWidget {
  final String hint;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;
  final TextEditingController controller;

  const AppBarTextField({
    super.key,
    required this.hint,
    this.style,
    this.hintStyle,
    required this.onChanged,
    required this.focusNode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        return ListenableBuilder(
          listenable: focusNode,
          builder: (_, _) {
            final needsSuffix = value.text.isNotEmpty && focusNode.hasFocus;
            return TextField(
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: hintStyle,
                suffixIcon: switch (needsSuffix) {
                  false => null,
                  true => IconButton(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      onPressed: () {
                        focusNode.unfocus();
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                    ),
                },
                counter: const SizedBox.shrink(), // no counter widget
              ),
              style: style,
              onChanged: onChanged,
              focusNode: focusNode,
              onTapOutside: (_) {
                focusNode.unfocus();
              },
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              maxLines: 1,
              maxLength: 60,
            );
          },
        );
      },
    );
  }
}
