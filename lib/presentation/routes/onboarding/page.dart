part of 'onboarding.dart';

/// The first-launch carousel: three screens, a way out on every one of them.
///
/// Shown once, before the anonymous session lands anyone in the app, and never
/// again — the router decides that on `Preferences.onboardingSeen`, this page
/// only reports which way the reader left. Both ways mark the carousel seen;
/// there is no "remind me later", because a reminder is the one thing a
/// first launch must not turn into.
class OnboardingPage extends StatefulWidget {
  /// The way into the app: Skip on any screen, Continue on the last.
  final VoidCallback onContinue;

  /// The way to the login page, offered on the last screen only — the one
  /// that says what an account adds.
  final VoidCallback onLogIn;

  const new({
    super.key,
    required this.onContinue,
    required this.onLogIn,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  final _page = ValueNotifier(0);

  static const _screens = 3;

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :skip,
      :onboardingWelcomeTitle,
      :onboardingWelcomeBody,
      :onboardingLocalTitle,
      :onboardingLocalBody,
      :onboardingLocalTrade,
      :onboardingAccountTitle,
      :onboardingAccountBody,
    ) = L.of(
      context,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: .centerRight,
              child: Padding(
                padding: const .symmetric(horizontal: 8, vertical: 4),
                child: TextButton(
                  key: AppKeys.onboardingSkip,
                  // the theme's text button is dialog-footer sized; a lone
                  // control in a corner gets a full tap target
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: widget.onContinue,
                  child: Text(skip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => _page.value = index,
                children: [
                  _Screen(
                    asset: Assets.emptyWorkout,
                    title: onboardingWelcomeTitle,
                    body: [onboardingWelcomeBody],
                  ),
                  _Screen(
                    icon: Icons.smartphone_outlined,
                    title: onboardingLocalTitle,
                    body: [onboardingLocalBody, onboardingLocalTrade],
                  ),
                  _Screen(
                    icon: Icons.cloud_sync_outlined,
                    title: onboardingAccountTitle,
                    body: [onboardingAccountBody],
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _page,
              builder: (context, page, _) {
                return _Footer(
                  page: page,
                  screens: _screens,
                  onNext: _next,
                  onContinue: widget.onContinue,
                  onLogIn: widget.onLogIn,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One screen of the carousel: an illustration, a title, a paragraph or two.
///
/// Measures its own viewport — the page it is scrolled inside, not the window
/// — and caps everything: the illustration to a fraction of the short edge, the
/// copy to [readableWidth]. Left to fill, the illustration asked for 250pt on
/// an iPad and the paragraph ran the full 1194.
class _Screen extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final String title;
  final List<String> body;

  const new({
    this.asset,
    this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final BoxConstraints(:maxWidth, :maxHeight) = constraints;
        final size = (math.min(maxWidth, maxHeight) * .3).clamp(96.0, 160.0);

        // Scrolls only when it has to — a large text scale on a short phone —
        // and centres otherwise; see the login page for the same construction.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxHeight),
            child: Center(
              child: Padding(
                padding: const .symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: readableWidth),
                  child: Column(
                    mainAxisSize: .min,
                    spacing: 16,
                    children: [
                      // decorative — the title says what the screen is about
                      ExcludeSemantics(
                        child: _Illustration(
                          key: AppKeys.onboardingIllustration,
                          size: size,
                          asset: asset,
                          icon: icon,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: textTheme.headlineMedium,
                        textAlign: .center,
                      ),
                      for (final paragraph in body)
                        Text(
                          paragraph,
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          textAlign: .center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The ring the upgrade-required page draws around its glyph, so the two
/// full-page surfaces read as one family.
class _Illustration extends StatelessWidget {
  final double size;
  final String? asset;
  final IconData? icon;

  const new({
    super.key,
    required this.size,
    this.asset,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final glyph = size * .55;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: .circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: switch ((asset, icon)) {
          (String asset, _) => Vector(asset, width: glyph, height: glyph, color: color),
          (null, IconData icon) => Icon(icon, size: glyph, color: color),
          (null, null) => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// One page dot; the active one stretches into a pill.
class _Dot extends StatelessWidget {
  final bool active;

  const new({required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: switch (active) {
        true => 24,
        false => 8,
      },
      height: 8,
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(4)),
        color: switch (active) {
          true => colorScheme.primary,
          false => colorScheme.outlineVariant,
        },
      ),
    );
  }
}

/// The page dots and the actions under the carousel.
///
/// Next on the way through; on the last screen the two ways out, the neutral
/// fill for the login page and the accent for the app — the app is where a
/// first launch is headed, an account is the option.
class _Footer extends StatelessWidget {
  final int page;
  final int screens;
  final VoidCallback onNext;
  final VoidCallback onContinue;
  final VoidCallback onLogIn;

  const new({
    required this.page,
    required this.screens,
    required this.onNext,
    required this.onContinue,
    required this.onLogIn,
  });

  /// Grows the 32pt button the dialogs use to a full tap target: this is a
  /// page's one action, not a footer's.
  static const _margin = EdgeInsets.symmetric(horizontal: 8, vertical: 14);

  @override
  Widget build(BuildContext context) {
    final L(:onboardingNext, :onboardingContinue, :logIn, :onboardingScreenOf) = L.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = page == screens - 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Padding(
          padding: const .fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: .min,
            spacing: 16,
            children: [
              Semantics(
                label: onboardingScreenOf(page + 1, screens),
                liveRegion: true,
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: .center,
                  spacing: 6,
                  children: List.generate(screens, (i) => _Dot(active: i == page)),
                ),
              ),
              switch (isLast) {
                false => PrimaryButton.wide(
                  key: AppKeys.onboardingNext,
                  margin: _margin,
                  onPressed: onNext,
                  child: Center(child: Text(onboardingNext)),
                ),
                true => Column(
                  spacing: 8,
                  children: [
                    PrimaryButton.wide(
                      key: AppKeys.onboardingSignIn,
                      margin: _margin,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      onPressed: onLogIn,
                      child: Center(child: Text(logIn)),
                    ),
                    PrimaryButton.wide(
                      key: AppKeys.onboardingContinue,
                      margin: _margin,
                      onPressed: onContinue,
                      child: Center(child: Text(onboardingContinue)),
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
