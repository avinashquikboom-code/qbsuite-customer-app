import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_record.dart';

void main() {
  test('maps saved API fields and numeric internal ID from the actual record shape', () {
    final record = DataCaptureRecord.fromJson({
      'id': 31,
      'businessName': 'Northwind Retail',
      'googlePlaceId': 'ChIJ-example',
      'sourceRecordId': 'ChIJ-example',
      'phone': '+14155550100',
      'address': '100 Market Street',
      'latitude': 37.79,
      'longitude': -122.39,
      'status': 'VALIDATED',
    });

    expect(record.id, 31);
    expect(record.businessName, 'Northwind Retail');
    expect(record.googlePlaceId, 'ChIJ-example');
    expect(record.phone, '+14155550100');
    expect(record.address, '100 Market Street');
    expect(record.latitude, 37.79);
    expect(record.longitude, -122.39);
  });

  test('unwraps a response data wrapper without confusing place ID and capture ID', () {
    final record = DataCaptureRecord.fromJson({
      'data': {
        'id': 44,
        'business_name': 'Contoso Services',
        'place_id': 'ChIJ-reference',
        'phone_number': '+14155550101',
        'formatted_address': '200 Main Street',
      },
    });

    expect(record.id, 44);
    expect(record.businessName, 'Contoso Services');
    expect(record.googlePlaceId, isNull);
    expect(record.phone, '+14155550101');
    expect(record.address, '200 Main Street');
  });
}
