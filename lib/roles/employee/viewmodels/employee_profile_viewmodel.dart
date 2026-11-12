import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';

class EmployeeProfileData {
  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String employeeCode;
  final String email;
  final String phone;
  final String? profilePhoto;
  final String department;
  final int? departmentId;
  final String designation;
  final int? designationId;
  final String branch;
  final String organization;
  final String status;
  final String joiningDate;
  final String employmentType;
  final String manager;
  final Map<String, dynamic>? bankDetails;
  final Map<String, dynamic>? salaryStructure;

  const EmployeeProfileData({
    required this.id,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.employeeCode,
    required this.email,
    this.phone = '',
    this.profilePhoto,
    required this.department,
    this.departmentId,
    required this.designation,
    this.designationId,
    this.branch = 'Head Office',
    this.organization = 'QB Suite Enterprise',
    this.status = 'ACTIVE',
    this.joiningDate = '',
    this.employmentType = 'Full-Time',
    this.manager = '',
    this.bankDetails,
    this.salaryStructure,
  });

  factory EmployeeProfileData.fromJson(Map<String, dynamic> json) {
    final directName = (json['name'] ?? json['fullName'] ?? '')
        .toString()
        .trim();
    final fName = (json['firstName'] ?? '').toString().trim();
    final lName = (json['lastName'] ?? '').toString().trim();
    final combinedName = directName.isNotEmpty
        ? directName
        : [fName, lName].where((s) => s.isNotEmpty).join(' ');

    final rawDesigId =
        json['designationId'] ??
        (json['designation'] is Map ? json['designation']['id'] : null);
    final rawDeptId =
        json['departmentId'] ??
        (json['department'] is Map ? json['department']['id'] : null);

    final rawBank = json['bankDetails'];
    Map<String, dynamic>? parsedBank;
    if (rawBank is Map) {
      parsedBank = Map<String, dynamic>.from(rawBank);
    }

    return EmployeeProfileData(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: combinedName.isNotEmpty ? combinedName : '',
      firstName: fName,
      lastName: lName,
      employeeCode:
          (json['employeeCode'] ?? json['code'] ?? json['employeeId'] ?? '')
              .toString()
              .trim(),
      email: (json['email'] ?? '').toString().trim(),
      phone: (json['phone'] ?? json['mobile'] ?? '').toString().trim(),
      profilePhoto:
          (json['profilePhoto'] ??
                  json['avatar'] ??
                  json['profileImage'] ??
                  json['photo'])
              ?.toString(),
      department:
          (json['department'] is Map
                  ? json['department']['name']
                  : json['department'] ?? 'General')
              .toString()
              .trim(),
      departmentId: rawDeptId is int
          ? rawDeptId
          : int.tryParse(rawDeptId?.toString() ?? ''),
      designation:
          (json['designation'] is Map
                  ? json['designation']['name']
                  : json['designation'] ?? 'Staff')
              .toString()
              .trim(),
      designationId: rawDesigId is int
          ? rawDesigId
          : int.tryParse(rawDesigId?.toString() ?? ''),
      branch: (json['branch'] ?? json['office']?['name'] ?? 'Head Office')
          .toString()
          .trim(),
      organization:
          (json['organization'] ?? json['companyName'] ?? 'QB Suite Enterprise')
              .toString()
              .trim(),
      status: (json['status'] ?? 'ACTIVE').toString().trim(),
      joiningDate: (json['joiningDate'] ?? '').toString().trim(),
      employmentType: (json['employmentType'] ?? 'Full-Time').toString().trim(),
      manager: (json['manager'] ?? json['reportingManager'] ?? '').toString().trim(),
      bankDetails: parsedBank,
      salaryStructure: json['salaryStructure'] is Map
          ? Map<String, dynamic>.from(json['salaryStructure'])
          : null,
    );
  }

  factory EmployeeProfileData.empty({
    String name = '',
    String employeeCode = '',
    String email = '',
    String designation = '',
  }) {
    return EmployeeProfileData(
      id: 0,
      name: name,
      employeeCode: employeeCode,
      email: email,
      department: 'General',
      designation: designation.isNotEmpty ? designation : 'Staff',
    );
  }
}

/// Provider to fetch and cache authenticated employee profile directly from /employees/profile/me
final employeeProfileProvider = FutureProvider<EmployeeProfileData>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final authState = ref.watch(loginStateProvider);

  if (apiClient.token == null ||
      apiClient.token!.isEmpty ||
      !authState.isLoggedIn) {
    return EmployeeProfileData.empty();
  }

  try {
    final response = await apiClient.get(AppUrl.employeeProfile);
    if (response.statusCode == 200 && response.data != null) {
      final Map<String, dynamic> rawData = response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);
      final Map<String, dynamic> data = (rawData['data'] is Map)
          ? Map<String, dynamic>.from(rawData['data'])
          : rawData;
      return EmployeeProfileData.fromJson(data);
    }
  } catch (e) {
    debugPrint('[EMPLOYEE_PROFILE] Error fetching profile: $e');
  }

  // Fallback to /attendance/me if needed
  try {
    final response = await apiClient.get('/attendance/me');
    if (response.statusCode == 200 && response.data != null) {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(response.data);
      final Map<String, dynamic> data = (raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'])
          : raw;
      if (data['employee'] is Map) {
        return EmployeeProfileData.fromJson(
          Map<String, dynamic>.from(data['employee']),
        );
      }
    }
  } catch (_) {}

  // Fallback to authenticated loginState data if network profile endpoint is unavailable
  return EmployeeProfileData(
    id: int.tryParse(authState.employeeId ?? '0') ?? 0,
    name: (authState.userName != null && authState.userName!.trim().isNotEmpty)
        ? authState.userName!.trim()
        : '',
    employeeCode:
        (authState.employeeCode != null &&
            authState.employeeCode!.trim().isNotEmpty)
        ? authState.employeeCode!.trim()
        : '',
    email: authState.userEmail ?? '',
    department: 'General',
    designation: authState.userRole ?? 'Staff',
  );
});
