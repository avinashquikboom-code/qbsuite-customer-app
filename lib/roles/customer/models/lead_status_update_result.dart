import 'lead_model.dart';

class LeadStatusUpdateResult {
  const LeadStatusUpdateResult({
    required this.lead,
    this.emailNotification,
    this.whatsappNotification,
  });

  final LeadModel lead;
  final Map<String, dynamic>? emailNotification;
  final Map<String, dynamic>? whatsappNotification;

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static LeadStatusUpdateResult fromApiResponse(Map<String, dynamic> root) {
    final nested = root['data'];
    final leadMap = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(root);

    final email = _mapOrNull(root['emailNotification']) ?? _mapOrNull(leadMap['emailNotification']);
    final whatsapp = _mapOrNull(root['whatsappNotification']) ?? _mapOrNull(leadMap['whatsappNotification']);

    final sanitizedLead = Map<String, dynamic>.from(leadMap)
      ..remove('emailNotification')
      ..remove('whatsappNotification');

    return LeadStatusUpdateResult(
      lead: LeadModel.fromJson(sanitizedLead),
      emailNotification: email,
      whatsappNotification: whatsapp,
    );
  }
}
