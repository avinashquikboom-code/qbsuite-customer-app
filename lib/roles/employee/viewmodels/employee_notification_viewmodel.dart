import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/employee_api_service.dart';

class NotificationState {
  final bool isLoading;
  final bool loadingMore;
  final bool hasMore;
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationState({
    this.isLoading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  NotificationState copyWith({
    bool? isLoading,
    bool? loadingMore,
    bool? hasMore,
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EmployeeNotificationNotifier extends Notifier<NotificationState> {
  int _page = 1;

  @override
  NotificationState build() {
    Future.microtask(() => loadNotifications());
    return const NotificationState(isLoading: true);
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  int _unread(List<Map<String, dynamic>> list) => list.where((n) => n['isRead'] == false || n['isUnread'] == true).length;

  Future<void> loadNotifications() async {
    try {
      state = state.copyWith(isLoading: true);
      _page = 1;
      final list = await _service.getNotifications(page: 1);
      state = state.copyWith(
        isLoading: false,
        loadingMore: false,
        hasMore: list.length >= 30,
        notifications: list,
        unreadCount: _unread(list),
      );
    } catch (e) {
      debugPrint('[NOTIFICATION_NOTIFIER] loadNotifications error: $e');
      state = state.copyWith(isLoading: false, loadingMore: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = _page + 1;
      final list = await _service.getNotifications(page: nextPage);
      _page = nextPage;
      final merged = [...state.notifications, ...list];
      state = state.copyWith(
        loadingMore: false,
        hasMore: list.length >= 30,
        notifications: merged,
        unreadCount: _unread(merged),
      );
    } catch (e) {
      debugPrint('[NOTIFICATION_NOTIFIER] loadMore error: $e');
      state = state.copyWith(loadingMore: false, hasMore: false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markNotificationAsRead(id);
      final updated = state.notifications.map((n) {
        if (n['id'].toString() == id) {
          final copy = Map<String, dynamic>.from(n);
          copy['isRead'] = true;
          copy['isUnread'] = false;
          return copy;
        }
        return n;
      }).toList();

      final unread = updated
          .where((n) => n['isRead'] == false || n['isUnread'] == true)
          .length;
      state = state.copyWith(notifications: updated, unreadCount: unread);
    } catch (e) {
      debugPrint('[NOTIFICATION_NOTIFIER] markAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _service.deleteNotification(id);
      final updated = state.notifications
          .where((n) => n['id'].toString() != id)
          .toList();
      final unread = updated
          .where((n) => n['isRead'] == false || n['isUnread'] == true)
          .length;
      state = state.copyWith(notifications: updated, unreadCount: unread);
    } catch (e) {
      debugPrint('[NOTIFICATION_NOTIFIER] deleteNotification error: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllNotificationsAsRead();
      final updated = state.notifications.map((n) {
        final copy = Map<String, dynamic>.from(n);
        copy['isRead'] = true;
        copy['isUnread'] = false;
        return copy;
      }).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (e) {
      debugPrint('[NOTIFICATION_NOTIFIER] markAllAsRead error: $e');
    }
  }
}

final employeeNotificationProvider =
    NotifierProvider<EmployeeNotificationNotifier, NotificationState>(
      EmployeeNotificationNotifier.new,
    );
