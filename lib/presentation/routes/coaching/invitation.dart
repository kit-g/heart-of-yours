part of 'coaching.dart';

/// What a coach's invitation link opens (#553): who sent it, what accepting
/// means, and the answer. This page is Your coach's ask (`docs/opt-in.md`):
/// accepting is the yes, and anything else leaves the switch where it was,
/// asked about.
///
/// [fingerprint] is the link's fragment: the coach's key fingerprint, kept on
/// this device for #555 to check their keys against.
class InvitationPage extends StatefulWidget {
  final String token;
  final String? fingerprint;

  /// Leaves the page, however it was answered.
  final VoidCallback onDone;

  /// To making an account; the link is kept, and opens again once there is one.
  final VoidCallback onMakeAccount;

  const new({
    super.key,
    required this.token,
    this.fingerprint,
    required this.onDone,
    required this.onMakeAccount,
  });

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  late final Future<InvitationPreview?> _preview = Coaching.of(context).preview(widget.token);

  /// What the person opens beyond the workouts logged from now on: nothing
  /// unless they say so.
  final _shares = ValueNotifier<Set<ConnectionShare>>(const {});

  /// An answer on its way, so a second tap doesn't send another.
  final _busy = ValueNotifier(false);

  /// The link stopped being good while the page was open.
  final _gone = ValueNotifier(false);

  @override
  void dispose() {
    _shares.dispose();
    _busy.dispose();
    _gone.dispose();
    super.dispose();
  }

  /// The person was asked, whatever they answered: Your coach's switch shows
  /// in Settings from now on.
  void _asked() => Preferences.of(context).markOffered(.yourCoach);

  Future<void> _answer(Future<void> Function() answer) async {
    if (_busy.value) return;
    _busy.value = true;
    try {
      await answer();
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  Future<void> _accept(String? name) {
    return _answer(() async {
      final messenger = ScaffoldMessenger.of(context);
      final l = L.of(context);
      final preferences = Preferences.of(context);
      try {
        final accepted = await Coaching.of(context).accept(widget.token, _shares.value);
        if (accepted.connection.connectionId case final String id) {
          if (name != null) await preferences.rememberCoachName(id, name);
          if (widget.fingerprint case final String fingerprint when fingerprint.isNotEmpty) {
            await preferences.rememberCoachFingerprint(id, fingerprint);
          }
        }
        // the ask's yes; the server turned it on in the account too
        preferences.answerOffer(.yourCoach, yes: true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (name) {
              final String name => l.invitationAccepted(name),
              null => l.invitationAcceptedSomeone,
            }),
          ),
        );
        widget.onDone();
      } catch (error) {
        switch (error) {
          case {'code': 'invitation_gone'}:
            _gone.value = true;
          case {'code': 'own_invitation'}:
            messenger.showSnackBar(SnackBar(content: Text(l.invitationOwn)));
          default:
            messenger.showSnackBar(SnackBar(content: Text(l.invitationFailed)));
        }
      }
    });
  }

