import 'package:heart_api/heart_api.dart';
import 'package:test/test.dart';

void main() {
  group('Api Authentication Tests', () {
    late Api api;

    setUp(
      () {
        api = Api(gateway: 'https://test-api.example.com');
        api.defaultHeaders = null; // Reset headers before each test
      },
    );

    group(
      'authenticate method',
      () {
        test(
          'should set defaultHeaders with provided headers',
          () {
            // Define test headers
            final testHeaders = {
              'Authorization': 'Bearer test-token',
              'Content-Type': 'application/json',
            };

            // Call authenticate
            api.authenticate(testHeaders);

            // Verify headers were set
            expect(api.defaultHeaders, testHeaders);
          },
        );

        test(
          'should overwrite existing headers',
          () {
            // Set initial headers
            api.defaultHeaders = {
              'Authorization': 'Bearer old-token',
              'Content-Type': 'application/json',
            };

            // New headers to set
            final newHeaders = {
              'Authorization': 'Bearer new-token',
              'Accept': 'application/json',
            };

            // Call authenticate
            api.authenticate(newHeaders);

            // Verify headers were completely replaced
            expect(api.defaultHeaders, newHeaders);
            expect(api.defaultHeaders?['Authorization'], 'Bearer new-token');
            expect(api.defaultHeaders?['Content-Type'],
                null); // Old header should be gone
          },
        );

        test(
          'should handle empty headers map',
          () {
            // Call authenticate with empty map
            api.authenticate({});

            // Verify empty map was set
            expect(api.defaultHeaders, {});
          },
        );
      },
    );

    group(
      'isAuthenticated property',
      () {
        test('should return true for valid Bearer token', () {
          // Set valid authorization header
          api.defaultHeaders = {'Authorization': 'Bearer valid-token'};

          // Verify isAuthenticated is true
          expect(api.isAuthenticated, true);
        });

        test('should return false for null defaultHeaders', () {
          // Ensure headers are null
          api.defaultHeaders = null;

          // Verify isAuthenticated is false
          expect(api.isAuthenticated, false);
        });

        test('should return false for empty defaultHeaders', () {
          // Set empty headers
          api.defaultHeaders = {};

          // Verify isAuthenticated is false
          expect(api.isAuthenticated, false);
        });

        test('should return false when Authorization header is missing', () {
          // Set headers without Authorization
          api.defaultHeaders = {'Content-Type': 'application/json'};

          // Verify isAuthenticated is false
          expect(api.isAuthenticated, false);
        });

        test('should return false for non-Bearer token', () {
          // Set different authorization type
          api.defaultHeaders = {
            'Authorization': 'Basic dXNlcm5hbWU6cGFzc3dvcmQ='
          };

          // Verify isAuthenticated is false
          expect(api.isAuthenticated, false);
        });

        test('should return false for malformed Bearer token', () {
          // Various malformed tokens
          final malformedTokens = [
            'Bearer', // Missing token part
            'Bearer ', // Empty token
            'bearer token', // Lowercase bearer
            'BearerToken', // No space
          ];

          // Test each malformed token
          for (final token in malformedTokens) {
            api.defaultHeaders = {'Authorization': token};
            expect(api.isAuthenticated, false,
                reason: 'Failed for token: $token');
          }
        });

        test('should return false for empty token value', () {
          // Set empty token
          api.defaultHeaders = {'Authorization': 'Bearer '};

          // Verify isAuthenticated is false
          expect(api.isAuthenticated, false);
        });

        test('should return true for token with special characters', () {
          // Token with special chars should be valid
          api.defaultHeaders = {'Authorization': 'Bearer abc.xyz-123_456!@#'};

          // Verify isAuthenticated is true
          expect(api.isAuthenticated, true);
        });

        test('should properly handle multipart tokens', () {
          // Token with multiple parts
          api.defaultHeaders = {'Authorization': 'Bearer part1.part2.part3'};

          // Verify isAuthenticated is true
          expect(api.isAuthenticated, true);
        });

        test('should be case sensitive for "Bearer" prefix', () {
          // Test with different casings
          api.defaultHeaders = {'Authorization': 'bearer valid-token'};
          expect(api.isAuthenticated, false);

          api.defaultHeaders = {'Authorization': 'BEARER valid-token'};
          expect(api.isAuthenticated, false);

          api.defaultHeaders = {'Authorization': 'Bearer valid-token'};
          expect(api.isAuthenticated, true);
        });
      },
    );
  });
}
