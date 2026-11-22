part of 'history.dart';

/// The calendar a month at a time (#739): swiped sideways, the past to the
/// left, under a header that names the month shown, steps to the one beside
/// it, and picks a date to go to.
///
/// The month shown is announced as it changes, whichever way it did.
class _MonthPages extends StatefulWidget {
  final PageController pages;

  /// The current month: page 0, and the last there is to swipe to.
  final DateTime newest;

  /// How many months there are, from [newest] back to the oldest known.
  final int count;
  final DateTime today;

  /// Whether older history is still to come: then a page after the oldest
  /// month is [tail], until what it brings is there.
  final bool more;

  /// Asks for what is older, as the oldest month comes into view.
  final VoidCallback onOldest;
  final Widget weekdays;
  final Widget Function() tail;
  final Widget Function(DateTime month) month;

  const new({
    required this.pages,
    required this.newest,
    required this.count,
    required this.today,
    required this.more,
    required this.onOldest,
    required this.weekdays,
    required this.tail,
    required this.month,
  });

  @override
  State<_MonthPages> createState() => _MonthPagesState();
}

class _MonthPagesState extends State<_MonthPages> {
  /// The page shown, or the one most of it is.
  final _page = ValueNotifier(0);

  static const _turn = Duration(milliseconds: 250);

  @override
  void didUpdateWidget(covariant _MonthPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = _monthsBetween(oldWidget.newest, widget.newest);
    if (moved == 0) return;
    // a month began with the page open: stay on the one being looked at
    final page = _page.value + moved;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.pages.hasClients) widget.pages.jumpToPage(page.clamp(0, widget.count - 1));
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  static int _monthsBetween(DateTime from, DateTime to) => (to.year - from.year) * 12 + to.month - from.month;

  DateTime _monthAt(int page) => DateTime(widget.newest.year, widget.newest.month - page);

  Future<void> _turnTo(int page) async {
    if (lessMotion(context)) return widget.pages.jumpToPage(page);
    await widget.pages.animateToPage(page, duration: _turn, curve: Curves.easeInOut);
  }

  /// Picks a date and goes to its month.
  Future<void> _goToDate(DateTime shown) async {
    final picked = await showAdaptiveDatePicker(
      context,
      // the month's last day there is, so the picker opens on the month shown
      initialDate: switch (DateTime(shown.year, shown.month + 1, 0)) {
        final end when end.isAfter(widget.today) => widget.today,
        final end => end,
      },
      firstDate: _monthAt(widget.count - 1),
      lastDate: widget.today,
      title: L.of(context).calendarGoToDate,
    );
    if (picked == null || !mounted || !widget.pages.hasClients) return;
    // straight there: not through every month between
    widget.pages.jumpToPage(_monthsBetween(picked, widget.newest).clamp(0, widget.count - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: _page,
          builder: (context, page, _) => _header(context, page),
        ),
        widget.weekdays,
        Expanded(
          child: PageView.builder(
            controller: widget.pages,
            reverse: true,
            itemCount: widget.count + (widget.more ? 1 : 0),
            onPageChanged: (page) => _page.value = page,
            itemBuilder: (context, page) {
              if (page >= widget.count - 1) widget.onOldest();
              if (page == widget.count) return Center(child: widget.tail());
              // a short screen, or a six-week month over the workout's button
              return SingleChildScrollView(
                padding: const .only(bottom: 72),
                child: widget.month(_monthAt(page)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, int page) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    // the page of what is still to come is no month: it is named after the
    // oldest one known
    final shown = _monthAt(page.clamp(0, widget.count - 1));
    final last = widget.count - 1 + (widget.more ? 1 : 0);
    return Padding(
      padding: const .fromLTRB(16, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              liveRegion: true,
              label: DateFormat.yMMMM(l.localeName).format(shown),
              excludeSemantics: true,
              child: Text(
                DateFormat.yMMM(l.localeName).format(shown),
                key: AppKeys.calendarMonthTitle,
                style: textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            key: AppKeys.calendarGoToDate,
            tooltip: l.calendarGoToDate,
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => _goToDate(shown),
          ),
          _step(
            key: AppKeys.calendarPreviousMonth,
            there: page < last,
            tooltip: l.calendarPreviousMonth,
            icon: Icons.chevron_left_rounded,
            onPressed: () => _turnTo(page + 1),
          ),
          _step(
            key: AppKeys.calendarNextMonth,
            there: page > 0,
            tooltip: l.calendarNextMonth,
            icon: Icons.chevron_right_rounded,
            onPressed: () => _turnTo(page - 1),
          ),
        ],
      ),
    );
  }

  /// A way to the month beside this one: gone where there is none, its place
  /// kept, so the other doesn't move under the finger.
  Widget _step({
    required Key key,
    required bool there,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Visibility(
      visible: there,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: IconButton(key: key, tooltip: tooltip, icon: Icon(icon), onPressed: onPressed),
    );
  }
}
