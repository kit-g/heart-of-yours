part of 'coaching.dart';

/// What a coach's invitation link opens (#553): who sent it, what accepting
/// means, and the answer. This page is Your coach's ask (`docs/opt-in.md`):
/// accepting is the yes; Not now, Block or closing the page is a no, owed the
/// one "you can turn this on in Settings" notice, unless Your coach was
/// already answered, by an earlier coach.
///
/// [fingerprint] is the link's fragment: the coach's key fingerprint, kept on
/// this device for #555 to check their keys against.
///
/// Keyed by its token where it is built: a second link opened over the first
/// is a new page, never the first one's preview answering for the second.
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
  /// The preview, again on a retry.
  late final _preview = ValueNotifier(_read());

  /// What the person opens beyond the workouts logged from now on: nothing
  /// unless they say so.
  final _shares = ValueNotifier<Set<ConnectionShare>>(const {});

  /// An answer on its way, so a second tap doesn't send another.
  final _busy = ValueNotifier(false);

  /// The link stopped being good while the page was open.
  final _gone = ValueNotifier(false);

  /// The ask was on screen: closing the page is then an answer.
  var _asked = false;

  @override
  void dispose() {
    _preview.dispose();
    _shares.dispose();
    _busy.dispose();
    _gone.dispose();
    super.dispose();
  }

  /// A failure to read is reported, and shown as one: the link may well still
  /// be good, so the page never calls it dead for an outage.
  Future<InvitationPreview?> _read() {
    final coaching = Coaching.of(context);
    return coaching.preview(widget.token).catchError((Object error, StackTrace stacktrace) {
      coaching.onError?.call(error, stacktrace: stacktrace);
      throw error;
    });
  }

  /// A no to Your coach, when it is still the question: the one notice, and
  /// then the switch is the only way on. An earlier coach's yes stays a yes.
  void _no(ScaffoldMessengerState messenger, L l) {
    final preferences = Preferences.of(context);
    switch (preferences.featureAnswer(.yourCoach)) {
      case .unasked || .pending:
        preferences.answerOffer(.yourCoach, yes: false);
        preferences.acknowledgeDeclineNotice(.yourCoach);
        messenger.snack(l.featureDeclinedNotice);
      case .on || .off:
        break;
    }
  }

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
        messenger.snack(switch (name) {
          final String name => l.invitationAccepted(name),
          null => l.invitationAcceptedSomeone,
        });
        widget.onDone();
      } catch (error) {
        switch (error) {
          case {'code': 'invitation_gone'}:
            _gone.value = true;
          case {'code': 'own_invitation'}:
            messenger.snack(l.invitationOwn);
          default:
            messenger.snack(l.invitationFailed);
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
        _no(messenger, l);
        widget.onDone();
      } catch (_) {
        messenger.snack(l.invitationFailed);
      }
    });
  }

  Future<void> _block() {
    return _answer(() async {
      final messenger = ScaffoldMessenger.of(context);
      final l = L.of(context);
      try {
        await Coaching.of(context).blockInviter(widget.token);
        messenger.snack(l.invitationBlocked);
        _no(messenger, l);
        widget.onDone();
      } catch (_) {
        messenger.snack(l.invitationFailed);
      }
    });
  }

  /// Closed with the ask on screen: a dismissal, which the contract reads as no.
  void _close() {
    if (_asked) _no(ScaffoldMessenger.of(context), L.of(context));
    widget.onDone();
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
        leading: CloseButton(onPressed: _close),
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: ValueListenableBuilder<Future<InvitationPreview?>>(
            valueListenable: _preview,
            builder: (context, preview, _) => FutureBuilder<InvitationPreview?>(
              future: preview,
              builder: (context, snapshot) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _gone,
                  builder: (context, gone, _) {
                    return switch ((snapshot.connectionState, snapshot.hasError, snapshot.data, gone)) {
                      (.waiting, _, _, _) => const Center(child: CircularProgressIndicator()),
                      (_, true, _, _) => _Empty(
                        icon: Icons.cloud_off_rounded,
                        title: l.invitationLoadFailed,
                        body: l.invitationLoadFailedBody,
                        action: FilledButton(
                          key: AppKeys.invitationRetry,
                          style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                          onPressed: () => _preview.value = _read(),
                          child: Text(l.retry),
                        ),
                      ),
                      (_, false, InvitationPreview(good: true) && final preview, false) => _ask(context, preview),
                      _ => _Empty(icon: Icons.link_off_rounded, title: l.invitationGone, body: l.invitationGoneBody),
                    };
                  },
                );
              },
            ),
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
    _asked = true;

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
