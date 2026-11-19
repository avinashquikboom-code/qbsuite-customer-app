import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';
import 'package:quickboom_crm_customer/shared/services/data_capture_service.dart';

void main() {
  test('only imported or duplicate source records are marked imported', () {
    final places = [
      _place(id: 1, googlePlaceId: 'place-imported'),
      _place(id: 2, googlePlaceId: 'place-duplicate'),
      _place(id: 3, googlePlaceId: 'place-failed'),
    ];

    applyImportOutcomesToCapturedPlaces(places, [
      {
        'sourceRecordId': '1',
        'googlePlaceId': 'place-imported',
        'imported': true,
      },
      {
        'sourceRecordId': '2',
        'googlePlaceId': 'place-duplicate',
        'duplicate': true,
      },
      {'sourceRecordId': '3', 'googlePlaceId': 'place-failed', 'failed': true},
    ]);

    expect(places.map((place) => place.isImported), [true, true, false]);
    expect(places.map((place) => place.isSelected), [false, false, true]);
  });
}

CapturedBusiness _place({required int id, required String googlePlaceId}) =>
    CapturedBusiness(
      id: id,
      googlePlaceId: googlePlaceId,
      businessName: 'Business $id',
      category: 'Retail',
      address: 'Address $id',
      phone: '',
      capturedAt: DateTime(2026),
    );
