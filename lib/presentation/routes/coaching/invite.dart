part of 'coaching.dart';

/// Where an invitation link goes: the site, which opens the app where it is
/// installed and invites on the web where it isn't (#553). [fingerprint], the
/// coach's device's keys (#555), rides after `#`, the part of an address that
/// never reaches a server, for the student's device to check the coach's keys
/// against.
Uri invitationLink(AppConfig config, String token, {String? fingerprint}) {
  return Uri.https(config.appDomain, '/invite.html', {'t': token}).replace(fragment: fingerprint);
}

/// Asks what the coach calls the person, makes their link, and hands it to the
/// share sheet: the coach sends it however they like.
Future<void> inviteSomeone(BuildContext context) async {
  final name = await showBrandedDialog<String>(
    context,
    title: Text(L.of(context).coachingInvite),
    content: const _InviteForm(),
  );
  if (name == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  final config = AppConfig.of(context);
  final origin = _shareOrigin(context);
  final keys = DeviceKeys.of(context);
  final Invitation invitation;
  try {
    invitation = await Coaching.of(context).invite(name);
  } catch (error) {
    messenger.snack(switch (error) {
      {'code': 'coaching_beta'} => l.coachingInviteBeta,
      _ => l.coachingInviteFailed,
    });
    return;
  }
  // made either way: it waits on Clients, and "Share a new link" sends it again
  if (invitation.token case final String token) await _share(l, config, token, origin, await keys.fingerprint());
  // the first thing that pushes a coach: hearing that the person accepted
  // (#567). Asked once the link is on its way, never before
  if (context.mounted) await askForPushes(context);
}

/// A fresh link for [invitation], shared again. The old one stops working.
Future<void> shareAgain(BuildContext context, Invitation invitation) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  final config = AppConfig.of(context);
  final origin = _shareOrigin(context);
  final keys = DeviceKeys.of(context);
  final Invitation renewed;
  try {
    renewed = await Coaching.of(context).resend(invitation);
  } catch (_) {
    messenger.snack(l.coachingInviteFailed);
    return;
  }
  if (renewed.token case final String token) await _share(l, config, token, origin, await keys.fingerprint());
}

Future<void> _share(L l, AppConfig config, String token, Rect? origin, String? fingerprint) {
  final link = invitationLink(config, token, fingerprint: fingerprint).toString();
  return SharePlus.instance.share(ShareParams(text: l.coachingInviteShareText(link), sharePositionOrigin: origin));
}

/// Where the iPad's share popover points; ignored everywhere else.
Rect? _shareOrigin(BuildContext context) {
  return switch (context.findRenderObject()) {
    RenderBox box when box.hasSize => box.localToGlobal(Offset.zero) & box.size,
    _ => null,
  };
}

/// The person's name, as the coach calls them. Pops with it, trimmed.
class _InviteForm extends StatefulWidget {
  const new();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        TextField(
          key: AppKeys.coachingInviteName,
          controller: _name,
          autofocus: true,
          textCapitalization: .words,
          textInputAction: .done,
          decoration: InputDecoration(hintText: l.coachingInviteNameHint),
          onSubmitted: (_) => _submit(),
        ),
        Text(l.coachingInviteNote, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        Row(
          mainAxisAlignment: .end,
          spacing: 8,
          children: [
            // the theme's buttons are compact; a dialog's answers stay a full tap target
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
            // a link needs someone to be for: absent rather than dead until then
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name,
              builder: (_, value, _) => switch (value.text.trim().isEmpty) {
                true => const SizedBox.shrink(),
                false => FilledButton(
                  key: AppKeys.coachingMakeLink,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: _submit,
                  child: Text(l.coachingMakeLink),
                ),
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// The coach's invitations nobody has answered yet, each with its way to share
/// a fresh link or withdraw it.
class _WaitingInvitations extends StatelessWidget {
  final List<Invitation> invitations;

  const new({required this.invitations});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final format = DateFormat.MMMd(l.localeName);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(16, 16, 16, 4),
          child: Text(
            l.coachingInvitesWaiting,
            style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        for (final invitation in invitations)
          ListTile(
            key: AppKeys.coachingInvitation(invitation.id),
            leading: const Icon(Icons.schedule_send_outlined),
            title: Text(invitation.name),
            subtitle: Text(l.coachingInviteUntil(format.format(invitation.expiresAt.toLocal()))),
            // its own context, so the menu and the iPad's share popover open
            // at this row's button rather than at the top of the list
            trailing: Builder(
              builder: (button) => IconButton(
                tooltip: l.moreOptions,
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () => _menu(button, invitation),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _menu(BuildContext context, Invitation invitation) async {
    final l = L.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final position = switch ((box, overlay)) {
      (final RenderBox box, final RenderBox overlay) => RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      _ => RelativeRect.fill,
    };
    final choice = await showMenu<_InvitationAction>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(value: .shareAgain, child: Text(l.coachingShareAgain)),
        PopupMenuItem(value: .cancel, child: Text(l.coachingCancelInvite)),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case .shareAgain:
        await shareAgain(context, invitation);
      case .cancel:
        final messenger = ScaffoldMessenger.of(context);
        final failed = L.of(context).coachingCancelFailed;
        try {
          await Coaching.of(context).cancel(invitation);
        } catch (_) {
          messenger.snack(failed);
        }
      case null:
        break;
    }
  }
}

enum _InvitationAction { shareAgain, cancel }
