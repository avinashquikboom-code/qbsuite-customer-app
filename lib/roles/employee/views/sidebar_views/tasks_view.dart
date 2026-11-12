import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/empty_state_card.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_calendar_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class TasksView extends ConsumerStatefulWidget {
  const TasksView({super.key});

  @override
  ConsumerState<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends ConsumerState<TasksView> {
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';
  bool _isLoading = false;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchMyTasks();
  }

  String? _loadError;
  int _requestVersion = 0;

  List<dynamic> _readTaskList(dynamic data) {
    if (data is List) return data;
    if (data is! Map) throw const FormatException('Invalid task response');
    for (final key in const ['data', 'items', 'tasks']) {
      final v = data[key];
      if (v is List) return v;
      if (v is Map) {
        return _readTaskList(v);
      }
    }
    throw const FormatException('Missing task list in response');
  }

  Future<void> _fetchMyTasks() async {
    final requestVersion = ++_requestVersion;
    setState(() => _isLoading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(
            '/mobile/tasks',
            queryParameters: {
              if (_selectedStatus != 'ALL') 'status': _selectedStatus,
              if (_selectedPriority != 'ALL') 'priority': _selectedPriority,
            },
          );

      final items = _readTaskList(res.data);
      debugPrint(
        '[TasksView] status=${res.statusCode} rawCount=${items.length}',
      );

      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _loadError = null;
        _tasks = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      debugPrint('[TasksView] _fetchMyTasks error: $e');
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loadError = 'Unable to load tasks. Pull to retry.');
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'URGENT':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.info;
      case 'LOW':
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.success;
      case 'UNDER_REVIEW':
      case 'SUBMITTED':
        return AppColors.warning;
      case 'REJECTED':
        return AppColors.error;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'PENDING':
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _startTask(int id) async {
    try {
      await ref.read(apiClientProvider).post('/mobile/tasks/$id/start');
      if (mounted) {
        AppToast.success(context, 'Task started! Work in progress.');
      }
      refreshEmployeeCalendarProviders(ref);
      _fetchMyTasks();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to start task: $e');
      }
    }
  }

  void _showSubmitProofDialog(Map<String, dynamic> task) {
    final photoUrlController = TextEditingController();
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Submit Task Proof',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚠️ Photo proof is mandatory before completing task.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Photo URL / Upload Link *',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: photoUrlController,
                decoration: InputDecoration(
                  hintText: 'https://...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Completion Comments',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Work completed as per checklist...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (photoUrlController.text.trim().isEmpty) {
                AppToast.error(context, 'Completion proof photo is required.');
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(apiClientProvider)
                    .post(
                      '/mobile/tasks/${task['id']}/proof',
                      data: {
                        'fileUrl': photoUrlController.text.trim(),
                        'comment': commentController.text.trim(),
                      },
                    );
                if (mounted) {
                  AppToast.success(context, 'Proof submitted for HR review!');
                }
                refreshEmployeeCalendarProviders(ref);
                _fetchMyTasks();
              } catch (e) {
                if (mounted) {
                  AppToast.error(context, 'Failed to submit proof: $e');
                }
              }
            },
            child: Text(
              'Submit for Review',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEditTasks = ref
        .watch(permissionManagerProvider)
        .canEdit(AppModule.tasks);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'My Assigned Tasks',
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line),
            onPressed: _fetchMyTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatusFilter('All', 'ALL'),
                      _buildStatusFilter('Pending', 'PENDING'),
                      _buildStatusFilter('In Progress', 'IN_PROGRESS'),
                      _buildStatusFilter('Under Review', 'UNDER_REVIEW'),
                      _buildStatusFilter('Completed', 'COMPLETED'),
                      _buildStatusFilter('Rejected', 'REJECTED'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPriorityFilter('All Priorities', 'ALL'),
                      _buildPriorityFilter('🔴 URGENT', 'URGENT'),
                      _buildPriorityFilter('🟠 HIGH', 'HIGH'),
                      _buildPriorityFilter('🔵 MEDIUM', 'MEDIUM'),
                      _buildPriorityFilter('⚪ LOW', 'LOW'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _isLoading
                ? const SkeletonList(count: 4)
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _fetchMyTasks,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _tasks.isEmpty
                ? const Center(
                    child: EmptyStateCard(
                      title: 'No Tasks Found',
                      description:
                          'You have no assigned tasks matching current filters.',
                      icon: Remix.task_line,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchMyTasks,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return _buildTaskCard(task, canEditTasks);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(String label, String value) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: GoogleFonts.outfit(
          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedStatus = value);
            _fetchMyTasks();
          }
        },
      ),
    );
  }

  Widget _buildPriorityFilter(String label, String value) {
    final isSelected = _selectedPriority == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: GoogleFonts.outfit(
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 10,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedPriority = value);
            _fetchMyTasks();
          }
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool canEditTasks) {
    final priority = (task['priority'] ?? 'MEDIUM').toString();
    final status = (task['status'] ?? 'PENDING').toString();
    final isUrgent = priority == 'URGENT';
    final isRejected = status == 'REJECTED';
    final isCompleted = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS';
    final isPending = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? AppColors.error.withValues(alpha: 0.5)
              : isRejected
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
          width: isUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(
                          priority,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priority,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(priority),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task['taskNumber'] ?? 'TSK-${task['id']}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'UNDER_REVIEW' ? 'Awaiting Review' : status,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task['title'] ?? 'Untitled Task',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            if (task['description'] != null &&
                (task['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task['description'],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isRejected && task['rejectionReason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Remix.error_warning_line,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${task['rejectionReason']}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Remix.time_line,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${task['dueTime'] ?? ''} ${task['dueDate'] ?? ''}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Action Buttons
                if (canEditTasks) ...[
                  if (isPending || isRejected)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Remix.play_line,
                        size: 13,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Start Task',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => _startTask(task['id'] as int),
                    )
                  else if (isInProgress)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Remix.camera_line,
                        size: 13,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Upload Proof',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => _showSubmitProofDialog(task),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
