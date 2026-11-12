import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_leave_model.dart';
import '../services/employee_api_service.dart';

class LeaveState {
  final bool isLoading;
  final bool isSubmitting;
  final List<LeaveBalanceItem> balances;
  final List<LeaveRequestItem> leaveRequests;
  final List<RemoteRequestItem> remoteRequests;
  final String? errorMessage;
  final String? successMessage;

  const LeaveState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.balances = const [],
    this.leaveRequests = const [],
    this.remoteRequests = const [],
    this.errorMessage,
    this.successMessage,
  });

  LeaveState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<LeaveBalanceItem>? balances,
    List<LeaveRequestItem>? leaveRequests,
    List<RemoteRequestItem>? remoteRequests,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      balances: balances ?? this.balances,
      leaveRequests: leaveRequests ?? this.leaveRequests,
      remoteRequests: remoteRequests ?? this.remoteRequests,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class EmployeeLeaveNotifier extends Notifier<LeaveState> {
  @override
  LeaveState build() {
    Future.microtask(() => loadAll());
    return const LeaveState(isLoading: true);
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadAll() async {
    try {
      state = state.copyWith(isLoading: true, clearMessages: true);
      final balances = await _service.getLeaveBalances().catchError((e) {
        debugPrint('[LEAVE_NOTIFIER] getLeaveBalances error: $e');
        return <LeaveBalanceItem>[];
      });
      final leaves = await _service.getLeaveRequests();
      final remote = await _service.getRemoteRequests().catchError((e) {
        debugPrint('[LEAVE_NOTIFIER] getRemoteRequests error: $e');
        return <RemoteRequestItem>[];
      });

      state = state.copyWith(
        isLoading: false,
        balances: balances,
        leaveRequests: leaves,
        remoteRequests: remote,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('[LEAVE_NOTIFIER] loadAll error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to load leaves: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<bool> applyLeave({
    required int leaveTypeId,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    try {
      state = state.copyWith(isSubmitting: true, clearMessages: true);
      await _service.applyLeave(
        leaveTypeId: leaveTypeId,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
      );

      await loadAll();
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Leave application submitted for approval.',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSubmitting: false, errorMessage: cleanMsg);
      return false;
    }
  }

  Future<bool> applyRemoteWork({
    required String fromDate,
    required String toDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    try {
      state = state.copyWith(isSubmitting: true, clearMessages: true);
      await _service.applyRemoteWork(
        fromDate: fromDate,
        toDate: toDate,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );

      await loadAll();
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Work from home request submitted for approval.',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSubmitting: false, errorMessage: cleanMsg);
      return false;
    }
  }
}

final employeeLeaveProvider =
    NotifierProvider<EmployeeLeaveNotifier, LeaveState>(
      EmployeeLeaveNotifier.new,
    );
