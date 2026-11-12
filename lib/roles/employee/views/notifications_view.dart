import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_theme.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import '../viewmodels/employee_notification_viewmodel.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/widgets/common_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';





class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  static const _green = Color(0xFF22C55E);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF718096);
  static const _line = Color(0xFFE2E8F0);
  String filter = 'All';
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeeNotificationProvider.notifier).loadNotifications();
    });
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 240) {
        ref.read(employeeNotificationProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  bool _unread(Map<String, dynamic> item) => item['isRead'] == false || item['isUnread'] == true;

  String _bucket(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString().toUpperCase();
    if (type.contains('LEAD')) return 'Leads';
    if (type.contains('LEAVE') || type.contains('REMOTE') || type.contains('CLAIM') || type.contains('REQUEST')) return 'Requests';
    return 'Updates';
  }

  IconData _getNotificationIcon(dynamic type) {
    if (type == null) return Remix.notification_3_line;
    final str = type.toString().trim().toUpperCase();
    switch (str) {
      case 'ATTENDANCE':
        return Remix.fingerprint_line;
      case 'LEAD':
        return Remix.user_add_line;
      case 'PAYROLL':
        return Remix.receipt_line;
      case 'TASK':
        return Remix.task_line;
      case 'WORK_COMPLETED':
      case 'LEVEL_APPROVED':
        return Remix.checkbox_circle_line;
      case 'WORK_SUBMITTED':
        return Remix.file_check_line;
      case 'PLAN_PURCHASE_SUCCESS':
      case 'PLAN_ACTIVATED':
      case 'SUBSCRIPTION':
        return Remix.vip_diamond_line;
      case 'OFFER':
      case 'ADMIN_OFFER':
        return Remix.gift_2_line;
      case 'WELCOME':
        return Remix.user_heart_line;
      default:
        return Remix.notification_3_line;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(employeeNotificationProvider);
    final loginState = ref.watch(loginStateProvider);
    if (loginState.role == UserRole.customer) {
      final perms = ref.watch(permissionManagerProvider);
      if (!perms.customerCan('CUSTOMER_NOTIFICATIONS', 'VIEW')) {
        return const PermissionGuardedView(
          moduleKey: 'CUSTOMER_NOTIFICATIONS',
          moduleTitle: 'Notifications',
          child: SizedBox.shrink(),
        );
      }
    }
    final items = notificationState.notifications;
    final visible = items.where((item) {
      if (filter == 'Unread') return _unread(item);
      if (filter == 'All') return true;
      return _bucket(item) == filter;
    }).toList();
    final counts = {
      'All': items.length,
      'Unread': items.where(_unread).length,
      'Leads': items.where((item) => _bucket(item) == 'Leads').length,
      'Updates': items.where((item) => _bucket(item) == 'Updates').length,
      'Requests': items.where((item) => _bucket(item) == 'Requests').length,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppAppBar(
        title: AppBarTitles.notifications,
        showBackButton: true,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => ref
                  .read(employeeNotificationProvider.notifier)
                  .markAllAsRead(),
              child: Text(
                'Mark all read',
                style: GoogleFonts.outfit(
                  color: _green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: notificationState.isLoading
          ? _buildNotificationSkeleton()
          : notificationState.errorMessage != null && items.isEmpty
          ? _buildErrorState(notificationState.errorMessage!)
          : Column(children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(children: [
                  for (final label in ['All', 'Unread', 'Leads', 'Updates', 'Requests'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: filter == label ? _green : Colors.white,
                        shape: StadiumBorder(side: BorderSide(color: filter == label ? _green : _line)),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => setState(() => filter = label),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Text('$label ${counts[label] ?? 0}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: filter == label ? Colors.white : _ink)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _buildEmptyState(loginState.role)
                    : RefreshIndicator(
                        onRefresh: () => ref.read(employeeNotificationProvider.notifier).loadNotifications(),
                        child: ListView.separated(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: visible.length + (notificationState.loadingMore ? 1 : 0),
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= visible.length) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
                            return _buildNotificationItem(context, visible[index]);
                          },
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _buildNotificationSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, _) => const SkeletonNotificationTile(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Remix.error_warning_line,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load notifications',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(employeeNotificationProvider.notifier)
                  .loadNotifications(),
              icon: const Icon(Remix.refresh_line, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(UserRole? role) {
    String subtitle;
    if (role == UserRole.customer) {
      subtitle =
          'You are all caught up! Updates about your campaigns, plans, and deliverables will appear here.';
    } else if (role == UserRole.companyAdmin) {
      subtitle =
          'You are all caught up! Updates about your workforce, visits, and approvals will appear here.';
    } else {
      subtitle =
          'You are all caught up! Updates about attendance, leaves, and tasks will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Remix.notification_off_line,
              size: 48,
              color: AppColors.textPlaceholder,
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications available',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatNotificationDate(dynamic rawDate) {
    if (rawDate == null) return 'Recently';
    final str = rawDate.toString().trim();
    if (str.isEmpty || str == 'Recently') return 'Recently';

    DateTime? dt;
    try {
      dt = DateTime.tryParse(str)?.toLocal();
    } catch (_) {}

    if (dt == null) {
      return str;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;

    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour12:$minuteStr $period';
  }

  Widget _buildNotificationItem(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final isUnread = item['isRead'] == false || item['isUnread'] == true;
    final title = (item['title'] ?? 'Notification').toString().trim();
    final message = (item['message'] ?? item['body'] ?? '').toString().trim();
    final rawTime = item['createdAt'] ?? item['time'];
    final formattedTime = _formatNotificationDate(rawTime);
    final icon = item['icon'] is IconData
        ? item['icon'] as IconData
        : _getNotificationIcon(item['type']);

    final data = item['data'] is Map ? item['data'] as Map : null;
    final imageUrl = (item['imageUrl'] ?? data?['imageUrl'])?.toString().trim();
    final rawShowCta = item['showCta'] ?? data?['showCta'];
    final showCta = rawShowCta == true || rawShowCta == 'true';
    final ctaText =
        (item['ctaText'] ?? data?['ctaText'])?.toString().trim() ?? '';
    final ctaActionType = (item['ctaActionType'] ?? data?['ctaActionType'])
        ?.toString()
        .trim();
    final ctaActionValue =
        (item['ctaActionValue'] ??
                data?['ctaActionValue'] ??
                data?['deepLink'] ??
                data?['route'])
            ?.toString()
            .trim();

    return InkWell(
      onTap: () {
        if (item['id'] != null) {
          ref
              .read(employeeNotificationProvider.notifier)
              .markAsRead(item['id'].toString());
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? _green.withValues(alpha: 0.35)
                : _line,
          ),
          boxShadow: [
            if (isUnread)
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _AnimatedNotificationIcon(icon: icon, isUnread: isUnread),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formattedTime,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B), // Slate 500
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              await CommonConfirmDialog.show(
                                context,
                                title: 'Delete Notification',
                                message:
                                    'Are you sure you want to delete this notification?',
                                confirmLabel: 'Delete',
                                isDestructive: true,
                                onConfirm: () async {
                                  if (item['id'] != null) {
                                    try {
                                      await ref
                                          .read(
                                            employeeNotificationProvider
                                                .notifier,
                                          )
                                          .deleteNotification(
                                            item['id'].toString(),
                                          );
                                      if (context.mounted) {
                                        AppToast.success(
                                          context,
                                          'Notification deleted',
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        AppToast.error(
                                          context,
                                          'Failed to delete notification',
                                        );
                                      }
                                    }
                                  }
                                },
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Remix.delete_bin_line,
                                size: 16,
                                color: AppColors.textPlaceholder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Notification Title
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),

                  // Notification Message / Body
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF475569), // Slate 600
                        height: 1.45,
                      ),
                    ),
                  ],

                  // Rich Promotional Image
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _previewImage(context, imageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                          errorWidget: (context, url, error) => Container(
                            height: 88,
                            alignment: Alignment.center,
                            color: const Color(0xFFF7F9FA),
                            child: Text('Image could not be loaded', style: GoogleFonts.outfit(color: _muted, fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Customizable CTA Action Button
                  if (showCta && ctaText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _executeAction(
                          context,
                          ctaActionType,
                          ctaActionValue,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1AA14D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          ctaText,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
        ),
      ),
    );
  }

  void _previewImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _executeAction(
    BuildContext context,
    String? actionType,
    String? actionValue,
  ) {
    if (actionValue == null || actionValue.trim().isEmpty) return;
    final trimmedVal = actionValue.trim();
    final isWeb =
        (actionType ?? '').toUpperCase() == 'WEB_URL' ||
        trimmedVal.startsWith('http://') ||
        trimmedVal.startsWith('https://');

    if (isWeb) {
      final uri = Uri.tryParse(trimmedVal);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
          debugPrint('Error launching URL: $e');
          return false;
        });
      }
      return;
    }

    var route = trimmedVal;
    if (route.startsWith('app://')) {
      route = route.substring(6);
    }
    if (!route.startsWith('/')) {
      route = '/$route';
    }

    if (route == '/plans' || route == '/customer/plans') {
      
      return;
    }
    if (route == '/orders' || route == '/customer/orders') {
      
      return;
    }
    if (route == '/leads' || route == '/employee/leads') {
      
      return;
    }
    if (route == '/customer/work-requests' ||
        route == '/work-requests' ||
        route == '/customer/work') {
      
      return;
    }

    try {
      Navigator.of(context).pushNamed(route);
    } catch (_) {
      debugPrint('Route not recognized: $route');
    }
  }
}

/// Lightweight, self-contained animated notification icon.
///
/// Unread: Continuously rings with a smooth, premium bell swing around [Alignment.topCenter].
/// Read: Static icon with zero ticker/controller overhead.
class _AnimatedNotificationIcon extends StatefulWidget {
  final IconData icon;
  final bool isUnread;

  const _AnimatedNotificationIcon({required this.icon, required this.isUnread});

  @override
  State<_AnimatedNotificationIcon> createState() =>
      _AnimatedNotificationIconState();
}

class _AnimatedNotificationIconState extends State<_AnimatedNotificationIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _swingAnimation;

  // Bell swing keyframe angles in radians: ~12°, ~8°, ~4°
  static const _deg12 = 12.0 * math.pi / 180.0;
  static const _deg8 = 8.0 * math.pi / 180.0;
  static const _deg4 = 4.0 * math.pi / 180.0;

  @override
  void initState() {
    super.initState();
    if (widget.isUnread) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _swingAnimation ??= TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -_deg12,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg12,
          end: _deg12,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _deg12,
          end: -_deg8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg8,
          end: _deg8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _deg8,
          end: -_deg4,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg4,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 9,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 10, // brief rest at center before repeating
      ),
    ]).animate(_controller!);

    _controller!.repeat();
  }

  void _stopAnimation() {
    _controller?.stop();
    _controller?.reset();
  }

  @override
  void didUpdateWidget(covariant _AnimatedNotificationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnread != oldWidget.isUnread) {
      if (widget.isUnread) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isUnread
        ? AppTheme.primaryColor.withValues(alpha: 0.1)
        : const Color(0xFFF1F5F9);
    final iconColor = widget.isUnread
        ? AppTheme.primaryColor
        : const Color(0xFF94A3B8);

    Widget iconWidget = Icon(widget.icon, color: iconColor, size: 20);

    if (widget.isUnread && _controller != null && _swingAnimation != null) {
      iconWidget = AnimatedBuilder(
        animation: _swingAnimation!,
        builder: (context, child) {
          return Transform.rotate(
            alignment: Alignment.topCenter,
            angle: _swingAnimation!.value,
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: iconWidget,
    );
  }
}
