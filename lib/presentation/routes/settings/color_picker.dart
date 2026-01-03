part of 'settings.dart';

class _ColorPicker extends StatefulWidget {
  const _ColorPicker();

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> with HasHaptic<_ColorPicker> {
  Color? _color;

  @override
  Widget build(BuildContext context) {
    final L(:customThemeColorSetting, :customThemeColorSettingSubtitle, :reset) = L.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customThemeColorSetting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              customThemeColorSettingSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Consumer<AppTheme>(
          builder: (_, theme, _) {
            return Row(
              children: [
                if (theme.color != null)
                  TextButton(
                    onPressed: () {
                      final auth = Auth.of(context);
                      theme.color = null;
                      Preferences.of(context).setBaseColor(auth.user?.id, null);
                    },
                    child: Text(reset),
                  ),
                IconButton(
                  onPressed: () => _showColorPicker(context),
                  icon: Icon(
                    Icons.color_lens_rounded,
                    color: theme.color,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showColorPicker(BuildContext context) {
    final L(:cancel, :ok) = L.of(context);
    buzz();
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(500),
              bottom: Radius.circular(100),
            ),
          ),
          content: SingleChildScrollView(
            child: HueRingPicker(
              portraitOnly: true,
              pickerColor: AppTheme.of(context).color ?? Theme.of(context).colorScheme.primary,
              onColorChanged: (color) => _color = color,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                buzz();
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cancel),
              ),
            ),
            TextButton(
              onPressed: () {
                buzz();
                final auth = Auth.of(context);
                AppTheme.of(context).color = _color;
                Preferences.of(context).setBaseColor(auth.user?.id, _color?.toHexString());
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(ok),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        );
      },
    );
  }
}
