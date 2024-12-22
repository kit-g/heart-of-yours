import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final VoidCallback? onClear;
  final String? hint;

  const SearchField({
    super.key,
    required this.focusNode,
    required this.controller,
    this.onClear,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (__, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            filled: true,
            hintText: hint,
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 24,
            ),
            suffixIcon: switch (focusNode.hasFocus) {
              true => GestureDetector(
                  onTap: onClear ?? _onClear,
                  child: const Icon(Icons.close_rounded),
                ),
              false => null,
            },
          ),
        );
      },
    );
  }

  void _onClear() {
    controller.clear();
    focusNode.unfocus();
  }
}
