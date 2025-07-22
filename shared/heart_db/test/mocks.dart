import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';

@GenerateNiceMocks(
  [
    MockSpec<Database>(),
    MockSpec<Transaction>(),
    MockSpec<Batch>(),
    MockSpec<Exercise>(),
  ],
)
void main() {
  //
}
