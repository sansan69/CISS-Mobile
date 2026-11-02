import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/app/motion.dart';

void main() {
  test('route timings are within the motion budget', () {
    expect(AppMotion.routeIn.inMilliseconds, lessThanOrEqualTo(300));
    expect(
      AppMotion.routeOut.inMilliseconds,
      lessThan(AppMotion.routeIn.inMilliseconds),
    );
    expect(AppMotion.press.inMilliseconds, inInclusiveRange(100, 150));
  });
}
