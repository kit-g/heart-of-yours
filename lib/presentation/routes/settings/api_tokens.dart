part of 'settings.dart';

/// Where a token goes: the one page that says what to call and how.
final _developerDocs = Uri.https('heart-of.me', '/developers.html');

/// The export page's button margin: the house 32pt button grown to a 48pt
/// target, for the handful of buttons here that are the page's only action.
const _tallButton = EdgeInsets.symmetric(horizontal: 8.0, vertical: 14);

/// The purpose menu's width: the house 56pt step that fits its longest label.
const _purposeMenuWidth = 224.0;

/// The purpose's copy. The wire value is the owner's label for the token,
/// nothing the app acts on, so a null one has words too.
extension on ApiTokenPurpose? {
  String label(L l) {
    return switch (this) {
      .script => l.apiTokenPurposeScript,
      .spreadsheet => l.apiTokenPurposeSpreadsheet,
      .homeAutomation => l.apiTokenPurposeHomeAutomation,
      .aiAssistant => l.apiTokenPurposeAiAssistant,
      .other => l.apiTokenPurposeOther,
      null => l.apiTokenPurposeUnset,
    };
  }
}

/// The account's personal access tokens for the developer API (#271): what
/// they are for, the ones it holds, and the way to one more.
///
/// Reads the server on every open. The list is the server's, a token minted
/// on another device since the last visit belongs here, and there is no
/// local copy to paint from first: a credential for the server has nothing to
/// show without one. Signed-in only, by way of the Settings section it sits
/// in — an anonymous session has no account to hold a token.
class ApiTokensPage extends StatefulWidget {
  final VoidCallback onNewToken;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, required this.onNewToken, this.onError});

  @override
  State<ApiTokensPage> createState() => _ApiTokensPageState();
}

class _ApiTokensPageState extends State<ApiTokensPage> with HasHaptic<ApiTokensPage> {
  @override
  void initState() {
    super.initState();
    // after the first frame, not in it: the read notifies at once, and a
    // notification during the build that mounts this page reaches whoever
    // else is watching the list mid-frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ApiTokens.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :developerApi,
      :apiTokensExplainer,
      :exportNoHealthData,
      :apiTokensHowTo,
      :newApiToken,
      :apiTokensAtCapacity,
      :apiTokensEmpty,
      :apiTokensLoadFailed,
      :retry,
      :apiTokensActive,
      :apiTokensPast,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme) = Theme.of(context);
    final tokens = ApiTokens.watch(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(developerApi),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      // capped and centred the way the settings list is: rows with an action
      // at the far edge, which on a landscape iPad would otherwise sit a
      // screen away from the name it belongs to
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: .symmetric(horizontal: math.max(0, (constraints.maxWidth - _maxWidth) / 2)),
          children: [
            Padding(
              padding: const .all(16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(apiTokensExplainer),
                  const SizedBox(height: 12),
                  Text(exportNoHealthData, style: textTheme.bodySmall),
                ],
              ),
            ),
            ListTile(
              key: AppKeys.apiTokensDocs,
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(apiTokensHowTo),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: _openDocs,
            ),
            const SizedBox(height: 16),
            // the list is the server's: until it has been read once there is
            // nothing to offer a token against, and a create button over an
            // unread list would offer one the account may not have room for
            ...switch ((tokens.status, tokens.all.isEmpty)) {
              (.idle || .loading, true) => const [LinearProgressIndicator()],
              (.failed, true) => [
                Padding(
                  padding: const .symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 12,
                    children: [
                      Text(apiTokensLoadFailed),
                      PrimaryButton.shrunk(
                        key: AppKeys.retryApiTokens,
                        margin: _tallButton,
                        onPressed: tokens.load,
                        child: Text(retry),
                      ),
                    ],
                  ),
                ),
              ],
              (.idle || .loading || .loaded || .failed, _) => [
                Padding(
                  padding: const .symmetric(horizontal: 16),
                  // absent rather than dead at the cap: the sentence that
                  // takes the button's place says what frees it
                  child: switch (tokens.isAtCapacity) {
                    true => Text(apiTokensAtCapacity(ApiToken.maxActive), style: textTheme.bodySmall),
                    false => PrimaryButton.wide(
                      key: AppKeys.newApiToken,
                      margin: _tallButton,
                      onPressed: widget.onNewToken,
                      child: Center(
                        child: Row(
                          mainAxisSize: .min,
                          spacing: 8,
                          children: [
                            const Icon(Icons.add_rounded),
                            Text(newApiToken),
                          ],
                        ),
                      ),
                    ),
                  },
                ),
                const SizedBox(height: 24),
                if (tokens.all.isEmpty)
                  Padding(
                    padding: const .symmetric(horizontal: 16),
                    child: Text(apiTokensEmpty, style: textTheme.bodySmall),
                  ),
                if (tokens.active.isNotEmpty)
                  _Section(
                    title: apiTokensActive,
                    children: [
                      for (final token in tokens.active)
                        _TokenRow(
                          token: token,
                          onRevoke: () => _confirmRevoke(context, token),
                        ),
                    ],
                  ),
                if (tokens.inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: apiTokensPast,
                    children: [
                      for (final token in tokens.inactive) _TokenRow(token: token),
                    ],
                  ),
                ],
              ],
            },
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocs() {
    return launchUrl(_developerDocs, mode: LaunchMode.externalApplication);
  }

  /// Irreversible, so it is the one action here that asks first.
  Future<void> _confirmRevoke(BuildContext context, ApiToken token) {
    final L(:revokeApiTokenTitle, :revokeApiTokenBody, :keepApiToken, :revokeApiToken) = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);

    return showBrandedDialog(
      context,
      title: Text(
        revokeApiTokenTitle(token.name),
        textAlign: .center,
      ),
      content: Padding(
        padding: const .all(8.0),
        child: Text(
          revokeApiTokenBody,
          textAlign: .center,
        ),
      ),
      icon: Icon(Icons.link_off_rounded, color: colorScheme.error),
      actions: [
        _RevokeActions(
          keepCopy: keepApiToken,
          revokeCopy: revokeApiToken,
          onRevoke: () {
            Navigator.of(context, rootNavigator: true).pop();
            _revoke(context, token);
          },
        ),
      ],
    );
  }

  Future<void> _revoke(BuildContext context, ApiToken token) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    final analytics = Analytics.of(context);
    try {
      await ApiTokens.of(context).revoke(token);
      analytics.apiTokenRevoked();
    } on ApiTokenRejected catch (e) {
      messenger.snack(e.reason ?? l.noConnectivity);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(l.noConnectivity);
    }
  }
}

