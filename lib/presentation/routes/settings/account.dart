part of 'settings.dart';

class AccountManagementPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// Where to go once the account is scheduled for deletion.
  ///
  /// The sign-out that follows does not move anyone on its own: on mobile a
  /// missing user is replaced by an anonymous one at once (`Auth.ensureSession`),
  /// so the session stays valid, the router's gate never fires, and the page
  /// that manages an account sits there managing one that is on its way out.
  /// The anonymous "Erase my data" path has always had this, as `onErased`.
  final VoidCallback? onDeleted;

  const new({super.key, this.onError, this.onDeleted});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage>
    with LoadingState<AccountManagementPage>, HasHaptic<AccountManagementPage> {
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _obscurityController = ValueNotifier(true);
  final _avatarController = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _obscurityController.dispose();
    _avatarController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :accountControl,
      :deleteAccount,
      :dangerZone,
      :name,
      :saveName,
      :changeName,
      :resetPassword,
      :yourEmail,
    ) = L.of(
      context,
    );
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(accountControl),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: loader,
        builder: (_, loading, child) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final auth = Auth.watch(context);

          if (auth.user?.displayName case String name) {
            _nameController.text = name;
          }

          return ListView(
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<double?>(
                    valueListenable: _avatarController,
                    builder: (_, progress, _) {
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: progress == null ? 1 : .3,
                        child: EditableAvatar(
                          local: auth.user?.localAvatar,
                          remote: auth.user?.remoteAvatar,
                          radius: 60,
                          progress: progress,
                          onTap: switch (loading) {
                            true => null,
                            false => () => _onAvatar(context),
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (auth.user?.email case String email) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(yourEmail, style: textTheme.titleMedium),
                ),
                ListTile(title: Text(email)),
              ],
              // the account's sign-ins (#323): what opens it today, and the
              // way to add another, so one person stays one account
              _SignIns(
                onError: widget.onError,
                onSetPassword: () => _onResetPassword(context),
              ),
              ListTile(
                title: Text(resetPassword),
                onTap: () => _onResetPassword(context),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(changeName, style: textTheme.titleMedium),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (_, value, _) {
                  return ListenableBuilder(
                    listenable: _nameFocusNode,
                    builder: (context, _) {
                      final current = value.text.trim();
                      final hasChangedName = auth.user?.displayName != current;
                      final shouldSave = current.isNotEmpty && hasChangedName;
                      return ListTile(
                        title: TextField(
                          autocorrect: false,
                          focusNode: _nameFocusNode,
                          controller: _nameController,
                          selectionControls: context.platformSpecificSelectionControls(),
                          onSubmitted: (_) {
                            buzz();
                            if (shouldSave) {
                              auth.updateName(current);
                            }
                            _nameFocusNode.unfocus();
                          },
                          decoration: InputDecoration.collapsed(hintText: name),
                        ),
                        trailing: switch (_nameFocusNode.hasFocus) {
                          false => null,
                          true => IconButton(
                            tooltip: saveName,
                            icon: const Icon(Icons.check_circle_rounded),
                            onPressed: switch (shouldSave) {
                              true => () {
                                buzz();
                                auth.updateName(current);
                                _nameFocusNode.unfocus();
                              },
                              false => null,
                            },
                          ),
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  dangerZone,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
              ListTile(
                onTap: () {
                  _onDeleteAccount(context);
                },
                leading: Icon(
                  Icons.auto_delete_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  deleteAccount,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onResetPassword(BuildContext context) {
    final L(
      :resetPassword,
      :resetPasswordBody,
      :cancel,
      :ok,
      :noConnectivity,
      :recoveryLinkMessageSent,
    ) = L.of(
      context,
    );
    final ThemeData(:colorScheme) = Theme.of(context);
    final auth = Auth.of(context);
    return showBrandedDialog<void>(
      context,
      title: Text(resetPassword, textAlign: TextAlign.center),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(resetPasswordBody, textAlign: TextAlign.center),
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(child: Text(cancel, textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              child: Center(child: Text(ok, textAlign: TextAlign.center)),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                if (auth.user?.email case String email) {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    startLoading();
                    await auth.sendPasswordRecoveryEmail(email);
                    messenger.snack(recoveryLinkMessageSent);
                  } on AuthException catch (e, s) {
                    switch (e.reason) {
                      case AuthExceptionReason.networkRequestFailed:
                        messenger.snack(noConnectivity);
                      default:
                        widget.onError?.call(e, stacktrace: s);
                    }
                  } finally {
                    stopLoading();
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onDeleteAccount(BuildContext context) async {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :deleteAccountTitle,
      :deleteAccountBody,
      :deleteAccountCancelMessage,
      :deleteAccountConfirmMessage,
    ) = L.of(
      context,
    );

    return showBrandedDialog(
      context,
      title: Text(deleteAccountTitle, textAlign: TextAlign.center),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          deleteAccountBody(AppConfig.of(context).accountDeletionDeadline),
          textAlign: TextAlign.center,
        ),
      ),
      icon: Icon(Icons.auto_delete_rounded, color: colorScheme.error),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(child: Text(deleteAccountCancelMessage)),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteAccountConfirmMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                // Only an account that has a password can be asked for one.
                // Apple and Google accounts re-authenticate through their
                // provider instead, which is a sheet rather than a prompt —
                // asking them to type a password they never set is how
                // deletion used to be impossible for them.
                switch (Auth.of(context).hasPassword) {
                  case true:
                    _onConfirmDeleteAccount(context);
                  case false:
                    _requestAccountDeletion(context);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onConfirmDeleteAccount(BuildContext context) async {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :confirmDeleteAccountTitle,
      :yourPassword,
      :hidePassword,
      :showPassword,
      confirmDeleteAccountCancelMessage: cancel,
      confirmDeleteAccountOkMessage: ok,
    ) = L.of(
      context,
    );

    return showBrandedDialog(
      context,
      title: Text(confirmDeleteAccountTitle, textAlign: TextAlign.center),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: _obscurityController,
          builder: (_, hide, _) {
            return TextField(
              autocorrect: false,
              controller: _passwordController,
              obscureText: hide,
              decoration: InputDecoration(hintText: yourPassword),
              textAlign: .center,
              selectionControls: context.platformSpecificSelectionControls(),
            );
          },
        ),
      ),
      icon: Icon(Icons.auto_delete_rounded, color: colorScheme.error),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(child: Text(cancel)),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  ok,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _requestAccountDeletion(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    startLoading();
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    try {
      await Auth.of(context).scheduleAccountForDeletion(
        // Empty for a provider account; `Auth` only reads it where there is a
        // password to read.
        password: _passwordController.text.trim(),
        onAuthenticate: (token) {
          if (token != null) {
            Api.instance.authenticate(
              headers(
                config: AppConfig.of(context),
                sessionToken: token,
                appVersion: AppInfo.of(context).fullVersion,
                isWeb: kIsWeb,
              ),
            );
          }
        },
        // the profile's log-out pair, minus the sign-out Auth does itself: a
        // deleted account's history must not stay on screen in the anonymous
        // session that follows
        onScheduled: () {
          AppTheme.of(context).onSignOut();
          clearUserState(context);
        },
      );
      _passwordController.clear();
      widget.onDeleted?.call();
    } on AuthException {
      messenger.snack(l.invalidCredentials);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }

  Future<void> _uploadAvatar(
    BuildContext context,
    Future<LocalImage?> Function() getImage,
  ) async {
    final auth = Auth.of(context);
    final config = AppConfig.of(context);
    buzz();

    _avatarController.value = .001;
    final image = await getImage();
    if (image != null) {
      await auth.updateAvatar(
        image,
        config.avatarLink,
        onProgress: (bytes, totalBytes) {
          final progress = bytes / totalBytes;
          _avatarController.value = totalBytes > 0 ? (bytes / totalBytes) : null;
          if (progress >= .999) {
            _avatarController.value = null;
          }
        },
        onDone: CachedNetworkImage.evictFromCache,
      );
    }
    _avatarController.value = null;
  }

  Future<void> _removeExistingAvatar(BuildContext context) async {
    buzz();
    Auth.of(context).removeAvatar();
  }

  Future<void> _onAvatar(BuildContext context) async {
    final L(:capturePhoto, :chooseFromGallery, :removeCurrentPhoto, :cancel) = L.of(context);
    final ThemeData(:colorScheme, :platform) = Theme.of(context);

    final pop = Navigator.of(context).pop;
    final supportsTakingPhoto = context.supportsTakingPhoto();

    return showBottomMenu<void>(context, [
      if (supportsTakingPhoto)
        BottomMenuAction(
          title: capturePhoto,
          onPressed: () {
            pop();
            _uploadAvatar(
              context,
              () => captureAndCropPhoto(context, L.of(context).cropAvatar),
            );
          },
          icon: const Icon(Icons.camera_alt_rounded),
        ),
      BottomMenuAction(
        title: chooseFromGallery,
        onPressed: () {
          pop();
          _uploadAvatar(
            context,
            () => pickAndCropGalleryImage(context, L.of(context).cropAvatar),
          );
        },
        icon: const Icon(Icons.photo_library_rounded),
      ),
      BottomMenuAction(
        title: removeCurrentPhoto,
        onPressed: () {
          pop();
          _removeExistingAvatar(context);
        },
        icon: Icon(Icons.delete_rounded, color: colorScheme.error),
        isDestructive: true,
      ),
      BottomMenuAction(
        title: cancel,
        onPressed: pop,
        icon: const Icon(Icons.close_rounded),
      ),
    ]);
  }
}

/// The account's sign-ins (#323): Google, Apple and email-plus-password, each
/// connected or not, with the way to connect it and, while another remains,
/// the way to disconnect it. One uid throughout, so the server sees nothing.
///
/// Apple's row shows where Apple's sheet can: the same test the login page
/// makes. A password is "set", not connected: the reset email is how Firebase
/// adds one to an account that has none.
class _SignIns extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final VoidCallback onSetPassword;

  const new({required this.onError, required this.onSetPassword});

  @override
  State<_SignIns> createState() => _SignInsState();
}

class _SignInsState extends State<_SignIns> with HasHaptic<_SignIns> {
  late final Future<bool> _apple = Auth.isAppleSignInAvailable();

  /// The provider a connect or disconnect is in flight for: its row shows
  /// progress, the others keep their buttons.
  final _busy = ValueNotifier<AuthProvider?>(null);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:signIns) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Semantics(
            header: true,
            child: Text(signIns, style: textTheme.titleMedium),
          ),
        ),
        _row(context, .google),
        FutureBuilder<bool>(
          future: _apple,
          builder: (context, snapshot) => switch (snapshot.data) {
            true => _row(context, .apple),
            _ => const SizedBox.shrink(),
          },
        ),
        _row(context, .password),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _row(BuildContext context, AuthProvider provider) {
    return ValueListenableBuilder<AuthProvider?>(
      valueListenable: _busy,
      builder: (context, busy, _) {
        return _SignInRow(
          provider: provider,
          busy: busy == provider,
          onConnect: switch ((provider, busy)) {
            (_, AuthProvider()) => null,
            (.password, null) => widget.onSetPassword,
            (.google || .apple, null) => () => _connect(context, provider),
          },
          onDisconnect: switch (busy) {
            AuthProvider() => null,
            null => () => _disconnect(context, provider),
          },
        );
      },
    );
  }

  Future<void> _connect(BuildContext context, AuthProvider provider) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    _busy.value = provider;
    try {
      await Auth.of(context).connect(provider);
    } on AuthException catch (e) {
      messenger.snack(switch (e.reason) {
        .providerInUse => l.providerInUse,
        .networkRequestFailed => l.noConnectivity,
        .invalidEmail ||
        .wrongPassword ||
        .userDisabled ||
        .userNotFound ||
        .emailInUse ||
        .accountUnderOtherProvider ||
        .weakPassword ||
        .unknown => l.unknownError,
      });
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(l.unknownError);
    } finally {
      _busy.value = null;
    }
  }

  Future<void> _disconnect(BuildContext context, AuthProvider provider) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);
    final l = L.of(context);
    _busy.value = provider;
    try {
      await Auth.of(context).disconnect(provider);
    } on AuthException {
      messenger.snack(l.unknownError);
    } finally {
      _busy.value = null;
    }
  }
}

/// One sign-in: its mark and name, the address it knows the account by, and
/// the one action its state allows — Connect while it is not on the account,
/// Disconnect while it is and is not the last. Absent, not dead: the last
/// sign-in shows no button at all.
class _SignInRow extends StatelessWidget {
  final AuthProvider provider;
  final bool busy;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const new({
    required this.provider,
    required this.busy,
    this.onConnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      :providerGoogle,
      :providerApple,
      :providerPassword,
      :signInConnected,
      :connectSignIn,
      :disconnectSignIn,
      :setPassword,
    ) = L.of(
      context,
    );
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final auth = Auth.watch(context);
    final connected = auth.providers.contains(provider);
    final canDisconnect = connected && auth.providers.length > 1;

    final (icon, name) = switch (provider) {
      .google => (const Icon(CustomIcons.google), providerGoogle),
      .apple => (const Icon(CustomIcons.appstore), providerApple),
      .password => (const Icon(Icons.password_rounded), providerPassword),
    };

    return ListTile(
      key: AppKeys.signInRow(provider.id),
      leading: icon,
      title: Text(name),
      subtitle: switch (connected) {
        true => Text(
          auth.providerEmail(provider) ?? signInConnected,
          style: textTheme.bodySmall,
        ),
        false => null,
      },
      // One slot, as wide as the widest button this row can show: moving
      // between Connect, the spinner, Disconnect and nothing used to resize
      // the trailing and shift the row's text with every step. Measured in
      // the style the tile gives its trailing, which is the style the label
      // renders in.
      trailing: Builder(
        builder: (context) {
          final style = DefaultTextStyle.of(context).style;
          final scaler = MediaQuery.textScalerOf(context);
          double widthOf(String label) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            return painter.width;
          }

          final labels = [connectSignIn, disconnectSignIn, if (provider == .password) setPassword];
          final slot = labels.map(widthOf).reduce(math.max) + primaryButtonPadding.horizontal;
          return ConstrainedBox(
            constraints: BoxConstraints(minWidth: slot),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              widthFactor: 1,
              child: switch ((busy, connected, canDisconnect)) {
                (true, _, _) => const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                (false, false, _) => PrimaryButton.shrunk(
                  key: AppKeys.connectSignIn(provider.id),
                  onPressed: onConnect,
                  child: Text(switch (provider) {
                    .password => setPassword,
                    .google || .apple => connectSignIn,
                  }),
                ),
                (false, true, true) => PrimaryButton.shrunk(
                  key: AppKeys.disconnectSignIn(provider.id),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  onPressed: onDisconnect,
                  child: Text(disconnectSignIn),
                ),
                (false, true, false) => const SizedBox.shrink(),
              },
            ),
          );
        },
      ),
    );
  }
}
