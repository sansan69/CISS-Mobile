import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/auth/pin_policy.dart';

void main() {
  group('validateNewGuardPin', () {
    test('accepts a non-trivial six-digit PIN', () {
      expect(validateNewGuardPin('246810'), isNull);
      expect(validateNewGuardPin('135790'), isNull);
      expect(isValidNewGuardPin('864209'), isTrue);
    });

    test('requires exactly six digits', () {
      expect(validateNewGuardPin('1234'), 'Enter a 6-digit PIN.');
      expect(validateNewGuardPin('1234567'), 'Enter a 6-digit PIN.');
      expect(validateNewGuardPin('12a456'), 'Enter a 6-digit PIN.');
      expect(validateNewGuardPin(''), 'Enter a 6-digit PIN.');
    });

    test('rejects repeated, sequential and patterned PINs', () {
      expect(validateNewGuardPin('111111'), isNotNull);
      expect(validateNewGuardPin('000000'), isNotNull);
      expect(validateNewGuardPin('123456'), isNotNull);
      expect(validateNewGuardPin('654321'), isNotNull);
      expect(validateNewGuardPin('121212'), isNotNull);
      expect(validateNewGuardPin('123123'), isNotNull);
      expect(validateNewGuardPin('112233'), isNotNull);
    });

    test('rejects well-known common PINs', () {
      expect(validateNewGuardPin('520131'), isNotNull);
      expect(validateNewGuardPin('159357'), isNotNull);
    });

    test('does not reject a PIN merely for containing a repeated pair', () {
      expect(validateNewGuardPin('246886'), isNull);
    });
  });
}