/// One token: its name, what it is for and the tail of its secret, its dates,
/// and the way to revoke it while it still works.
class _TokenRow extends StatelessWidget {
  final ApiToken token;

  /// Null for a token that is already past: nothing left to revoke.
  final VoidCallback? onRevoke;

  const new({required this.token, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final format = DateFormat.yMMMd(l.localeName);
    String date(DateTime at) => format.format(at.toLocal());

    final status = switch ((token.revokedAt, token.expiresAt)) {
      (DateTime at, _) => l.apiTokenRevokedOn(date(at)),
      (null, DateTime at) when !at.isAfter(DateTime.now()) => l.apiTokenExpiredOn(date(at)),
      (null, DateTime at) => l.apiTokenExpiresOn(date(at)),
      (null, null) => l.apiTokenNeverExpires,
    };
    final used = switch (token.lastUsedAt) {
      DateTime at => l.apiTokenLastUsedOn(date(at)),
      null => l.apiTokenNeverUsed,
    };
    final what = [
      if (token.purpose case final purpose?) purpose.label(l),
      l.apiTokenEndsWith(token.hint),
    ].join(' · ');

    return ListTile(
      key: AppKeys.apiTokenRow(token.id),
      // a three-line tile pins its leading and trailing to the top by
      // default; the key and the revoke belong level with the name block
      titleAlignment: .center,
      leading: Icon(onRevoke == null ? Icons.key_off_rounded : Icons.key_rounded),
      title: Text(token.name),
      subtitle: Text(
        '$what\n${l.apiTokenCreatedOn(date(token.createdAt))} · $status\n$used',
        style: textTheme.bodySmall,
      ),
      isThreeLine: true,
      trailing: switch (onRevoke) {
        VoidCallback revoke => IconButton(
          key: AppKeys.revokeApiToken(token.id),
          tooltip: l.revokeApiToken,
          icon: Icon(Icons.link_off_rounded, color: colorScheme.error),
          onPressed: revoke,
        ),
        null => null,
      },
    );
  }
}

/// The revoke dialog's two actions: a neutral fill for keeping the token, the
/// error container for the revoke. A widget for the reason `_EraseDataActions`
/// is: the fills follow the theme the dialog is showing under.
class _RevokeActions extends StatelessWidget {
  final String keepCopy;
  final String revokeCopy;
  final VoidCallback onRevoke;

