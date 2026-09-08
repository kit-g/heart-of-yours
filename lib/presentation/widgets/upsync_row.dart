import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// The one place the replay of an anonymous session's store into its new
/// account shows: a line with a bar while it runs, the same line with a
/// retry when the server could not be reached, one line of numbers when it
/// is done. Absent — not empty — the rest of the time.
///
/// A sliver, for the top of the profile's scroll view: it sits above the
/// chart rather than in the app bar, so the bar has room to be read and
/// nothing else on the page moves when it goes.
class const UpsyncRow({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final upsync = Upsync.watch(context);
    final l = L.of(context);

    final Widget? row = switch (upsync.status) {
      .idle => null,
      .running => _Running(
        label: l.upsyncRunning(upsync.done, upsync.total),
        done: upsync.done,
        total: upsync.total,
      ),
      .failed => _Line(
        // a phone with no signal is the user's to fix; a server that answered
        // and refused is not, and sending them after a working connection is
        // sending them after a fault they do not have
        text: switch (upsync.reachedServer) {
          true => l.upsyncRefused(upsync.done, upsync.total),
          false => l.upsyncFailed(upsync.done, upsync.total),
        },
        action: PrimaryButton.shrunk(
          key: AppKeys.upsyncRetry,
          onPressed: upsync.retry,
          child: Text(l.retry),
        ),
      ),
      .done => _Line(
        text: [
          l.upsyncDone(upsync.report.uploaded, upsync.report.existing),
          if (upsync.report.skipped > 0) l.upsyncSkipped(upsync.report.skipped),
        ].join(' '),
        action: IconButton(
          key: AppKeys.upsyncDismiss,
          tooltip: l.close,
          onPressed: upsync.dismiss,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    };

    if (row == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (_, constraints) {
          // a line of prose and a bar: a readable column, start-aligned with
          // the chart below it, not the whole width of an iPad
          final width = math.min(constraints.maxWidth - 32, readableWidth);
          return Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: .centerLeft,
              child: SizedBox(
                key: AppKeys.upsyncRow,
                width: width,
                child: row,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The pull counterpart: the history this device does not hold yet, being
/// paged down in the background (heart-of-yours#113).
///
/// A line with a bar while it runs, the same line with a retry when the server
/// could not be reached. **No finished line** — the user never asked for this
/// sync, and telling them a job they did not start has ended is a notice about
/// the app's bookkeeping rather than about them. It simply goes.
class const BackfillRow({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final backfill = Backfill.watch(context);
    final l = L.of(context);

    final Widget? row = switch (backfill.status) {
      .idle => null,
      .running => _Running(
        // the account's own total is one request the run may not have got;
        // without it the line says what it knows and the bar spins
        label: switch (backfill.total) {
          0 => l.backfillRunning,
          final total => l.backfillRunningOf(backfill.done, total),
        },
        done: backfill.done,
        total: backfill.total,
      ),
      .failed => _Line(
        text: l.backfillFailed,
        action: PrimaryButton.shrunk(
          key: AppKeys.backfillRetry,
          onPressed: backfill.retry,
          child: Text(l.retry),
        ),
      ),
    };

    if (row == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = math.min(constraints.maxWidth - 32, readableWidth);
          return Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: .centerLeft,
              child: SizedBox(
                key: AppKeys.backfillRow,
                width: width,
                child: row,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Running extends StatelessWidget {
  final String label;
  final int done;
  final int total;

  const new({required this.label, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Column(
      crossAxisAlignment: .start,
      spacing: 6,
      children: [
        Text(label, style: textTheme.bodyMedium),
        ClipRRect(
          borderRadius: .circular(4),
          child: LinearProgressIndicator(
            // indeterminate until the first pass has counted the rows
            value: switch (total) {
              0 => null,
              _ => done / total,
            },
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            // the label above already reads the numbers out
            semanticsLabel: label,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String text;
  final Widget action;

  const new({required this.text, required this.action});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        Expanded(child: Text(text, style: textTheme.bodyMedium)),
        action,
      ],
    );
  }
}
