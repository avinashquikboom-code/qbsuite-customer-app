import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/commission_model.dart';
import '../services/employee_api_service.dart';

class EmployeeCommissionState {
  final List<CommissionItem> items;
  final CommissionSummary summary;
  final CommissionEmployeeInfo? employee;
  final bool isLoading;
  final String? errorMessage;
  final String selectedStatus; // 'ALL' | 'APPROVED' | 'PAID' | 'PENDING'
  final int page;
  final int total;

  const EmployeeCommissionState({
    this.items = const [],
    required this.summary,
    this.employee,
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatus = 'ALL',
    this.page = 1,
    this.total = 0,
  });

  EmployeeCommissionState copyWith({
    List<CommissionItem>? items,
    CommissionSummary? summary,
    CommissionEmployeeInfo? employee,
    bool? isLoading,
    String? errorMessage,
    String? selectedStatus,
    int? page,
    int? total,
  }) {
    return EmployeeCommissionState(
      items: items ?? this.items,
      summary: summary ?? this.summary,
      employee: employee ?? this.employee,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      page: page ?? this.page,
      total: total ?? this.total,
    );
  }
}

class EmployeeCommissionNotifier extends Notifier<EmployeeCommissionState> {
  int _requestGeneration = 0;
  @override
  EmployeeCommissionState build() {
    ref.onDispose(() => _requestGeneration++);
    return EmployeeCommissionState(summary: CommissionSummary.empty());
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadCommissions({String? status}) async {
    final generation = ++_requestGeneration;
    final effectiveStatus = status ?? state.selectedStatus;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      selectedStatus: effectiveStatus,
    );

    try {
      final res = await _service.getMyCommissions(
        status: effectiveStatus == 'ALL' ? null : effectiveStatus,
      );
      if (generation != _requestGeneration) return;

      state = state.copyWith(
        items: res.items,
        summary: res.summary,
        employee: res.employee,
        isLoading: false,
        page: res.page,
        total: res.total,
      );
    } catch (e) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.items.length >= state.total) return;
    final generation = _requestGeneration;
    final filter = state.selectedStatus;
    state = state.copyWith(isLoading: true);
    try {
      final res = await _service.getMyCommissions(
        status: filter == 'ALL' ? null : filter,
        page: state.page + 1,
      );
      if (generation != _requestGeneration) return;
      final byId = {
        for (final item in [...state.items, ...res.items]) item.id: item,
      };
      state = state.copyWith(
        items: byId.values.toList(),
        page: res.page,
        total: res.total,
        summary: res.summary,
        isLoading: false,
      );
    } catch (e) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> setStatusFilter(String status) async {
    if (state.selectedStatus == status) return;
    await loadCommissions(status: status);
  }

  Future<void> refresh() async {
    await loadCommissions();
  }
}

final employeeCommissionProvider =
    NotifierProvider<EmployeeCommissionNotifier, EmployeeCommissionState>(
      EmployeeCommissionNotifier.new,
    );
