import 'dart:math' as math;
import 'dart:collection';
import 'package:flutter/material.dart';

class Dot {
  final double x;
  final double y;
  final String? tooltip;

  const Dot(
    this.x,
    this.y, {
    this.tooltip,
  });

  @override
  String toString() {
    return '($x:$y)';
  }
}

class LineSeries with Iterable<Dot>, ChangeNotifier {
  final List<Dot> _dots;
  final double lowerBoundaryY;
  final double upperBoundaryY;

  final SplayTreeSet<int> _tooltipIndices;

  LineSeries({required Iterable<Dot> dots})
      : _dots = dots.toList(),
        lowerBoundaryY = dots.lowerBoundaryY,
        upperBoundaryY = dots.upperBoundaryY,
        _tooltipIndices = SplayTreeSet.from(
          dots.indexed.map((record) => record.$2.tooltip == null ? null : record.$1).nonNulls,
        );

  @override
  Iterator<Dot> get iterator => _dots.iterator;

  List<int> get tooltipIndices => _tooltipIndices.toList();

  void addTooltipAt(int index) {
    _tooltipIndices.add(index);
    notifyListeners();
  }

  void removeTooltipAt(int index) {
    _tooltipIndices.remove(index);
    notifyListeners();
  }
}

extension on Iterable<Dot> {
  double get lowerBoundaryY {
    try {
      return map((each) => each.y).reduce((one, two) => math.min(one, two));
    } on StateError {
      return 0;
    }
  }

  double get upperBoundaryY {
    try {
      return map((each) => each.y).reduce((one, two) => math.max(one, two));
    } on StateError {
      return 0;
    }
  }
}
