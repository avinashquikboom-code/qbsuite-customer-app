import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_payroll_model.dart';
import '../services/employee_api_service.dart';

class PayrollState {
  final bool isLoading;
  final List<SalarySlipItem> slips;
  final SalarySlipItem? latestSlip;
  final String? errorMessage;

  const PayrollState({
    this.isLoading = false,
    this.slips = const [],
    this.latestSlip,
    this.errorMessage,
  });

  PayrollState copyWith({
    bool? isLoading,
    List<SalarySlipItem>? slips,
    SalarySlipItem? latestSlip,
    String? errorMessage,
  }) {
    return PayrollState(
      isLoading: isLoading ?? this.isLoading,
      slips: slips ?? this.slips,
      latestSlip: latestSlip ?? this.latestSlip,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EmployeePayrollNotifier extends Notifier<PayrollState> {
  @override
  PayrollState build() {
    Future.microtask(() => loadSalarySlips());
    return const PayrollState(isLoading: true);
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadSalarySlips() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final slips = await _service.getSalarySlips();
      state = state.copyWith(
        isLoading: false,
        slips: slips,
        latestSlip: slips.isNotEmpty ? slips.first : null,
        errorMessage: null,
      );
    } catch (e) {
      debugPrint('[PAYROLL_NOTIFIER] loadSalarySlips error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load payslips',
      );
    }
  }
}

final employeePayrollProvider =
    NotifierProvider<EmployeePayrollNotifier, PayrollState>(
      EmployeePayrollNotifier.new,
    );
