import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_claim_model.dart';
import '../services/employee_api_service.dart';

class EmployeeClaimState {
  final List<EmployeeClaimItem> claims;
  final bool isLoading;
  final String? errorMessage;

  const EmployeeClaimState({
    this.claims = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EmployeeClaimState copyWith({
    List<EmployeeClaimItem>? claims,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmployeeClaimState(
      claims: claims ?? this.claims,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EmployeeClaimNotifier extends Notifier<EmployeeClaimState> {
  @override
  EmployeeClaimState build() {
    return const EmployeeClaimState();
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  Future<void> loadClaims({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _service.getExpenseClaims(status: status);
      state = state.copyWith(claims: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> applyClaim({
    required String category,
    required double amount,
    required String description,
    String? claimDate,
    String? receiptUrl,
  }) async {
    try {
      await _service.applyExpenseClaim(
        category: category,
        amount: amount,
        description: description,
        claimDate: claimDate,
        receiptUrl: receiptUrl,
      );
      await loadClaims();
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final employeeClaimProvider =
    NotifierProvider<EmployeeClaimNotifier, EmployeeClaimState>(() {
      return EmployeeClaimNotifier();
    });
