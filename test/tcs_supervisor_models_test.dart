import 'package:flutter_test/flutter_test.dart';
import 'package:ciss_mobile/core/models/report_models.dart';
import 'package:ciss_mobile/core/models/mobile_dashboard_models.dart';

void main() {
  test('work-order counts and site shift templates retain server data', () {
    final dynamic order = WorkOrderModel.fromJson({
      'willingCount': 8,
      'unavailableCount': 3,
    });
    expect(order.willingCount, 8);
    expect(order.unavailableCount, 3);
    final dynamic site = FieldOfficerSiteOption.fromJson({
      'id': 's1',
      'shiftTemplates': [
        {
          'code': 'N',
          'label': 'Night',
          'startTime': '22:00',
          'endTime': '06:00',
        },
      ],
    });
    expect(site.shiftTemplates.single.code, 'N');
  });
}
