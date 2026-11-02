import 'package:ciss_mobile/core/update/update_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateUrlPolicy accepts production download URLs', () {
    const accepted = <String>[
      'https://cisskerala.site/downloads/ciss-workforce-1.0.22.apk',
      'https://cisskerala.site/downloads/nested/ciss-workforce-1.0.22.apk',
      'https://cdn.cisskerala.site/downloads/ciss-workforce-1.0.22.apk',
      'https://downloads.cisskerala.site/downloads/app.apk',
      'https://cisskerala.site/downloads/app.apk?v=22',
      '  https://cisskerala.site/downloads/app.apk  ',
      // An explicit default port and dot segments are normalised away by
      // Uri.parse, leaving the same safe host + /downloads/ path.
      'https://cisskerala.site:443/downloads/app.apk',
      'https://cisskerala.site/downloads/./app.apk',
    ];

    for (final url in accepted) {
      test(url, () {
        final result = UpdateUrlPolicy.check(url);
        expect(
          result.isAllowed,
          isTrue,
          reason: 'rejected by ${result.rejection?.name}',
        );
        expect(result.rejection, isNull);
        expect(result.uri, isNotNull);
      });
    }

    test('allowedUri returns the parsed URI and allows() mirrors check()', () {
      const url = 'https://cisskerala.site/downloads/app.apk';
      expect(UpdateUrlPolicy.allowedUri(url)?.host, 'cisskerala.site');
      expect(UpdateUrlPolicy.allows(url), isTrue);
      expect(
        UpdateUrlPolicy.allowedUri('http://cisskerala.site/x.apk'),
        isNull,
      );
    });
  });

  group('UpdateUrlPolicy rejects untrusted update URLs', () {
    const cases = <String, UpdateUrlRejection>{
      '': UpdateUrlRejection.empty,
      '   ': UpdateUrlRejection.empty,
      'http://cisskerala.site/downloads/app.apk':
          UpdateUrlRejection.schemeNotHttps,
      'http://cisskerala.site:443/downloads/app.apk':
          UpdateUrlRejection.schemeNotHttps,
      'ftp://cisskerala.site/downloads/app.apk':
          UpdateUrlRejection.schemeNotHttps,
      'intent://scan/#Intent;scheme=https;end':
          UpdateUrlRejection.schemeNotHttps,
      'file:///data/local/tmp/app.apk': UpdateUrlRejection.schemeNotHttps,
      'https://user:pass@cisskerala.site/downloads/app.apk':
          UpdateUrlRejection.userInfo,
      'https://cisskerala.site:8443/downloads/app.apk': UpdateUrlRejection.port,
      'https://evil.example/downloads/app.apk':
          UpdateUrlRejection.hostNotAllowed,
      'https://cisskerala.site.evil.example/downloads/app.apk':
          UpdateUrlRejection.hostNotAllowed,
      'https://evilcisskerala.site/downloads/app.apk':
          UpdateUrlRejection.hostNotAllowed,
      'https://sub.evilcisskerala.site/downloads/app.apk':
          UpdateUrlRejection.hostNotAllowed,
      'https://cisskerala.site/uploads/app.apk':
          UpdateUrlRejection.pathNotAllowed,
      'https://cisskerala.site/downloads': UpdateUrlRejection.pathNotAllowed,
      'https://cisskerala.site/': UpdateUrlRejection.pathNotAllowed,
      'https://cisskerala.site/downloads/../admin/app.apk':
          UpdateUrlRejection.pathNotAllowed,
      'https://cisskerala.site/downloads/': UpdateUrlRejection.pathNotAllowed,
      'https://[::1': UpdateUrlRejection.malformed,
    };

    cases.forEach((url, expected) {
      test('$url -> ${expected.name}', () {
        final result = UpdateUrlPolicy.check(url);
        expect(result.isAllowed, isFalse);
        expect(result.rejection, expected);
        expect(result.uri, isNull);
      });
    });

    test('null is rejected as empty', () {
      expect(UpdateUrlPolicy.check(null).rejection, UpdateUrlRejection.empty);
    });
  });

  group('UpdateUrlPolicy.isAllowedHost', () {
    test('accepts the apex and real subdomains only', () {
      expect(UpdateUrlPolicy.isAllowedHost('cisskerala.site'), isTrue);
      expect(UpdateUrlPolicy.isAllowedHost('CISSKERALA.SITE'), isTrue);
      expect(UpdateUrlPolicy.isAllowedHost('cdn.cisskerala.site'), isTrue);
      expect(UpdateUrlPolicy.isAllowedHost('a.b.cisskerala.site'), isTrue);
      expect(
        UpdateUrlPolicy.isAllowedHost('cisskerala.site.evil.test'),
        isFalse,
      );
      expect(UpdateUrlPolicy.isAllowedHost('evilcisskerala.site'), isFalse);
      expect(UpdateUrlPolicy.isAllowedHost('notcisskerala.site'), isFalse);
      expect(UpdateUrlPolicy.isAllowedHost(''), isFalse);
      expect(
        UpdateUrlPolicy.isAllowedHost('cisskerala.site@evil.test'),
        isFalse,
      );
    });
  });
}
