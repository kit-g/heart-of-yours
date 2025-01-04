import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('HistoryPage'),
      ),
      floatingActionButton: WorkoutTimerFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
