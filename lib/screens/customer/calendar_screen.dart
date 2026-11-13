import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/subscription_service.dart';

class CustomerCalendarScreen extends StatefulWidget {
  final Dio? dio;
  final String? customerId;
  const CustomerCalendarScreen({super.key, this.dio, this.customerId});

  @override
  State<CustomerCalendarScreen> createState() => _CustomerCalendarScreenState();
}

class _CustomerCalendarScreenState extends State<CustomerCalendarScreen> {
  late DateTime selectedDate;
  late SubscriptionService subscriptionService;
  List<ActivitySchedule> activities = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    subscriptionService = SubscriptionService(
      dio: widget.dio ?? ApiClient().dio,
    );
    loadCalendar();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> loadCalendar() async {
    setState(() => isLoading = true);

    try {
      final dateStr = selectedDate.toIso8601String().split('T')[0];
      final response = await subscriptionService.getCalendarSchedule(
        dateStr,
        customerId: widget.customerId,
      );

      final rawList =
          response['activities'] ?? response['data'] ?? response['schedules'];
      setState(() {
        if (rawList is List) {
          final parsed = rawList
              .whereType<Map<String, dynamic>>()
              .map((a) => ActivitySchedule.fromJson(a))
              .toList();
          final seen = <int>{};
          activities = parsed.where((a) => seen.add(a.id)).toList();
        } else {
          activities = [];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading calendar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> markActivityComplete(int id) async {
    try {
      await subscriptionService.completeActivity(id);
      await loadCalendar(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity marked complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: const Color(0xFF0F766E),
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Date: $dateStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Change Date'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                      loadCalendar();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Activities List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : activities.isEmpty
                ? const Center(
                    child: Text('No activities scheduled for this date'),
                  )
                : ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      final isDone =
                          activity.status.toLowerCase() == 'completed';
                      return ListTile(
                        key: ValueKey('cust_sched_${activity.id}'),
                        leading: Icon(
                          isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isDone ? Colors.green : Colors.grey,
                        ),
                        title: Text(activity.activity),
                        subtitle: Text(activity.time ?? 'No time set'),
                        trailing: !isDone
                            ? IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  markActivityComplete(activity.id);
                                },
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ActivitySchedule {
  final int id;
  final String activity;
  final String status;
  final String? time;

  ActivitySchedule({
    required this.id,
    required this.activity,
    required this.status,
    this.time,
  });

  factory ActivitySchedule.fromJson(Map<String, dynamic> json) {
    return ActivitySchedule(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      activity:
          json['activity']?.toString() ??
          json['title']?.toString() ??
          'Activity',
      status: json['status']?.toString() ?? 'pending',
      time: json['time']?.toString() ?? json['scheduledTime']?.toString(),
    );
  }
}
