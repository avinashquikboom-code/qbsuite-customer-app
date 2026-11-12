// Dummy data for UI‑only mode Dashboard
// This file provides static demo data for the Dashboard UI.

class LeadStats {
  final int total;
  final int newToday;
  const LeadStats({required this.total, required this.newToday});
}

class VisitStats {
  final int today;
  final int upcoming;
  final int completed;
  const VisitStats({
    required this.today,
    required this.upcoming,
    required this.completed,
  });
}

class FollowUpStats {
  final int today;
  final int upcoming;
  final int overdue;
  const FollowUpStats({
    required this.today,
    required this.upcoming,
    required this.overdue,
  });
}

class DataCaptureStats {
  final int capturedToday;
  final int convertedLeads;
  const DataCaptureStats({
    required this.capturedToday,
    required this.convertedLeads,
  });
}

class ProposalStats {
  final int active;
  final int sentToday;
  final int accepted;
  const ProposalStats({
    required this.active,
    required this.sentToday,
    required this.accepted,
  });
}

enum ActivityType {
  leadCreated,
  leadUpdated,
  dataCaptured,
  leadFromDataCapture,
  followUpScheduled,
  followUpCompleted,
  visitScheduled,
  visitStarted,
  visitCompleted,
  proposalGenerated,
  proposalSent,
  proposalAccepted,
  paymentReceived,
  workStarted,
}

class ActivityItem {
  final ActivityType type;
  final String title;
  final String subtitle; // e.g., lead/company name
  final String timestamp; // e.g., "10 min ago"
  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class DashboardDemoRepository {
  const DashboardDemoRepository();

  LeadStats leadStats() => const LeadStats(total: 24, newToday: 5);
  VisitStats visitStats() =>
      const VisitStats(today: 4, upcoming: 2, completed: 2);
  FollowUpStats followUpStats() =>
      const FollowUpStats(today: 6, upcoming: 2, overdue: 1);
  DataCaptureStats dataCaptureStats() =>
      const DataCaptureStats(capturedToday: 18, convertedLeads: 7);
  ProposalStats proposalStats() =>
      const ProposalStats(active: 5, sentToday: 2, accepted: 1);

  List<ActivityItem> recentActivities() => const [
    ActivityItem(
      type: ActivityType.leadCreated,
      title: "Lead Created",
      subtitle: "ABC Traders",
      timestamp: "10 min ago",
    ),
    ActivityItem(
      type: ActivityType.followUpCompleted,
      title: "Follow‑up Completed",
      subtitle: "XYZ Enterprises",
      timestamp: "45 min ago",
    ),
    ActivityItem(
      type: ActivityType.visitCompleted,
      title: "Visit Completed",
      subtitle: "Global Solutions",
      timestamp: "2 hrs ago",
    ),
    ActivityItem(
      type: ActivityType.proposalGenerated,
      title: "Proposal Generated",
      subtitle: "ABC Industries",
      timestamp: "3 hrs ago",
    ),
    ActivityItem(
      type: ActivityType.dataCaptured,
      title: "Data Captured",
      subtitle: "Sunrise Traders",
      timestamp: "4 hrs ago",
    ),
  ];

  List<ActivityItem> upcomingActivities() => const [
    ActivityItem(
      type: ActivityType.followUpScheduled,
      title: "Follow‑up",
      subtitle: "ABC Traders",
      timestamp: "Today • 3:30 PM",
    ),
    ActivityItem(
      type: ActivityType.visitScheduled,
      title: "Visit",
      subtitle: "XYZ Enterprises",
      timestamp: "Tomorrow • 11:00 AM",
    ),
  ];
}
