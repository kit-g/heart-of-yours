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

  /// The page being turned to, which the next tap counts from: the one shown
  /// changes only halfway there.
  int? _turning;

  /// The month picked while it is still to come: gone to as the history that
  /// holds it is read.
  DateTime? _seeking;

  @override
  void didUpdateWidget(covariant _MonthPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = _monthsBetween(oldWidget.newest, widget.newest);
    // a month began with the page open: stay on an earlier one being looked
    // at, and go on being on the current one
    if (moved != 0 && _page.value > 0) _page.value = math.min(_page.value + moved, widget.count - 1);
    if (moved != 0) _jumpAfterFrame(_page.value);
    if (_seeking case final DateTime month) _seek(month);
  }

  void _jumpAfterFrame(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.pages.hasClients) widget.pages.jumpToPage(page);
    });
  }

  /// To [month]'s page once it is there; until then to the one still to come,
  /// which reads on.
  void _seek(DateTime month) {
    final page = _monthsBetween(month, widget.newest);
    final found = page < widget.count || !widget.more;
    _seeking = found ? null : month;
    _jumpAfterFrame(found ? page.clamp(0, widget.count - 1) : widget.count);
  }

  /// The person went somewhere themselves.
  void _letGo() {
    _seeking = null;
    _turning = null;
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  static int _monthsBetween(DateTime from, DateTime to) => (to.year - from.year) * 12 + to.month - from.month;

  DateTime _monthAt(int page) => DateTime(widget.newest.year, widget.newest.month - page);

  /// Turns [by] months, counted from the one a turn under way goes to.
  Future<void> _turnBy(int by) async {
    final page = ((_turning ?? _page.value) + by).clamp(0, _last);
    _letGo();
    if (lessMotion(context)) return widget.pages.jumpToPage(page);
    _turning = page;
    await widget.pages.animateToPage(page, duration: _turn, curve: Curves.easeInOut);
    if (_turning == page) _turning = null;
  }

  /// The last page: the oldest month, or what is still to come after it.
  int get _last => widget.count - 1 + (widget.more ? 1 : 0);

  /// Picks a date and goes to its month.
  Future<void> _goToDate(DateTime shown) async {
    final picked = await showAdaptiveDatePicker(
      context,
      // its first day, which every month has: on the 31st, a wheel turned to
      // a shorter month says nothing until it has rolled back by itself
      initialDate: shown,
      // further back than is read yet, while there is more to read
      firstDate: widget.more ? _farthest : _monthAt(widget.count - 1),
      lastDate: widget.today,
      title: L.of(context).calendarGoToDate,
    );
    if (picked == null || !mounted || !widget.pages.hasClients) return;
    _letGo();
    // straight there: not through every month between
    _seek(DateTime(picked.year, picked.month));
  }

  static final _farthest = DateTime(2000);

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
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (start) {
              if (start.dragDetails != null) _letGo();
              return false;
            },
            child: PageView.builder(
              controller: widget.pages,
              reverse: true,
              itemCount: _last + 1,
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
    final title = Semantics(
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
    );
    final buttons = [
      // nowhere to go with one month and nothing more to come
      if (_last > 0)
        IconButton(
          key: AppKeys.calendarGoToDate,
          tooltip: l.calendarGoToDate,
          icon: const Icon(Icons.edit_calendar_outlined),
          onPressed: () => _goToDate(shown),
        ),
      _step(
        key: AppKeys.calendarPreviousMonth,
        there: page < _last,
        tooltip: l.calendarPreviousMonth,
        icon: Icons.chevron_left_rounded,
        onPressed: () => _turnBy(1),
      ),
      _step(
        key: AppKeys.calendarNextMonth,
        there: page > 0,
        tooltip: l.calendarNextMonth,
        icon: Icons.chevron_right_rounded,
        onPressed: () => _turnBy(-1),
      ),
    ];
    return Padding(
      padding: const .fromLTRB(16, 8, 4, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // by the widest month's name, so a turn never moves the header
          final widest = List.generate(
            12,
            (month) => lineWidth(
              context,
              DateFormat.yMMM(l.localeName).format(DateTime(shown.year, month + 1)),
              style: textTheme.titleLarge,
            ),
          ).fold(0.0, math.max);
          return switch (widest + 3 * kMinInteractiveDimension <= constraints.maxWidth) {
            true => Row(
              children: [
                Expanded(child: title),
                ...buttons,
              ],
            ),
            false => Column(
              crossAxisAlignment: .start,
              children: [
                title,
                Row(mainAxisAlignment: .end, children: buttons),
              ],
            ),
          };
        },
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
