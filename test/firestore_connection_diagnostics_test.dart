import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/firestore_connection_diagnostics.dart';

void main() {
  group('Firestore REST diagnostic', () {
    test(
      'maps decisive HTTP statuses without conflating transport failures',
      () {
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(200),
          FirestoreRestOutcome.success,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(404),
          FirestoreRestOutcome.missingDocument,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(401),
          FirestoreRestOutcome.unauthenticated,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(403),
          FirestoreRestOutcome.permissionDenied,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(400),
          FirestoreRestOutcome.invalidTarget,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(429),
          FirestoreRestOutcome.rateLimited,
        );
        expect(
          FirestoreConnectionDiagnostics.outcomeForHttpStatus(503),
          FirestoreRestOutcome.serviceFailure,
        );
      },
    );

    test('does not misclassify a database-level 404 as a missing document', () {
      expect(
        FirestoreConnectionDiagnostics.outcomeForProbeStatuses(
          documentStatus: 404,
          commitStatus: 404,
        ),
        FirestoreRestOutcome.invalidTarget,
      );
      expect(
        FirestoreConnectionDiagnostics.outcomeForProbeStatuses(
          documentStatus: 404,
          commitStatus: 200,
        ),
        FirestoreRestOutcome.missingDocument,
      );
    });

    test('redacts uid, token, email, and line breaks from native messages', () {
      const uid = 'private-user-id-123';
      final safe = FirestoreConnectionDiagnostics.redactSensitive(
        'user=$uid email=user@example.com\n'
        'Authorization: Bearer abc.def.ghi',
        uid: uid,
      );

      expect(safe, contains('<uid>'));
      expect(safe, contains('<email>'));
      expect(safe, contains('Bearer <token>'));
      expect(safe, isNot(contains(uid)));
      expect(safe, isNot(contains('user@example.com')));
      expect(safe, isNot(contains('abc.def.ghi')));
      expect(safe, isNot(contains('\n')));
    });
  });
}
