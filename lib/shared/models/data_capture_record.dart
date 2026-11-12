import 'data_capture_model.dart';

/// A saved record returned by the Data Capture CRUD endpoints.
class DataCaptureRecord {
  final Map<String, dynamic> fields;
  DataCaptureRecord.fromJson(Map<String, dynamic> json)
    : fields = Map.unmodifiable(json);
  int get id => int.parse(fields['id'].toString());
  String get businessName => fields['businessName']?.toString() ?? '';
  String get status => fields['status']?.toString() ?? '';
  CapturedBusiness get business => CapturedBusiness.fromJson(fields);
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
