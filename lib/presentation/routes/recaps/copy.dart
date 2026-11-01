part of 'recaps.dart';

/// "September 2026", capitalised: in Russian, Spanish and French a month is
/// lower case mid-sentence, and a title is not mid-sentence.
String monthTitle(L l, DateTime month) {
  final title = DateFormat.yMMMM(l.localeName).format(month);
  return switch (title) {
    '' => title,
    _ => '${title[0].toUpperCase()}${title.substring(1)}',
  };
}

/// "9 h 40 min", or "45 min" under an hour.
String trainedTime(L l, Duration trained) {
  return switch (trained.inHours) {
    0 => l.recapMinutes(trained.inMinutes),
    final hours => l.recapHoursMinutes(hours, trained.inMinutes.remainder(60)),
  };
}

/// [volume], already in [unit], whole and grouped: "12,450 kg".
String recapVolume(L l, double volume, MeasurementUnit unit) {
  final suffix = switch (unit) {
    .imperial => l.lbs,
    .metric => l.kg,
  };
  return '${NumberFormat.decimalPattern(l.localeName).format(volume.round())} $suffix';
}

/// The records a recap lists: the ones that beat something. An exercise's
/// first time sets every record at once, and a list of them congratulates
/// nobody — the same line the badges beside a workout's sets draw.
Iterable<RecapRecord> beatenRecords(Recap recap) {
  return recap.records.where((record) => !record.isFirst && _kindOf(record) != null);
}

RecordKind? _kindOf(RecapRecord record) {
  return RecordKind.values.where((kind) => kind.key == record.record).firstOrNull;
}

/// The one line a month says about itself: "12 workouts · 9 h 40 min · 3
/// records", the records only when there are some.
String recapSummary(L l, Recap recap) {
  final records = beatenRecords(recap).length;
  return [
    l.recapWorkoutsCount(recap.workouts),
    trainedTime(l, recap.trained),
    if (records > 0) l.recapRecordsCount(records),
  ].join(' · ');
}
