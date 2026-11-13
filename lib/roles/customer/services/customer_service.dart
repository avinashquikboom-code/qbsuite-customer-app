import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_url.dart';
import '../models/customer_model.dart';
import '../models/lead_model.dart';

class CustomersResponse {
  final List<CustomerModel> customers;
  final Map<String, int> counts;

  const CustomersResponse({required this.customers, required this.counts});
}

final customerServiceProvider = Provider<CustomerService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CustomerService(client);
});

/// Query for Customers directory (tab + server-side search).
@immutable
class CustomersDirectoryQuery {
  final String status;
  final String search;

  const CustomersDirectoryQuery({
    this.status = 'ALL',
    this.search = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomersDirectoryQuery &&
          other.status == status &&
          other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

final customersDirectoryProvider = FutureProvider.autoDispose
    .family<CustomersResponse, CustomersDirectoryQuery>((ref, query) async {
  final service = ref.watch(customerServiceProvider);
  return service.getCustomers(
    status: query.status,
    search: query.search.trim().isEmpty ? null : query.search.trim(),
    page: 1,
    limit: 100,
  );
});

/// Invalidate after lead stage / conversion / billing changes.
void invalidateCustomersDirectory(WidgetRef ref) {
  ref.invalidate(customersDirectoryProvider);
  ref.invalidate(customersListProvider);
}

/// Lightweight global refresh (legacy call sites).
final customersListProvider = FutureProvider.autoDispose<CustomersResponse>((
  ref,
) async {
  final service = ref.watch(customerServiceProvider);
  return service.getCustomers();
});

final customerDetailFutureProvider =
    FutureProvider.family<Map<String, dynamic>?, dynamic>((
      ref,
      customerId,
    ) async {
      final service = ref.watch(customerServiceProvider);
      return service.getCustomerDetails(customerId);
    });

final customerAssignedTeamProvider =
    FutureProvider.family<Map<String, dynamic>?, dynamic>((
      ref,
      customerId,
    ) async {
      final service = ref.watch(customerServiceProvider);
      return service.getAssignedTeam(customerId);
    });

final availableTeamsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(customerServiceProvider);
  return service.getAvailableTeams();
});

/// Service responsible for fetching Customer profile and account details from /api/v1/customers/{id}
/// and managing team assignments.
class CustomerService {
  final ApiClient _client;

  CustomerService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches single customer details by ID via authenticated GET /api/v1/customers/{id}.
  /// Uses existing session token via ApiClient's global interceptor.
  Future<Map<String, dynamic>?> getCustomerDetails(dynamic customerId) async {
    final rawStr = customerId?.toString().trim();
    if (rawStr == null || rawStr.isEmpty) {
      debugPrint(
        '[CUSTOMER_SERVICE] Cannot fetch customer details: customerId is null or empty',
      );
      return null;
    }

    if (rawStr.startsWith('-')) {
      debugPrint(
        '[CUSTOMER_SERVICE] Cannot fetch customer details: negative customerId "$rawStr" is invalid',
      );
      return null;
    }

    final cleanId = rawStr.replaceAll(RegExp(r'^[^\d]+'), '').trim();
    final parsed = int.tryParse(cleanId);
    if (parsed == null || parsed <= 0) {
      debugPrint(
        '[CUSTOMER_SERVICE] Cannot fetch customer details: non-positive customerId "$rawStr" is invalid',
      );
      return null;
    }

    try {
      final endpoint = AppUrl.customerDetails(parsed);
      final response = await _client.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        if (raw is Map<String, dynamic>) {
          if (raw['data'] is Map<String, dynamic>) {
            return raw['data'] as Map<String, dynamic>;
          }
          return raw;
        }
      }
      return null;
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint(
        '[CUSTOMER_SERVICE] Dio error fetching customer $cleanId (HTTP $status): ${dioErr.message}',
      );
      if (status == 401) {
        debugPrint('[CUSTOMER_SERVICE] 401 Unauthorized for customer $cleanId');
      } else if (status == 403) {
        debugPrint(
          '[CUSTOMER_SERVICE] 403 Forbidden: insufficient permission for customer $cleanId',
        );
      } else if (status == 404) {
        debugPrint('[CUSTOMER_SERVICE] 404 Not Found for customer $cleanId');
      }
      rethrow;
    } catch (e) {
      debugPrint(
        '[CUSTOMER_SERVICE] Unexpected error fetching customer $cleanId: $e',
      );
      rethrow;
    }
  }

