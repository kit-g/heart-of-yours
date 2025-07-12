import 'package:heart_api/heart_api.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Api Singleton Tests',
    () {
      test(
        'Api.instance should always return the same instance',
        () {
          final instance1 = Api.instance;
          final instance2 = Api.instance;
          final instance3 = Api.instance;

          expect(identical(instance1, instance2), true);
          expect(identical(instance2, instance3), true);
          expect(identical(instance1, instance3), true);
        },
      );

      test(
        'Factory constructor should set gateway on the instance',
        () {
          final api = Api(gateway: 'https://test-api.example.com');

          expect(api.gateway, 'https://test-api.example.com');
          expect(Api.instance.gateway, 'https://test-api.example.com');

          expect(identical(api, Api.instance), true);
        },
      );

      test('Factory constructor should return the singleton instance', () {
        final instance = Api.instance;
        final api = Api(gateway: 'https://new-gateway.example.com');
        expect(identical(api, instance), true);
      });

      test(
        'Multiple calls to factory constructor should update the same instance',
        () {
          // First call
          final api1 = Api(gateway: 'https://first.example.com');
          expect(api1.gateway, 'https://first.example.com');

          // Second call
          final api2 = Api(gateway: 'https://second.example.com');
          expect(api2.gateway, 'https://second.example.com');

          // Verify they're the same instance and the gateway was updated
          expect(identical(api1, api2), true);
          expect(api1.gateway, 'https://second.example.com');
          expect(Api.instance.gateway, 'https://second.example.com');
        },
      );
    },
  );
}
