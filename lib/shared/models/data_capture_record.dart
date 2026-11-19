import 'data_capture_model.dart';

/// A saved record returned by the Data Capture CRUD endpoints.
class DataCaptureRecord {
  final Map<String, dynamic> fields;
  DataCaptureRecord.fromJson(Map<String, dynamic> json)
    : fields = Map.unmodifiable(_unwrapRecord(json));

  static Map<String, dynamic> _unwrapRecord(Map<String, dynamic> input) {
    var value = input;
    // Accept the common Nest response wrappers while retaining the exact
    // captured-row fields as the model source of truth.
    while (value['data'] is Map) {
      value = Map<String, dynamic>.from(value['data'] as Map);
    }
    return value;
  }

  int get id => int.parse(fields['id'].toString());
  String get businessName {
    for (final key in const ['businessName', 'business_name', 'name', 'placeName', 'place_name', 'title']) {
      final value = fields[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
  String get status => fields['status']?.toString() ?? '';
  CapturedBusiness get business => CapturedBusiness.fromJson(fields);
  String? get googlePlaceId {
    final value = fields['googlePlaceId'] ?? fields['google_place_id'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString().trim();
  }
  String? get phone {
    final value = fields['phone'] ?? fields['phoneNumber'] ?? fields['phone_number'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString().trim();
  }
  String? get address {
    final value = fields['address'] ?? fields['formattedAddress'] ?? fields['formatted_address'];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString().trim();
  }
  double? get latitude => _toDouble(fields['latitude'] ?? fields['lat']);
  double? get longitude => _toDouble(fields['longitude'] ?? fields['lng'] ?? fields['lon']);
  static double? _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
}

class DataCapturePage {
  final List<DataCaptureRecord> records;
  final int page, total, totalPages;
  DataCapturePage.fromJson(Map<String, dynamic> json)
    : records = (json['data'] as List)
          .map(
            (e) =>
                DataCaptureRecord.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      page = (json['pagination']['page'] as num).toInt(),
      total = (json['pagination']['total'] as num).toInt(),
      totalPages = (json['pagination']['totalPages'] as num).toInt();
}
