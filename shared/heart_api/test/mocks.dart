import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';

/// The mocks the route tests share; `support/http.dart` hands them out.
@GenerateNiceMocks(
  [
    MockSpec<http.Client>(),
    MockSpec<Exercise>(),
  ],
)
void main() {
  //
}
