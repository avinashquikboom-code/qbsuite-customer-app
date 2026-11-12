import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickboom_crm_customer/roles/customer/models/customer_model.dart';
import 'leads_viewmodel.dart';

/// Derives customers from WON/WORK_STARTED leads.
/// One closed Lead = One Customer (deduplication by leadId).
/// No separate storage needed — computed from leadsProvider.
final customersProvider = Provider<List<CustomerModel>>((ref) {
  final leadsState = ref.watch(leadsProvider);
  return leadsState.maybeWhen(
    data: (leads) {
      // Filter closed leads and convert to CustomerModel
      final seen = <String>{};
      final customers = <CustomerModel>[];
      for (final lead in leads) {
        if (CustomerModel.isClosedLead(lead) && !seen.contains(lead.id)) {
          seen.add(lead.id);
          customers.add(CustomerModel.fromLead(lead));
        }
      }
      // Sort by business name
      customers.sort((a, b) => a.businessName.compareTo(b.businessName));
      return customers;
    },
    orElse: () => [],
  );
});

class CustomerSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

/// Provides a filtered customer list based on search query
final customerSearchProvider = NotifierProvider<CustomerSearchNotifier, String>(
  CustomerSearchNotifier.new,
);

final filteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersProvider);
  final query = ref.watch(customerSearchProvider);
  if (query.isEmpty) return customers;
  return customers.where((c) => c.matchesQuery(query)).toList();
});
