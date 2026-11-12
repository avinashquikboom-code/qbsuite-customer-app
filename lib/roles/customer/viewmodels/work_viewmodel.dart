import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/customer/models/work_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';

final workProjectsProvider =
    NotifierProvider<WorkViewModel, List<WorkProjectModel>>(() {
      return WorkViewModel();
    });

class WorkViewModel extends Notifier<List<WorkProjectModel>> {
  @override
  List<WorkProjectModel> build() {
    final customerNameAsync = ref.watch(currentCustomerNameProvider);
    final customerName =
        (customerNameAsync.asData?.value ?? customerNameAsync.value ?? '')
            .trim()
            .toLowerCase();
    if (customerName.isEmpty) return [];
    return const [];
  }

  void addProject(WorkProjectModel project) {
    state = [project, ...state];
  }

  void updateProject(WorkProjectModel project) {
    state = [
      for (final p in state)
        if (p.id == project.id) project else p,
    ];
  }

  void deleteProject(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateStatus(String id, String status) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            status: status,
            progress: status == 'COMPLETED' ? 1.0 : p.progress,
          )
        else
          p,
    ];
  }

  void updateProgress(String id, double progress) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            progress: progress.clamp(0.0, 1.0),
            status: progress >= 1.0
                ? 'COMPLETED'
                : (progress > 0 ? 'ACTIVE' : 'UPCOMING'),
          )
        else
          p,
    ];
  }

  void toggleMilestone(String projectId, String milestoneId) {
    state = [
      for (final p in state)
        if (p.id == projectId) ...[
          (() {
            final updatedMilestones = p.milestones.map((m) {
              if (m.id == milestoneId) {
                return m.copyWith(isCompleted: !m.isCompleted);
              }
              return m;
            }).toList();

            final completedCount = updatedMilestones
                .where((m) => m.isCompleted)
                .length;
            final newProgress = updatedMilestones.isEmpty
                ? p.progress
                : completedCount / updatedMilestones.length;

            return p.copyWith(
              milestones: updatedMilestones,
              progress: newProgress,
              status: newProgress >= 1.0
                  ? 'COMPLETED'
                  : (newProgress > 0 ? 'ACTIVE' : p.status),
            );
          })(),
        ] else
          p,
    ];
  }

  String get nextProjectNo {
    final count = state.length + 1;
    return 'PRJ-2026-${count.toString().padLeft(3, '0')}';
  }
}
