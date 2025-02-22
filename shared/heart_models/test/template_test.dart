import 'package:test/test.dart';
import 'package:heart_models/heart_models.dart';
import 'dart:convert';

void main() {
  group(
    'Template Tests',
    () {
      test(
        'empty constructor creates a Template with no exercises',
        () {
          final template = Template.empty(id: 'template_1', order: 1);

          expect(template.id, 'template_1');
          expect(template.order, 1);
          expect(template.name, isNull);
          expect(template.isEmpty, true);
        },
      );

      test(
        'fromRows correctly constructs a Template',
        () {
          final rows = [
            {
              "templateName": 'Strength Training',
              "orderInParent": 2,
              "createdAt": '2025-02-17 19:14:54+00:00',
              "id": 88,
              "templateId": 9,
              "description": jsonEncode([
                {"id": "2025-02-17T19:15:38_013029Z", "completed": false, "reps": 10, "weight": 10.0},
                {"id": "2025-02-17T19:15:40_932484Z", "completed": false, "reps": 20, "weight": 10.0}
              ]),
              "name": 'Incline Chest Fly (Dumbbell)',
              "category": 'Dumbbell',
              "target": 'Chest',
              "lastDone": null,
              "lastResults": null,
              "restTimer": null
            }
          ];

          final template = Template.fromRows(rows);

          expect(template.id, '9');
          expect(template.name, 'Strength Training');
          expect(template.order, 2);
          expect(template.isNotEmpty, true);
          expect(template.length, 1);
        },
      );

      test(
        'toWorkout converts Template to a Workout',
        () {
          final template = Template.empty(id: 'template_3', order: 3);
          final workout = template.toWorkout();

          expect(workout, isEmpty);
        },
      );

      test(
        'Comparison works correctly',
        () {
          final template1 = Template.empty(id: 'template_4', order: 1);
          final template2 = Template.empty(id: 'template_5', order: 2);
          final template3 = Template.empty(id: 'template_6', order: 1);

          expect(template1.compareTo(template2) < 0, true);
          expect(template2.compareTo(template1) > 0, true);
          expect(template1.compareTo(template3) == 0, true);
        },
      );
    },
  );
}
