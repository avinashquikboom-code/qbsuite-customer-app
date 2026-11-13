import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/models/work_permission_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/work_permissions_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/customers_view.dart';
import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/views/leads/leads_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermissionManager.instance.clear();
  });

  tearDown(() {
    PermissionManager.instance.clear();
  });

  Widget createDashboardHarness({
    required List<UserPermission> permissions,
    required bool isCrmEligible,
    String role = 'Employee',
    String designation = 'BPO Executive',
    String department = 'BPO',
  }) {
    PermissionManager.instance.setPermissions(
      permissions,
      role: role,
      isCrmEligible: isCrmEligible,
    );

    final effectiveWorkPerms = EmployeeWorkPermissions(
      role: role,
      workPermissions: permissions
          .map((p) => p.module.toLowerCase())
          .toList(),
      isCrmEligible: isCrmEligible,
    );

    final permState = PermissionState(
      permissions: permissions,
      role: role,
      isCrmEligible: isCrmEligible,
      isInitialized: true,
      isLoading: false,
    );

    final authState = LoginState(
      isInitializing: false,
      isLoading: false,
      isLoggedIn: true,
      role: UserRole.employee,
      userRole: role,
      userName: 'Test BPO',
      employeeId: '101',
    );

    final testProfile = EmployeeProfileData(
      id: 101,
      name: 'Test BPO User',
      employeeCode: 'EMP101',
      email: 'bpo@example.com',
      phone: '9999999999',
      designation: designation,
      department: department,
      branch: 'Main',
      organization: 'QuikBoom',
      status: 'ACTIVE',
      joiningDate: '2026-01-01',
      employmentType: 'FULL_TIME',
      manager: 'Manager',
    );

    return ProviderScope(
      overrides: [
        loginStateProvider.overrideWith(() => _MockLoginNotifier(authState)),
        permissionManagerProvider.overrideWith(
          () => _MockPermissionNotifier(permState),
        ),
        workPermissionsProvider.overrideWith(() {
          return _MockWorkPermissionsNotifier(
            WorkPermissionsState(
              permissions: effectiveWorkPerms,
              isLoading: false,
            ),
          );
        }),
        employeeProfileProvider.overrideWith((ref) => Future.value(testProfile)),
        leadsProvider.overrideWith(() => _MockLeadsViewModel()),
        leadStagesProvider.overrideWith(() => _MockLeadStagesNotifier()),
      ],
      child: const MaterialApp(
        home: DashboardView(),
      ),
    );
  }

  group('BPO Bottom Navigation Leads Tab Tests', () {
    testWidgets('BPO team member has Leads tab in bottom navigation', (tester) async {
      final perms = [
        const UserPermission(module: 'DASHBOARD', action: 'VIEW'),
        const UserPermission(module: 'DATA_CAPTURE', action: 'VIEW'),
        const UserPermission(module: 'LEADS', action: 'VIEW'),
      ];

      await tester.pumpWidget(
        createDashboardHarness(
          permissions: perms,
          isCrmEligible: true,
          role: 'BPO Telecaller',
          designation: 'BPO Executive',
          department: 'BPO',
        ),
      );
      await tester.pumpAndSettle();

      // Check bottom navigation tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Data Capture'), findsOneWidget);
      expect(find.text('Leads'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('BPO team member by designation/department gets Leads and Customers tabs even if crmMobileAccess flag is uninitialized', (tester) async {
      final perms = [
        const UserPermission(module: 'DASHBOARD', action: 'VIEW'),
        const UserPermission(module: 'DATA_CAPTURE', action: 'VIEW'),
      ];

      await tester.pumpWidget(
        createDashboardHarness(
          permissions: perms,
          isCrmEligible: false,
          role: 'Employee',
          designation: 'Telesales Representative',
          department: 'BPO',
        ),
      );
      await tester.pumpAndSettle();

      // Leads and Customers tabs must be present for BPO staff
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Leads'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Tapping Leads tab switches to LeadsView', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final perms = [
        const UserPermission(module: 'DASHBOARD', action: 'VIEW'),
        const UserPermission(module: 'DATA_CAPTURE', action: 'VIEW'),
        const UserPermission(module: 'LEADS', action: 'VIEW'),
      ];

      await tester.pumpWidget(
        createDashboardHarness(
          permissions: perms,
          isCrmEligible: true,
          role: 'BPO Executive',
          designation: 'BPO Executive',
          department: 'BPO',
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Leads tab
      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();

      // LeadsView should now be visible
      expect(find.byType(LeadsView), findsOneWidget);
    });

    testWidgets('Tapping Customers tab switches to CustomersView', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final perms = [
        const UserPermission(module: 'DASHBOARD', action: 'VIEW'),
        const UserPermission(module: 'DATA_CAPTURE', action: 'VIEW'),
        const UserPermission(module: 'CUSTOMERS', action: 'VIEW'),
      ];

      await tester.pumpWidget(
        createDashboardHarness(
          permissions: perms,
          isCrmEligible: true,
          role: 'BPO Executive',
          designation: 'BPO Executive',
          department: 'BPO',
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Customers tab
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();

      // CustomersView should now be visible
      expect(find.byType(CustomersView), findsOneWidget);

      await tester.pump(const Duration(seconds: 65));
    });

    testWidgets('Non-BPO team members (e.g. Designer) do NOT get Data Capture, Leads, or Customers in bottom navigation', (tester) async {
      final perms = [
        const UserPermission(module: 'DASHBOARD', action: 'VIEW'),
        const UserPermission(module: 'ATTENDANCE', action: 'VIEW'),
        const UserPermission(module: 'MY_WORK', action: 'VIEW'),
      ];

      await tester.pumpWidget(
        createDashboardHarness(
          permissions: perms,
          isCrmEligible: false,
          role: 'Designer',
          designation: 'Graphic Designer',
          department: 'Creative',
        ),
      );
      await tester.pumpAndSettle();

      // Must have Home, My Work, Profile
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Work'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // CRM options MUST NOT be present
      expect(find.text('Data Capture'), findsNothing);
      expect(find.text('Leads'), findsNothing);
      expect(find.text('Customers'), findsNothing);

      await tester.pump(const Duration(seconds: 65));
    });

    testWidgets('Visitor employees see visit CRM tabs and not BPO leads', (tester) async {
      await tester.pumpWidget(
        createDashboardHarness(
          permissions: const [
            UserPermission(module: 'DASHBOARD', action: 'VIEW'),
            UserPermission(module: 'VISITS', action: 'VIEW'),
            UserPermission(module: 'LEADS', action: 'VIEW'),
          ],
          isCrmEligible: false,
          role: 'Visitor',
          designation: 'Visitor Executive',
          department: 'Field',
        ),
      );
      await tester.pump();

      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Leads'), findsNothing);
      expect(find.text('Data Capture'), findsNothing);

      await tester.pump(const Duration(seconds: 65));
    });

    testWidgets('Sales employees see assigned leads without BPO-only tabs', (tester) async {
      await tester.pumpWidget(
        createDashboardHarness(
          permissions: const [
            UserPermission(module: 'DASHBOARD', action: 'VIEW'),
            UserPermission(module: 'LEADS', action: 'VIEW'),
            UserPermission(module: 'ATTENDANCE', action: 'VIEW'),
          ],
          isCrmEligible: true,
          role: 'Sales Executive',
          designation: 'Sales Executive',
          department: 'Sales',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leads'), findsOneWidget);
      expect(find.text('Data Capture'), findsNothing);
      expect(find.text('Customers'), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      await tester.pump(const Duration(seconds: 65));
    });
  });
}

class _MockLoginNotifier extends LoginStateNotifier {
  final LoginState _state;
  _MockLoginNotifier(this._state);

  @override
  LoginState build() => _state;
}

class _MockPermissionNotifier extends PermissionNotifier {
  final PermissionState _initial;
  _MockPermissionNotifier(this._initial);

  @override
  PermissionState build() => _initial;
}

class _MockWorkPermissionsNotifier extends WorkPermissionsNotifier {
  final WorkPermissionsState _initial;
  _MockWorkPermissionsNotifier(this._initial);

  @override
  WorkPermissionsState build() => _initial;

  @override
  Future<void> loadPermissions() async {}
}

class _MockLeadsViewModel extends LeadsViewModel {
  @override
  AsyncValue<List<LeadModel>> build() => const AsyncValue.data(<LeadModel>[]);

  @override
  Future<void> fetchLeads({
    String? status,
    String? search,
    int? stageId,
    String? source,
    String? category,
    int? assignedToId,
    String? from,
    String? to,
    bool refreshCounts = false,
  }) async {}
}

class _MockLeadStagesNotifier extends LeadStagesNotifier {
  @override
  Future<List<LeadStageModel>> build() async => const <LeadStageModel>[];
}