  /// Fetches assigned team for a customer via GET /api/v1/customers/{id}/assign-team.
  Future<Map<String, dynamic>?> getAssignedTeam(dynamic customerId) async {
    final rawId = customerId?.toString().trim() ?? '';
    final directId = int.tryParse(rawId);
    final prefixedMatch = RegExp(
      r'^CUST-(\d+)$',
      caseSensitive: false,
    ).firstMatch(rawId);
    final parsedId =
        directId ?? int.tryParse(prefixedMatch?.group(1) ?? '');
    if (parsedId == null || parsedId <= 0) {
      throw ArgumentError.value(
        customerId,
        'customerId',
        'A valid customer database ID is required.',
      );
    }
    final cleanId = parsedId.toString();

    try {
      final endpoint = AppUrl.customerAssignTeam(cleanId);
      final response = await _client.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        if (raw is Map<String, dynamic>) {
          if (raw['data'] is Map<String, dynamic>) {
            return raw['data'] as Map<String, dynamic>;
          }
          return raw;
        }
      }
      return null;
    } on DioException catch (dioErr) {
      debugPrint(
        '[CUSTOMER_SERVICE] Error fetching assigned team for customer $cleanId: ${dioErr.message}',
      );
      if (dioErr.response?.statusCode == 404) {
        try {
          final details = await getCustomerDetails(parsedId);
          if (details != null) {
            final dynamic team = details['assignedTeam'] ?? details['team'];
            return {
              'id': parsedId,
              'customerId': parsedId,
              'assignedTeamId': details['assignedTeamId'],
              'team': team is Map<String, dynamic> ? team : null,
              'assignedTeam': team is Map<String, dynamic> ? team : null,
            };
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Assigns customer to a team via PATCH /api/v1/customers/{id}/assign-team.
  /// Pass [teamId] = null to unassign.
  Future<Map<String, dynamic>?> assignTeam(
    dynamic customerId,
    int? teamId,
  ) async {
    final rawId = customerId?.toString().trim() ?? '';
    final directId = int.tryParse(rawId);
    final prefixedMatch = RegExp(
      r'^CUST-(\d+)$',
      caseSensitive: false,
    ).firstMatch(rawId);
    final parsedId =
        directId ?? int.tryParse(prefixedMatch?.group(1) ?? '');
    if (parsedId == null || parsedId <= 0) {
      throw ArgumentError.value(
        customerId,
        'customerId',
        'A valid customer database ID is required.',
      );
    }
    final cleanId = parsedId.toString();

    try {
      final endpoint = AppUrl.customerAssignTeam(cleanId);
      final response = await _client.patch(endpoint, data: {'teamId': teamId});

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        if (raw is Map<String, dynamic>) {
          if (raw['data'] is Map<String, dynamic>) {
            return raw['data'] as Map<String, dynamic>;
          }
          return raw;
        }
      }
      return null;
    } on DioException catch (dioErr) {
      debugPrint(
        '[CUSTOMER_SERVICE] Error assigning team $teamId to customer $cleanId: ${dioErr.message}',
      );
      rethrow;
    }
  }

  /// Fetches available teams from GET /api/v1/teams.
  Future<List<Map<String, dynamic>>> getAvailableTeams() async {
    try {
      final response = await _client.get(AppUrl.teams);
      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        List<dynamic>? list;
        if (raw is Map<String, dynamic>) {
          if (raw['data'] is List) {
            list = raw['data'] as List<dynamic>;
          } else if (raw['items'] is List) {
            list = raw['items'] as List<dynamic>;
          } else if (raw['data'] is Map && (raw['data'] as Map)['items'] is List) {
            list = (raw['data'] as Map)['items'] as List<dynamic>;
          }
        } else if (raw is List) {
          list = raw;
        }

        if (list != null) {
          return list.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } on DioException catch (dioErr) {
      debugPrint(
        '[CUSTOMER_SERVICE] Error fetching available teams: ${dioErr.message}',
      );
      return [];
    }
  }

  /// Fetches customers with pagination, dynamic counts and lead info via GET /api/v1/customers.
  Future<CustomersResponse> getCustomers({
    String? search,
    String? status,
    int page = 1,
    int limit = 100,
    bool forCalendar = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status != 'ALL' && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      if (forCalendar) {
        queryParams['forCalendar'] = 'true';
        queryParams['isActive'] = 'true';
      }

      final response = await _client.get(
        AppUrl.customers,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        List<dynamic> itemsRaw = [];
        Map<String, int> counts = {
          'active': 0,
          'upcoming': 0,
          'inactive': 0,
          'completed': 0,
          'all': 0,
        };
        int? paginationTotal;

        void absorbPayload(Map<String, dynamic> map) {
          if (itemsRaw.isEmpty) {
            if (map['items'] is List) {
              itemsRaw = map['items'] as List<dynamic>;
            } else if (map['data'] is List) {
              itemsRaw = map['data'] as List<dynamic>;
            }
          }
          final meta = map['meta'];
          if (meta is Map && meta['counts'] is Map) {
            final c = meta['counts'] as Map;
            counts = {
              'active': (c['active'] as num?)?.toInt() ?? 0,
              'upcoming': (c['upcoming'] as num?)?.toInt() ?? 0,
              'inactive': (c['inactive'] as num?)?.toInt() ?? 0,
              'completed': (c['completed'] as num?)?.toInt() ?? 0,
              'all': (c['all'] as num?)?.toInt() ?? 0,
            };
          }
          final pagination = map['pagination'];
          if (pagination is Map && pagination['total'] != null) {
            paginationTotal = (pagination['total'] as num?)?.toInt();
          }
        }

        if (raw is Map<String, dynamic>) {
          absorbPayload(raw);
          if (itemsRaw.isEmpty && raw['data'] is Map<String, dynamic>) {
            absorbPayload(raw['data'] as Map<String, dynamic>);
          }
        } else if (raw is List) {
          itemsRaw = raw;
        }

        final customers = itemsRaw
            .whereType<Map<String, dynamic>>()
            .map((j) => CustomerModel.fromJson(j))
            .where(_isEligibleCustomerRecord)
            .toList();

        if (kDebugMode) {
          final ids = customers
              .map(
                (c) =>
                    '${c.customerId}|${c.customerStatus}|${c.leadStatus ?? ""}|${c.subscriptionStatus ?? ""}',
              )
              .join('; ');
          debugPrint(
            '[CUSTOMERS] filter=${status ?? "ALL"} search=${search ?? ""} page=$page limit=$limit apiCounts=$counts paginationTotal=$paginationTotal parsed=${customers.length} ids=$ids',
          );
        }

        return CustomersResponse(customers: customers, counts: counts);
      }
      throw Exception('Failed to load customers (HTTP ${response.statusCode})');
    } on DioException catch (dioErr) {
      debugPrint(
        '[CUSTOMER_SERVICE] Dio error fetching customers: ${dioErr.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[CUSTOMER_SERVICE] Error fetching customers: $e');
      rethrow;
    }
  }

  /// Merges Won leads (as Customers) and Follow-up / Final Call leads (Upcoming only)
  /// that are not yet present as Customer records.
  CustomersResponse mergeWithUpcomingLeads(
    CustomersResponse response,
    List<LeadModel> leads,
  ) {
    if (leads.isEmpty) return response;

    final existingCustomerIds = <String>{};
    final existingLeadIds = <String>{};

    for (final c in response.customers) {
      if (c.customerId.isNotEmpty) existingCustomerIds.add(c.customerId);
      if (c.leadId.isNotEmpty) existingLeadIds.add(c.leadId);
    }

    final mergedCustomers = List<CustomerModel>.from(response.customers);

    for (final lead in leads) {
      if (!lead.isWon) continue;

      final custId = 'LEAD-${lead.id.padLeft(4, '0')}';
      final altCustId = 'CUST-${lead.id}';
      if (!existingLeadIds.contains(lead.id) &&
          !existingCustomerIds.contains(custId) &&
          !existingCustomerIds.contains(altCustId)) {
        final cust = CustomerModel.fromLead(lead);
        mergedCustomers.add(cust);
        existingLeadIds.add(lead.id);
        existingCustomerIds.add(cust.customerId);
      }
    }

    int activeCount = 0;
    int upcomingCount = 0;
    int inactiveCount = 0;

    for (final c in mergedCustomers) {
      if (c.isSubscriptionActive) {
        activeCount++;
      } else if (c.hasUpcomingCall) {
        upcomingCount++;
      } else {
        inactiveCount++;
      }
    }

    final updatedCounts = {
      'all': mergedCustomers.length,
      'active': activeCount,
      'upcoming': upcomingCount,
      'inactive': inactiveCount,
    };

    return CustomersResponse(customers: mergedCustomers, counts: updatedCounts);
  }

  /// Synthetic LEAD-* cards: FINAL_CALL (Upcoming) or WON (Inactive). Real customers use API eligibility.
  static bool _isEligibleCustomerRecord(CustomerModel c) {
    final isSyntheticLeadCard = c.customerId.toUpperCase().startsWith('LEAD-');
    if (!isSyntheticLeadCard) return true;
    final bucket = c.customerStatus.toUpperCase();
    if (bucket == 'UPCOMING' || bucket == 'INACTIVE' || bucket == 'ACTIVE') return true;
    final status = (c.leadStatus ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final stage = (c.leadStageName ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    return status == 'WON' ||
        status == 'CONVERTED' ||
        status == 'FINAL_CALL' ||
        stage == 'WON' ||
        stage == 'FINAL_CALL' ||
        stage.contains('FINAL');
  }
}
