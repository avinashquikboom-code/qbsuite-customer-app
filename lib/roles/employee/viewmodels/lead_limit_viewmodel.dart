import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead_limit_model.dart';
import '../services/employee_api_service.dart';

final leadLimitProvider =
    AsyncNotifierProvider<LeadLimitViewModel, EmployeeLeadLimitModel>(() {
      return LeadLimitViewModel();
    });

class LeadLimitViewModel extends AsyncNotifier<EmployeeLeadLimitModel> {
  @override
  Future<EmployeeLeadLimitModel> build() async {
    return _fetch();
  }

  Future<EmployeeLeadLimitModel> _fetch() async {
    final api = ref.read(employeeApiServiceProvider);
    return api.getMyLeadLimit();
  }

  Future<void> fetchLimits() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }
}
