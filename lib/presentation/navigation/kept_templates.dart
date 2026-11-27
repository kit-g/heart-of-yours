import 'package:flutter/widgets.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// Gives [Templates] the words for a template it keeps beside the one that
/// replaced it on the server (#448): the user's own changes, made while the
/// server was out of reach, under a name that says whose they are.
///
/// Here because the name is copy and the read that needs it has no page: it
/// runs at launch and whenever the app comes back. In the language the app
/// shows at that moment, and again when that changes.
class KeptTemplatesPresenter extends StatefulWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  State<KeptTemplatesPresenter> createState() => _KeptTemplatesPresenterState();
}

class _KeptTemplatesPresenterState extends State<KeptTemplatesPresenter> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = L.of(context);
    Templates.of(context).keptName = (name) => l.templateYourChangesName(name ?? l.template);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
