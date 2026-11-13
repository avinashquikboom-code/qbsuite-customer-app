/// CRM category returned by the employee login and profile APIs.
enum CrmEmployeeCategory { bpo, visitor, sales, none }

const String kCrmAccessRestrictedTitle = 'Access Restricted';

const String kCustomerAppAccessMessage =
    'This app is only for customers who registered on mobile or were created from a lead.';

const String kCrmAccessRestrictedMessage =
    'Your account is not authorized to access the QB Suite CRM application.\n\n'
    'Visitor and Lead Visitor employees use the QB Suite Visitor app. CRM access is available to BPO and Sales employees.\n\n'
    'Please contact your administrator if you believe this is a mistake.';

CrmEmployeeCategory? parseCrmCategory(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'BPO':
      return CrmEmployeeCategory.bpo;
    case 'VISITOR':
      return CrmEmployeeCategory.visitor;
    case 'SALES':
      return CrmEmployeeCategory.sales;
    case 'NONE':
      return CrmEmployeeCategory.none;
    default:
      return null;
  }
}

bool _isBpo(String value) => value.toUpperCase().contains('BPO');

bool _isTelesales(String value) {
  final text = value.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  return text.contains('TELESALES') ||
      text.contains('TELE_SALES') ||
      text.contains('TELECALL') ||
      text.contains('TELE_CALL') ||
      text.contains('TELESELL');
}

bool _isSales(String value) =>
    value.toUpperCase().contains('SALES') && !_isTelesales(value);

bool _isVisitor(String value) {
  final text = value.toUpperCase().trim();
  return text.contains('VISITOR') ||
      text == 'VISIT' ||
      text.contains('FIELD VISIT') ||
      text.contains('FIELD OFFICER');
}

/// Uses the backend category when login already resolved it.
/// Otherwise reads the department, designation, and role returned for this employee.
CrmEmployeeCategory classifyCrmEmployee({
  String? department,
  String? designation,
  String? role,
  String? backendCategory,
}) {
  final parsed = parseCrmCategory(backendCategory);
  if (parsed != null) return parsed;

  final departmentBpo = _isBpo(department ?? '');
  final designationBpo = _isBpo(designation ?? '');
  final designationVisitor = _isVisitor(designation ?? '');
  final roleBpo = _isBpo(role ?? '');
  final roleVisitor = _isVisitor(role ?? '');
  final values = [department, designation, role].whereType<String>();
  final telesales = values.any(_isTelesales);
  final sales = values.any(_isSales);

  if (designationVisitor && !departmentBpo && !designationBpo && !telesales) {
    return CrmEmployeeCategory.visitor;
  }
  if (departmentBpo || designationBpo || roleBpo || telesales) {
    return CrmEmployeeCategory.bpo;
  }
  if (sales) {
    return CrmEmployeeCategory.sales;
  }
  if (designationVisitor || roleVisitor) {
    return CrmEmployeeCategory.visitor;
  }
  return CrmEmployeeCategory.none;
}

String? crmLabel(dynamic value) {
  if (value is Map) {
    return crmLabel(value['name'] ?? value['code'] ?? value['type']);
  }
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

/// Visitor and Lead Visitor employees belong in the visitor app, even when
/// the login payload also carries a BPO or Sales category.
bool isVisitorTeamAccount({
  String? department,
  String? designation,
  String? role,
  String? backendCategory,
}) {
  if (parseCrmCategory(backendCategory) == CrmEmployeeCategory.visitor) {
    return true;
  }
  return [department, designation, role].whereType<String>().any(_isVisitor);
}

bool isTelecallerOrBpoStaff({
  String? role,
  String? crmCategory,
  String? designation,
  bool isCrmEligible = false,
}) {
  final cat = (crmCategory ?? '').trim().toUpperCase();
  if (cat == 'BPO') return true;
  final raw = (role ?? '').trim().toUpperCase();
  if (raw.contains('BPO')) return true;
  if (_isTelesales(raw)) return true;
  final desig = (designation ?? '').trim().toUpperCase();
  if (desig.contains('BPO') || _isTelesales(desig)) return true;
  return isCrmEligible && cat != 'VISITOR' && cat != 'SALES';
}

bool isFieldVisitorActor({
  String? role,
  String? crmCategory,
  bool isCrmEligible = false,
}) {
  if (isTelecallerOrBpoStaff(role: role, crmCategory: crmCategory, isCrmEligible: isCrmEligible)) {
    return false;
  }
  final raw = (role ?? '').trim().toUpperCase();
  if (raw.contains('ADMIN') || raw.contains('CUSTOMER') || raw == 'SUPER_ADMIN') {
    return false;
  }
  final cat = (crmCategory ?? '').trim().toUpperCase();
  if (cat == 'VISITOR') return true;
  return raw.contains('VISITOR') || raw.contains('FIELD') || _isVisitor(raw);
}

bool canEmployeeScheduleFieldVisit({
  String? role,
  String? crmCategory,
  bool isCrmEligible = false,
  bool canScheduleVisits = false,
}) {
  final raw = (role ?? '').trim().toUpperCase();
  final isCustomerOrAdmin =
      raw.contains('CUSTOMER') || raw.contains('ADMIN') || raw == 'SUPER_ADMIN';
  if (isCustomerOrAdmin) return true;
  if (isFieldVisitorActor(role: role, crmCategory: crmCategory, isCrmEligible: isCrmEligible)) {
    return false;
  }
  if (isTelecallerOrBpoStaff(role: role, crmCategory: crmCategory, isCrmEligible: isCrmEligible)) {
    return true;
  }
  return canScheduleVisits;
}
