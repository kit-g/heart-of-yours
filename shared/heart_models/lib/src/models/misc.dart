import 'dart:async';

abstract interface class SignOutStateSentry {
  FutureOr<void> onSignOut();
}

abstract interface class Searchable {
  bool contains(String query);
}

abstract interface class Model {
  Map<String, dynamic> toMap();
}

abstract interface class Storable {
  Map<String, dynamic> toRow();
}

enum MeasurementUnit {
  imperial('Imperial'),
  metric('Metric');

  final String name;

  const MeasurementUnit(this.name);

  factory MeasurementUnit.fromString(String v) {
    return switch (v) {
      'Imperial' => MeasurementUnit.imperial,
      'Metric' => MeasurementUnit.metric,
      _ => throw ArgumentError(v),
    };
  }
}

extension Units on num {
  double get asPounds => this * 2.20462262185;

  double get asKilograms => this * 0.45359237;

  double get asMiles => this * 0.62137119224;

  double get asKilometers => this * 1.609344;
}
