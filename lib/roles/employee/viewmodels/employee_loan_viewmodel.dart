import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_loan_model.dart';
import '../services/employee_api_service.dart';

class EmployeeLoanState {
  final List<EmployeeLoanItem> loans;
  final bool isLoading;
  final String? errorMessage;

  const EmployeeLoanState({
    this.loans = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EmployeeLoanState copyWith({
    List<EmployeeLoanItem>? loans,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmployeeLoanState(
      loans: loans ?? this.loans,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EmployeeLoanNotifier extends Notifier<EmployeeLoanState> {
  @override
  EmployeeLoanState build() {
    return const EmployeeLoanState();
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadLoans({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _service.getLoans(status: status);
      state = state.copyWith(loans: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> applyLoan({
    required double loanAmount,
    required String reason,
    int termMonths = 12,
  }) async {
    try {
      await _service.applyLoan(
        loanAmount: loanAmount,
        reason: reason,
        termMonths: termMonths,
      );
      await loadLoans();
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final employeeLoanProvider =
    NotifierProvider<EmployeeLoanNotifier, EmployeeLoanState>(() {
      return EmployeeLoanNotifier();
    });
