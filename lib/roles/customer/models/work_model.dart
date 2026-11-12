/// Work Execution / Project Delivery Model for managing client onboarding and implementation projects.
class WorkProjectModel {
  final String id;
  final String projectNo;
  final String customerId;
  final String clientName;
  final String projectName;
  final String description;
  final String assignedTeam;
  final String leadPerson;
  final String kickoffDate;
  final String targetCompletion;
  final double progress; // 0.0 to 1.0
  final String status; // ACTIVE, UPCOMING, COMPLETED, ON_HOLD
  final List<WorkMilestoneModel> milestones;
  final String? notes;
  final String createdAt;

  const WorkProjectModel({
    required this.id,
    required this.projectNo,
    this.customerId = '',
    required this.clientName,
    required this.projectName,
    this.description = '',
    required this.assignedTeam,
    this.leadPerson = 'Team Lead',
    required this.kickoffDate,
    required this.targetCompletion,
    required this.progress,
    required this.status,
    required this.milestones,
    this.notes,
    required this.createdAt,
  });

  int get progressPercent => (progress * 100).round();

  int get completedMilestonesCount =>
      milestones.where((m) => m.isCompleted).length;

  String get milestoneProgressLabel => milestones.isEmpty
      ? '0/0'
      : '$completedMilestonesCount/${milestones.length}';

  WorkProjectModel copyWith({
    String? id,
    String? projectNo,
    String? customerId,
    String? clientName,
    String? projectName,
    String? description,
    String? assignedTeam,
    String? leadPerson,
    String? kickoffDate,
    String? targetCompletion,
    double? progress,
    String? status,
    List<WorkMilestoneModel>? milestones,
    String? notes,
    String? createdAt,
  }) {
    return WorkProjectModel(
      id: id ?? this.id,
      projectNo: projectNo ?? this.projectNo,
      customerId: customerId ?? this.customerId,
      clientName: clientName ?? this.clientName,
      projectName: projectName ?? this.projectName,
      description: description ?? this.description,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      leadPerson: leadPerson ?? this.leadPerson,
      kickoffDate: kickoffDate ?? this.kickoffDate,
      targetCompletion: targetCompletion ?? this.targetCompletion,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      milestones: milestones ?? this.milestones,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkMilestoneModel {
  final String id;
  final String title;
  final bool isCompleted;
  final String dueDate;

  const WorkMilestoneModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate = '',
  });

  WorkMilestoneModel copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? dueDate,
  }) {
    return WorkMilestoneModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
