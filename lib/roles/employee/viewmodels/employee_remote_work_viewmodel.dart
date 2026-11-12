import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_leave_model.dart';
import '../services/employee_api_service.dart';

class RemoteWorkState {
  final bool isLoading;
  final bool isSubmitting;
  final List<RemoteRequestItem> requests;
  final String? errorMessage;
  final String? successMessage;

  const RemoteWorkState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.requests = const [],
    this.errorMessage,
    this.successMessage,
  });

  RemoteWorkState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<RemoteRequestItem>? requests,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return RemoteWorkState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      requests: requests ?? this.requests,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class EmployeeRemoteWorkNotifier extends Notifier<RemoteWorkState> {
  @override
  RemoteWorkState build() {
    Future.microtask(() => loadRemoteRequests());
    return const RemoteWorkState(isLoading: true);
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadRemoteRequests() async {
    try {
      state = state.copyWith(isLoading: true, clearMessages: true);
      final list = await _service.getRemoteRequests();
      state = state.copyWith(
        isLoading: false,
        requests: list,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('[REMOTE_WORK_NOTIFIER] loadRemoteRequests error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to load remote work requests: ${e.toString().replaceFirst('Exception: ', '')}',
      );
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

      await loadRemoteRequests();
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

final employeeRemoteWorkProvider =
    NotifierProvider<EmployeeRemoteWorkNotifier, RemoteWorkState>(
      EmployeeRemoteWorkNotifier.new,
    );