  Future<void> _decline() {
    return _answer(() async {
      final messenger = ScaffoldMessenger.of(context);
      final l = L.of(context);
      try {
        await Coaching.of(context).decline(widget.token);
        _asked();
        widget.onDone();
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l.invitationFailed)));
      }
    });
  }

  Future<void> _block() {
    return _answer(() async {
      final messenger = ScaffoldMessenger.of(context);
      final l = L.of(context);
      try {
        await Coaching.of(context).blockInviter(widget.token);
        _asked();
        messenger.showSnackBar(SnackBar(content: Text(l.invitationBlocked)));
        widget.onDone();
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l.invitationFailed)));
      }
    });
  }

  void _makeAccount() {
    Preferences.of(context).setPendingInvitation((token: widget.token, fingerprint: widget.fingerprint));
    widget.onMakeAccount();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: widget.onDone),
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: FutureBuilder<InvitationPreview?>(
            future: _preview,
            builder: (context, snapshot) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gone,
                builder: (context, gone, _) {
                  return switch ((snapshot.connectionState, snapshot.data, gone)) {
                    (.waiting, _, _) => const Center(child: CircularProgressIndicator()),
                    (_, InvitationPreview(good: true) && final preview, false) => _ask(context, preview),
                    _ => _Empty(icon: Icons.link_off_rounded, title: l.invitationGone, body: l.invitationGoneBody),
                  };
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _ask(BuildContext context, InvitationPreview preview) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final name = switch (preview.inviterName?.trim()) {
      final String name when name.isNotEmpty => name,
      _ => null,
    };
    final anonymous = Auth.watch(context).isAnonymous;

    Widget heading(String text) => Padding(
      padding: const .only(top: 24, bottom: 8),
      child: Text(text, style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
    );
    Widget line(IconData icon, String text) => Padding(
      padding: const .symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          Expanded(child: Text(text, style: textTheme.bodyLarge)),
        ],
      ),
    );

    // the explanation scrolls, and the answers stay in reach under it
    return Column(
      key: AppKeys.invitationPage,
      children: [
        Expanded(
          child: ListView(
            padding: const .fromLTRB(16, 0, 16, 24),
            children: [
              Center(child: Avatar(remote: preview.inviterAvatar, radius: 40)),
              const SizedBox(height: 16),
              Text(
                switch (name) {
                  final String name => l.invitationFrom(name),
                  null => l.invitationFromSomeone,
                },
                style: textTheme.titleLarge,
                textAlign: .center,
              ),
              heading(l.invitationSees),
              line(Icons.fitness_center_rounded, l.invitationSeesWorkouts),
              line(Icons.event_repeat_rounded, l.invitationSeesProgram),
              line(Icons.redo_rounded, l.invitationSeesSkips),
              heading(l.invitationCan),
              line(Icons.edit_calendar_rounded, l.invitationCanPrograms),
              line(Icons.forum_outlined, l.invitationCanMessage),
              heading(l.invitationNever),
              line(Icons.visibility_off_outlined, l.invitationNeverList),
              heading(l.invitationAlsoShare),
              ValueListenableBuilder<Set<ConnectionShare>>(
                valueListenable: _shares,
                builder: (context, shares, _) {
                  Widget share(ConnectionShare share, String title, Key key) => SwitchListTile(
                    key: key,
                    contentPadding: .zero,
                    title: Text(title),
                    value: shares.contains(share),
                    onChanged: (on) => _shares.value = switch (on) {
                      true => {...shares, share},
                      false => {...shares}..remove(share),
                    },
                  );
                  return Column(
                    children: [
                      share(.history, l.invitationShareHistory, AppKeys.invitationShareHistory),
                      share(.goals, l.invitationShareGoals, AppKeys.invitationShareGoals),
                    ],
                  );
                },
              ),
              Text(l.invitationSharesNote, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const .fromLTRB(16, 8, 16, 8),
            child: ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (context, busy, _) {
                return Column(
                  crossAxisAlignment: .stretch,
                  spacing: 8,
                  children: switch (anonymous) {
                    // coaching needs an account: the one way forward is to make one
                    true => [
                      Text(l.invitationNeedsAccount, style: textTheme.bodyMedium, textAlign: .center),
                      FilledButton(
                        key: AppKeys.invitationMakeAccount,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _makeAccount,
                        child: Text(l.invitationMakeAccount),
                      ),
                    ],
                    false => [
                      FilledButton(
                        key: AppKeys.invitationAccept,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: switch (busy) {
                          true => null,
                          false => () => _accept(name),
                        },
                        child: Text(l.invitationAccept),
                      ),
                      OutlinedButton(
                        key: AppKeys.invitationDecline,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: switch (busy) {
                          true => null,
                          false => _decline,
                        },
                        child: Text(l.invitationDecline),
                      ),
                      TextButton(
                        key: AppKeys.invitationBlock,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: colorScheme.error,
                        ),
                        onPressed: switch (busy) {
                          true => null,
                          false => _block,
                        },
                        child: Text(l.invitationBlock),
                      ),
                    ],
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
