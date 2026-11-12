import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/models/user_role.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';

/// Provider for managing real-time schedule & plan synchronization
final planScheduleRealtimeServiceProvider =
    Provider<PlanScheduleRealtimeService>((ref) {
      final service = PlanScheduleRealtimeService(ref);
      ref.onDispose(() => service.dispose());
      return service;
    });

class PlanScheduleRealtimeService with WidgetsBindingObserver {
  final Ref _ref;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  StreamSubscription? _connectivitySub;
  bool _isDisposed = false;
  bool _isConnecting = false;
  String? _connectedCustomerId;

  PlanScheduleRealtimeService(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) connect();
    });
  }

  void _initConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline &&
          (_socket == null || _socket?.readyState != WebSocket.open)) {
        debugPrint('[REALTIME] Network restored. Reconnecting...');
        connect();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        '[REALTIME] App resumed to foreground. Ensuring connection & sync.',
      );
      if (_socket == null || _socket?.readyState != WebSocket.open) {
        // Socket dropped while backgrounded — reconnect (permission refresh
        // will happen automatically after the namespace join handshake).
        connect();
      } else {
        // Socket is still alive — proactively refresh permissions AND
        // calendar providers to catch any changes made while backgrounded.
        _refreshPermissions();
        invalidatePlanAndCalendarProviders(reason: 'App Resumed');
      }
    }
  }

  /// Connect to the backend WebSocket for real-time schedule events
  Future<void> connect() async {
    if (_isDisposed || _isConnecting) return;

    final apiClient = _ref.read(apiClientProvider);
    final customerIdAsync = _ref.read(currentCustomerIdProvider);
    final customerId =
        customerIdAsync.asData?.value ??
        customerIdAsync.value ??
        apiClient.customerId ??
        '';

    if (customerId.isEmpty) {
      debugPrint(
        '[REALTIME] No customer context available. Connection deferred.',
      );
      return;
    }

    _isConnecting = true;
    _connectedCustomerId = customerId;

    try {
      await apiClient.ensureAuthLoaded();
      await _socket?.close();
      _socket = null;

      final normalizedCustId = customerId.startsWith('CUST-')
          ? customerId
          : 'CUST-$customerId';

      // Validate token expiration before sending to websocket query/headers
      String? validToken = apiClient.token;
      if (validToken != null && validToken.isNotEmpty) {
        try {
          final parts = validToken.split('.');
          if (parts.length == 3) {
            final normalized = base64Url.normalize(parts[1]);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final map = jsonDecode(decoded);
            if (map is Map && map['exp'] is int) {
              final expSec = map['exp'] as int;
              final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              if (expSec <= nowSec) {
                validToken = null;
              }
            }
          }
        } catch (_) {}
      }

      if (validToken == null || validToken.trim().isEmpty) {
        _isConnecting = false;
        debugPrint('[REALTIME] No valid session token. Connection deferred.');
        _scheduleReconnect();
        return;
      }

      final wsUrl = AppUrl.getWsUrl(
        AppUrl.planScheduleWs,
        queryParams: {'customerId': normalizedCustId},
      );

      debugPrint('[REALTIME]\nConnecting to: $wsUrl');
      final socket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Origin': 'https://api.qbapp.online',
          'Authorization': 'Bearer $validToken',
        },
      ).timeout(const Duration(seconds: 10));

      _socket = socket;
      _isConnecting = false;

      debugPrint('[REALTIME]\nConnected');
      debugPrint('[REALTIME]\nCustomer: $normalizedCustId');

      // Send joinCustomerRoom message in case standard socket / custom protocol
      try {
        final joinPayload = jsonEncode({
          'event': 'joinCustomerRoom',
          'data': {'customerId': normalizedCustId},
        });
        socket.add(joinPayload);
      } catch (_) {}

      // Keepalive ping (Engine.IO ping is '2')
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_socket?.readyState == WebSocket.open) {
          try {
            _socket?.add('2');
          } catch (_) {}
        }
      });

      socket.listen(
        (data) {
          final raw = data.toString();
          // 1. Engine.IO OPEN packet: '0{"sid":...}' -> send Socket.IO namespace connect
          if (raw.startsWith('0')) {
            socket.add('40/ws/plan-schedule,');
            return;
          }
          // 2. Engine.IO PING -> reply with PONG '3'
          if (raw == '2' || raw == '2probe') {
            socket.add(raw == '2probe' ? '3probe' : '3');
            return;
          }
          // 3. Socket.IO namespace joined: '40/ws/plan-schedule...'
          if (raw.startsWith('40/ws/plan-schedule')) {
            _reconnectAttempts = 0; // reset backoff on successful connection
            debugPrint('[REALTIME] Joined namespace /ws/plan-schedule');
            try {
              final joinPayload = jsonEncode({'customerId': normalizedCustId});
              socket.add(
                '42/ws/plan-schedule,["joinCustomerRoom",$joinPayload]',
              );
            } catch (_) {}
            // Refresh permissions on every successful (re)connect to catch any
            // changes that occurred while the socket was disconnected.
            _refreshPermissions();
            return;
          }
          _handleIncomingMessage(raw);
        },
        onError: (err) {
          debugPrint('[REALTIME] Socket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[REALTIME] Socket closed.');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[REALTIME] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(String raw) {
    try {
      debugPrint('[REALTIME_RAW] $raw');
      Map<String, dynamic>? payload;

      // Handle Socket.IO packet format: 42...["event", {...}]
      if (raw.startsWith('42')) {
        final bracketIdx = raw.indexOf('[');
        if (bracketIdx != -1) {
          final jsonStr = raw.substring(bracketIdx);
          final list = jsonDecode(jsonStr);
          if (list is List && list.isNotEmpty) {
            final eventType = list[0]?.toString();
            // Server error packet (e.g. 401 token expired) - do NOT treat as business event
            if (eventType == 'error') {
              debugPrint(
                '[REALTIME_ERROR] Server error packet: ${list.length > 1 ? list[1] : ""}',
              );
              if (list.length > 1 && list[1] is Map) {
                final errMap = list[1] as Map;
                if (errMap['statusCode'] == 401) {
                  _reconnectAttempts = 5; // back off to avoid reconnect storm
                }
              }
              return;
            }

            if (list.length >= 2 && list[1] is Map) {
              payload = Map<String, dynamic>.from(list[1] as Map);
              if (!payload.containsKey('event')) {
                payload['event'] = eventType;
              }
            }
          }
        }
      } else if (raw.startsWith('{')) {
        // Direct JSON format
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          if (decoded['event'] == 'error' || decoded['statusCode'] != null) {
            debugPrint('[REALTIME_ERROR] Server error JSON: $decoded');
            return;
          }
          payload = Map<String, dynamic>.from(decoded);
        }
      }

      if (payload != null) {
        handleRealtimeEvent(payload);
      }
    } catch (e) {
      debugPrint('[REALTIME_PARSE_ERROR] Failed to parse message: $e');
    }
  }

  String get currentCustomerId {
    if (_connectedCustomerId != null && _connectedCustomerId!.isNotEmpty) {
      return _connectedCustomerId!;
    }
    final custAsync = _ref.read(currentCustomerIdProvider);
    final fromProvider = custAsync.asData?.value ?? custAsync.value ?? '';
    if (fromProvider.isNotEmpty) return fromProvider;
    return _ref.read(apiClientProvider).customerId ?? '';
  }

  /// Process real-time event with mandatory customer isolation and provider invalidation
  void handleRealtimeEvent(Map<String, dynamic> payload) {
    final eventName = (payload['event'] ?? payload['type'] ?? 'EVENT')
        .toString();
    final eventCustomerId = (payload['customerId'] ?? '').toString();
    final scheduleId = (payload['scheduleId'] ?? payload['id'] ?? 'N/A')
        .toString();

    // Do not process non-event payloads or error states
    if (eventName.toLowerCase() == 'error') return;

    // ── RBAC Permission Events ──────────────────────────────────────────────
    // When admin changes role/employee permissions the backend emits one of these
    // events. We immediately refresh our effective permissions without
    // requiring the employee to logout/login.
    if (eventName == 'employee_permissions_updated' ||
        eventName == 'designation_permissions_updated' ||
        eventName == 'customer_permissions_updated') {
      debugPrint(
        '[REALTIME_PERMISSIONS] Received $eventName — refreshing permissions',
      );
      _refreshPermissions();
      return;
    }

    // 1. Mandatory Customer Isolation Check
    final currentId = currentCustomerId;
    if (eventCustomerId.isNotEmpty && currentId.isNotEmpty) {
      final normEventId = eventCustomerId.replaceAll(RegExp(r'\D'), '');
      final normCurrentId = currentId.replaceAll(RegExp(r'\D'), '');
      if (normEventId.isNotEmpty &&
          normCurrentId.isNotEmpty &&
          normEventId != normCurrentId) {
        debugPrint(
          '[REALTIME_ISOLATION] Discarded event for other customer ($eventCustomerId != $currentId)',
        );
        return;
      }
    }

    // 2. Structured Debug Logging (exact match with requirements)
    debugPrint('[REALTIME_EVENT]\n$eventName\nscheduleId: $scheduleId');

    // 3. Trigger targeted Riverpod provider invalidations
    invalidatePlanAndCalendarProviders(
      specificDate: payload['date']?.toString(),
      reason: eventName,
    );
  }

  /// Trigger a live permission refresh from the backend.
  /// This updates both the singleton PermissionManager and the Riverpod
  /// permissionManagerProvider, causing reactive UI widgets to rebuild.
  void _refreshPermissions() {
    try {
      final role = _ref.read(loginStateProvider).role;
      if (role == UserRole.customer) {
        _ref.read(loginStateProvider.notifier).refreshCustomerPermissions();
      } else {
        _ref.read(loginStateProvider.notifier).refreshPermissions();
      }
      debugPrint(
        '[REALTIME_PERMISSIONS] refreshPermissions() triggered successfully',
      );
    } catch (e) {
      debugPrint(
        '[REALTIME_PERMISSIONS] Failed to trigger refreshPermissions: $e',
      );
    }
  }

  /// Invalidate all relevant Riverpod providers and trigger fresh fetch without page reload
  void invalidatePlanAndCalendarProviders({
    String? specificDate,
    String? reason,
  }) {
    debugPrint('[CALENDAR_REFRESH]\nInvalidating calendar providers');

    // 1. Invalidate Effective Plan & Subscription Providers
    _ref.invalidate(customerEffectivePlanProvider);
    _ref.invalidate(currentSubscriptionProvider);
    _ref.invalidate(currentCustomerSubscriptionProvider);
    _ref.invalidate(plansProvider);

    // 2. Invalidate Date-Specific Calendar Provider
    if (specificDate != null && specificDate.isNotEmpty) {
      _ref.invalidate(customerCalendarActivitiesForDateProvider(specificDate));
    } else {
      _ref.invalidate(customerCalendarActivitiesForDateProvider);
    }

    // 3. Invalidate Month & Multi-Day Providers
    _ref.invalidate(customerCalendarActivitiesForMonthProvider);
    _ref.invalidate(customerCalendarScheduledDatesForMonthProvider);
    _ref.invalidate(customerCalendarPlanSummaryProvider);
    _ref.invalidate(customerCalendarActivitiesFor7DayWindowProvider);
    _ref.invalidate(customerCalendarActivitiesProvider);

    debugPrint('[CALENDAR_REFRESH]\nFetching updated activities');
  }

  int _reconnectAttempts = 0;

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    // Exponential backoff: 3s, 6s, 12s, 24s, up to 60s
    final delaySec = (3 * (1 << _reconnectAttempts)).clamp(3, 60);
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 5);

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  /// Disconnect socket on user logout
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _socket?.close();
    _socket = null;
    _connectedCustomerId = null;
    debugPrint('[REALTIME] Disconnected.');
  }

  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    disconnect();
  }
}