  const new({required this.keepCopy, required this.revokeCopy, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Column(
      spacing: 8,
      children: [
        PrimaryButton.wide(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Text(keepCopy),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        PrimaryButton.wide(
          key: AppKeys.confirmRevokeApiToken,
          backgroundColor: colorScheme.errorContainer,
          onPressed: onRevoke,
          child: Center(
            child: Text(
              revokeCopy,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mints a token: a name, how long it lives, optionally what it is for. Once
/// minted, the same page turns into the one showing of the secret.
///
/// The reveal is in-page rather than a dialog over the list so nothing can
/// dismiss it by accident: a tap beside a dialog would have been the last
/// anyone saw of the secret. Leaving is the explicit action at the bottom.
class NewApiTokenPage extends StatefulWidget {
  final VoidCallback onDone;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, required this.onDone, this.onError});

  @override
  State<NewApiTokenPage> createState() => _NewApiTokenPageState();
}

class _NewApiTokenPageState extends State<NewApiTokenPage>
    with LoadingState<NewApiTokenPage>, HasHaptic<NewApiTokenPage> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _expiry = ValueNotifier<ApiTokenExpiry>(.year);
  final _purpose = ValueNotifier<ApiTokenPurpose?>(null);
  final _minted = ValueNotifier<MintedApiToken?>(null);
  final _purposeKey = GlobalKey();

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _expiry.dispose();
    _purpose.dispose();
    _minted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:newApiToken) = L.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(newApiToken),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // a short form, then a paragraph and a secret: a readable column
          final width = math.min(constraints.maxWidth, readableWidth);
          return Align(
            alignment: .topCenter,
            child: SizedBox(
              width: width,
              child: ValueListenableBuilder<MintedApiToken?>(
                valueListenable: _minted,
                builder: (context, minted, _) {
                  return switch (minted) {
                    MintedApiToken token => _Reveal(minted: token, onDone: widget.onDone),
                    null => _form(context),
                  };
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final L(
      :name,
      :apiTokenNameHint,
      :apiTokenExpiry,
      :apiTokenExpiryYear,
      :apiTokenExpiryNever,
      :apiTokenPurpose,
      :apiTokenPurposeHelp,
      :createApiToken,
    ) = L.of(
      context,
    );
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    // vertical padding on the list, horizontal on each row: the purpose tile
    // is an ink surface, and inside a padded list its splash stopped a
    // gutter short of the edges while the ripple ran on underneath
    return ListView(
      padding: const .symmetric(vertical: 16),
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(name, style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: TextField(
            key: AppKeys.apiTokenName,
            controller: _name,
            focusNode: _nameFocus,
            autofocus: true,
            autocorrect: false,
            textCapitalization: .sentences,
            textInputAction: .done,
            // the server's cap, applied at the keyboard rather than reported
            // after a round trip
            inputFormatters: [LengthLimitingTextInputFormatter(ApiToken.maxNameLength)],
            decoration: InputDecoration(hintText: apiTokenNameHint),
            selectionControls: context.platformSpecificSelectionControls(),
            onSubmitted: (_) => _create(context),
          ),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<ApiTokenExpiry>(
          valueListenable: _expiry,
          builder: (_, expiry, _) {
            return Padding(
              padding: const .symmetric(horizontal: 16),
              child: FixedLengthSettingPicker<ApiTokenExpiry>(
                title: apiTokenExpiry,
                value: expiry,
                onValueChanged: (picked) {
                  buzz();
                  if (picked != null) _expiry.value = picked;
                },
                children: {
                  .year: Text(apiTokenExpiryYear),
                  .never: Text(apiTokenExpiryNever),
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<ApiTokenPurpose?>(
          valueListenable: _purpose,
          builder: (_, purpose, _) {
            return ListTile(
              contentPadding: const .symmetric(horizontal: 16),
              title: Text(apiTokenPurpose),
              // the menu hangs off the value, not the row's far-left edge
              trailing: Row(
                key: _purposeKey,
                mainAxisSize: .min,
                spacing: 4,
                children: [
                  Text(purpose.label(l), style: textTheme.bodyMedium),
                  const Icon(Icons.unfold_more_rounded, size: 20),
                ],
              ),
              onTap: () => _pickPurpose(context),
            );
          },
        ),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(apiTokenPurposeHelp, style: textTheme.bodySmall),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: ValueListenableBuilder<bool>(
            valueListenable: loader,
            builder: (_, loading, _) {
              // live even before there is a name: a tap then only puts the
              // caret back in the field, and a greyed button is ink the dark
              // presets cannot carry legibly
              return switch (loading) {
                true => const LinearProgressIndicator(),
                false => PrimaryButton.wide(
                  key: AppKeys.createApiToken,
                  margin: _tallButton,
                  onPressed: () => _create(context),
                  child: Center(
                    child: Text(createApiToken),
                  ),
                ),
              };
            },
          ),
        ),
      ],
    );
  }

  /// The five purposes and "not saying", as a popup off the row — the house
  /// menu, and the one control that fits six choices on a phone.
  Future<void> _pickPurpose(BuildContext context) {
    final l = L.of(context);
    buzz();
    return showMenu<ApiTokenPurpose?>(
      context: context,
      position: _underValue(context, _purposeKey, width: _purposeMenuWidth),
      constraints: const BoxConstraints(minWidth: _purposeMenuWidth, maxWidth: _purposeMenuWidth),
      items: [
        for (final purpose in [null, ...ApiTokenPurpose.values])
          PopupMenuItem<ApiTokenPurpose?>(
            value: purpose,
            key: AppKeys.apiTokenPurposeOption(purpose),
            // on the item, not the menu's result: a dismissed menu and
            // "not saying" would both come back as null
            onTap: () => _purpose.value = purpose,
            child: Text(purpose.label(l)),
          ),
      ],
    );
  }

  /// Where the purpose menu opens: under the value, its right edge on the
  /// value's. `Position.position()` hangs a menu off a widget's *left* edge,
  /// which is right for a leading button and wrong for a trailing value,
  /// where the menu then runs past the column.
  ///
  /// Measured against the navigator's overlay, not the window: `showMenu`
  /// lays the menu out in that overlay, and inside the two-pane shell the
  /// overlay starts after the rail, so a window offset lands the menu a
  /// rail's width to the right of the value.
  static RelativeRect _underValue(BuildContext context, GlobalKey key, {required double width}) {
    final box = key.currentContext?.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return RelativeRect.fill;
    final Offset(:dx, :dy) = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Size(width: w, height: h) = box.size;
    return RelativeRect.fromLTRB(dx + w - width, dy + h, overlay.size.width - (dx + w), dy + h);
  }

  Future<void> _create(BuildContext context) async {
    final name = _name.text.trim();
    if (isLoading) return;
    if (name.isEmpty) {
      _nameFocus.requestFocus();
      return;
    }
    buzz();
    _nameFocus.unfocus();
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final analytics = Analytics.of(context);
    final tokens = ApiTokens.of(context);
    final expiry = _expiry.value;
    final purpose = _purpose.value;
    var atCapacity = false;

    startLoading();
    try {
      final minted = await tokens.create(name: name, expiry: expiry, purpose: purpose);
      analytics.apiTokenCreated(purpose: purpose, expiry: expiry);
      _minted.value = minted;
    } on ApiTokenRejected catch (e) {
      atCapacity = e.isAtCapacity;
      messenger.snack(
        switch (atCapacity) {
          true => l.apiTokensAtCapacity(ApiToken.maxActive),
          false => e.reason ?? l.noConnectivity,
        },
      );
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(l.noConnectivity);
    } finally {
      stopLoading();
    }
    // the list knows better than this form now: it re-read itself on the
    // refusal, and shows the sentence that says what frees a slot
    if (atCapacity && mounted) widget.onDone();
  }
}

/// The secret, once. Copy is the primary action; leaving is explicit.
class _Reveal extends StatelessWidget {
  final MintedApiToken minted;
  final VoidCallback onDone;

  const new({required this.minted, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final L(
      :apiTokenReady,
      :apiTokenRevealBody,
      :apiTokenSecretLabel,
      :copyApiToken,
      :apiTokenCopied,
      :apiTokenStored,
    ) = L.of(
      context,
    );
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return ListView(
      padding: const .all(16),
      children: [
        const SizedBox(height: 16),
        Icon(Icons.key_rounded, size: 48, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(apiTokenReady, style: textTheme.titleLarge, textAlign: .center),
        const SizedBox(height: 12),
        Text(apiTokenRevealBody, textAlign: .center),
        const SizedBox(height: 24),
        Semantics(
          label: apiTokenSecretLabel,
          child: Container(
            padding: const .all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: .circular(8),
            ),
            child: SelectableText(
              minted.secret,
              key: AppKeys.apiTokenSecret,
              textAlign: .center,
              style: textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Menlo', 'Courier New'],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton.wide(
          key: AppKeys.copyApiToken,
          margin: _tallButton,
          onPressed: () {
            copyToClipboard(minted.secret);
            snack(context, apiTokenCopied);
          },
          child: Center(
            child: Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                const Icon(Icons.copy_rounded),
                Text(copyApiToken),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton.wide(
          key: AppKeys.apiTokenStored,
          margin: _tallButton,
          backgroundColor: colorScheme.surfaceContainerHighest,
          onPressed: onDone,
          child: Center(
            child: Text(apiTokenStored),
          ),
        ),
      ],
    );
  }
}
