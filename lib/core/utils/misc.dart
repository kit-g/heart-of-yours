import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin AfterLayoutMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted) {
          afterFirstLayout(context);
        }
      },
    );
  }

  void afterFirstLayout(BuildContext context);
}

void copyToClipboard(String content) {
  Clipboard.setData(ClipboardData(text: content));
}

mixin HasHaptic<T extends StatefulWidget> on State<T> {
  void buzz() {
    HapticFeedback.mediumImpact();
  }
}
