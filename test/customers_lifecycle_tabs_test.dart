import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/customers_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final upcomingCustomer = CustomerModel(
    customerId: 'LEAD-0101',
    leadId: '101',
    businessName: 'Alpha Logistics',
    companyName: 'Alpha Logistics',
    customerName: 'Alice Smith',
    contactPerson: 'Alice Smith',
    mobile: '+919876543210',
    email: 'alice@alpha.com',
    address: 'Sector 10',
    city: 'Mumbai',
    state: 'Maharashtra',
    pincode: '400001',
    source: 'GOOGLE_PLACES',
    assignedEmployee: 'John Agent',
    leadClosingDate: '25 Oct 2026',
    status: 'UPCOMING',
    customerStatus: 'UPCOMING',
    leadStatus: 'FINAL_CALL',
    leadStageName: 'Final Call',
    hasUpcomingCall: true,
    upcomingCallType: 'Final Call',
    upcomingCallDate: '25 Oct 2026',
    upcomingCallTime: '11:00 AM',
    notes: 'Follow up for closing',
    value: 50000.0,
  );

  final inactiveCustomer = CustomerModel(
    customerId: 'CUST-0202',
    leadId: '102',
    businessName: 'Beta Retailers',
    companyName: 'Beta Retailers',
    customerName: 'Bob Jones',
    contactPerson: 'Bob Jones',
    mobile: '+919876543211',
    email: 'bob@beta.com',
    address: 'Ring Road',
    city: 'Pune',
    state: 'Maharashtra',
    pincode: '411001',
    source: 'MANUAL',
    assignedEmployee: 'Sarah Connor',
    leadClosingDate: '24 Oct 2026',
    status: 'INACTIVE',
    customerStatus: 'INACTIVE',
    leadStatus: 'WON',
    leadStageName: 'Won',
    hasUpcomingCall: false,
    subscriptionStatus: 'NO_PLAN',
    planName: null,
    notes: 'Won deal, awaiting plan purchase',
    value: 75000.0,
  );

  final activeCustomer = CustomerModel(
    customerId: 'CUST-0303',
    leadId: '103',
    businessName: 'Gamma Enterprises',
    companyName: 'Gamma Enterprises',
    customerName: 'Charlie Brown',
    contactPerson: 'Charlie Brown',
    mobile: '+919876543212',
    email: 'charlie@gamma.com',
    address: 'Tech Park',
    city: 'Bengaluru',
    state: 'Karnataka',
    pincode: '560001',
    source: 'WEBSITE',
    assignedEmployee: 'Sarah Connor',
    leadClosingDate: '20 Oct 2026',
    status: 'ACTIVE',
    customerStatus: 'ACTIVE',
    leadStatus: 'WON',
    leadStageName: 'Won',
    hasUpcomingCall: false,
    subscriptionStatus: 'ACTIVE',
    planName: 'Growth Pro Plan',
    notes: 'Active subscriber',
    value: 120000.0,
  );

  final mockCustomersResponse = CustomersResponse(
    customers: [upcomingCustomer, inactiveCustomer, activeCustomer],
    counts: {'upcoming': 1, 'inactive': 1, 'active': 1, 'all': 3},
  );

  Widget createHarness({CustomersResponse? response}) {
  final base = response ?? mockCustomersResponse;
    return ProviderScope(
      overrides: [
        customersDirectoryProvider.overrideWith((ref, query) async {
          var rows = base.customers;
          switch (query.status) {
            case 'ACTIVE':
              rows = rows.where((c) => c.customerStatus == 'ACTIVE').toList();
              break;
            case 'INACTIVE':
              rows = rows.where((c) => c.customerStatus == 'INACTIVE').toList();
              break;
            case 'UPCOMING':
              rows = rows.where((c) => c.customerStatus == 'UPCOMING').toList();
              break;
          }
          final q = query.search.trim().toLowerCase();
          if (q.isNotEmpty) {
            rows = rows.where((c) => c.matchesQuery(q)).toList();
          }
          return CustomersResponse(customers: rows, counts: base.counts);
        }),
      ],
      child: const MaterialApp(home: CustomersView()),
    );
  }

  group('Customers Screen Lifecycle Tabs', () {
    testWidgets(
      '1. Shows the 4 filter tabs: All, Active, Inactive, Upcoming in sequence with badges',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createHarness());
        await tester.pumpAndSettle();

        // Verify the 4 tabs are rendered in sequence
        expect(find.byKey(const ValueKey('filter_tab_All')), findsOneWidget);
        expect(find.byKey(const ValueKey('filter_tab_Active')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('filter_tab_Inactive')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('filter_tab_Upcoming')),
          findsOneWidget,
        );

        // Verify default selected tab is All (showing all customer records)
        expect(find.text('Alpha Logistics'), findsOneWidget);
        expect(find.text('Beta Retailers'), findsOneWidget);
        expect(find.text('Gamma Enterprises'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Tapping Active tab shows customers with an activated plan',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createHarness());
        await tester.pumpAndSettle();

        // Tap Active tab
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Active')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Active')));
        await tester.pumpAndSettle();

        expect(find.text('Gamma Enterprises'), findsOneWidget);
        expect(find.text('Alpha Logistics'), findsNothing);
        expect(find.text('Beta Retailers'), findsNothing);
        expect(find.text('Growth Pro Plan'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Tapping Inactive tab shows only Won customers without active plan',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createHarness());
        await tester.pumpAndSettle();

        // Tap Inactive tab
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Inactive')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Inactive')));
        await tester.pumpAndSettle();

        expect(find.text('Beta Retailers'), findsOneWidget);
        expect(find.text('Alpha Logistics'), findsNothing);
        expect(find.text('Gamma Enterprises'), findsNothing);
        expect(find.text('Inactive'), findsWidgets);
      },
    );

    testWidgets(
      '4. Tapping Upcoming tab shows only customers with upcoming calls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createHarness());
        await tester.pumpAndSettle();

        // Tap Upcoming tab
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Upcoming')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Upcoming')));
        await tester.pumpAndSettle();

        expect(find.text('Alpha Logistics'), findsOneWidget);
        expect(find.text('Beta Retailers'), findsNothing);
        expect(find.text('Gamma Enterprises'), findsNothing);
      },
    );

    testWidgets('5. Search filters correctly within selected tab', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createHarness());
      await tester.pumpAndSettle();

      // Default tab is All with all records
      expect(find.text('Alpha Logistics'), findsOneWidget);
      expect(find.text('Beta Retailers'), findsOneWidget);

      // Search for specific customer
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();

      expect(find.text('Alpha Logistics'), findsOneWidget);
      expect(find.text('Beta Retailers'), findsNothing);

      // Search for something not matching
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pumpAndSettle();

      expect(find.text('Alpha Logistics'), findsNothing);
      expect(find.text('No Results for "nonexistent"'), findsOneWidget);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Alpha Logistics'), findsOneWidget);
      expect(find.text('Beta Retailers'), findsOneWidget);
    });

    testWidgets(
      '6. Empty states render appropriate messages when tabs have no records',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final emptyResponse = const CustomersResponse(
          customers: [],
          counts: {'upcoming': 0, 'inactive': 0, 'active': 0, 'all': 0},
        );

        await tester.pumpWidget(createHarness(response: emptyResponse));
        await tester.pumpAndSettle();

        // All empty state
        expect(find.text('No Customers'), findsOneWidget);

        // Upcoming empty state
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Upcoming')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Upcoming')));
        await tester.pumpAndSettle();
        expect(find.text('No Upcoming Calls'), findsOneWidget);

        // Inactive empty state
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Inactive')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Inactive')));
        await tester.pumpAndSettle();
        expect(find.text('No Inactive Customers'), findsOneWidget);

        // Active empty state
        await tester.ensureVisible(
          find.byKey(const ValueKey('filter_tab_Active')),
        );
        await tester.tap(find.byKey(const ValueKey('filter_tab_Active')));
        await tester.pumpAndSettle();
        expect(find.text('No Active Customers'), findsOneWidget);
      },
    );
  });
}
