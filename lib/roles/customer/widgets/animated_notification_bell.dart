import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_notification_viewmodel.dart';

/// A self-contained, animated notification bell icon for the Home AppBar.
///
/// Features:
///  - Automatically shakes/wiggles smoothly when unreadCount > 0
///  - Uses a natural, subtle swing sequence (left -> right -> left)
///  - Repeats continuously while unread notifications exist
///  - Automatically stops and rests statically at 0° when unreadCount == 0
///  - Starts automatically if unread notifications exist on mount
///  - Reacts instantly when new notifications arrive or are marked as read
///  - Zero fake timers or polling; lightweight AnimatedBuilder prevents screen rebuilds
class AnimatedNotificationBell extends ConsumerStatefulWidget {
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? dotColor;
  final double iconSize;

  const AnimatedNotificationBell({
    super.key,
    required this.onPressed,
    this.iconColor,
    this.dotColor,
    this.iconSize = 24.0,
  });

  @override
  ConsumerState<AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState
    extends ConsumerState<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _swingAnimation;

  // Keyframe rotation angles in radians:
  // 14° ≈ 0.244 rad, 10° ≈ 0.174 rad, 5° ≈ 0.087 rad
  static const double _deg14 = 14.0 * math.pi / 180.0;
  static const double _deg10 = 10.0 * math.pi / 180.0;
  static const double _deg5 = 5.0 * math.pi / 180.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Subtle bell shake sequence:
    // 0.0 -> left (-14°) -> right (+14°) -> left (-10°) -> right (+10°) -> left (-5°) -> center (0°) -> pause at 0°
    _swingAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -_deg14,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg14,
          end: _deg14,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _deg14,
          end: -_deg10,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg10,
          end: _deg10,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 7,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _deg10,
          end: -_deg5,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 6,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -_deg5,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 58),
    ]).animate(_controller);

    // Start immediately if unread notifications already exist when Home opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final count = ref.read(employeeNotificationProvider).unreadCount;
      if (count > 0 && !_controller.isAnimating) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(int unreadCount) {
    if (!mounted) return;
    if (unreadCount > 0) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating || _controller.value != 0.0) {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically react when notification state changes (e.g. notifications arrive or marked as read)
    ref.listen<NotificationState>(employeeNotificationProvider, (
      previous,
      next,
    ) {
      _syncAnimation(next.unreadCount);
    });

    final unreadCount = ref.watch(employeeNotificationProvider).unreadCount;

    // Guard against edge cases where count updated before listener attached
    if (unreadCount > 0 && !_controller.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isAnimating) {
          _controller.repeat();
        }
      });
    } else if (unreadCount == 0 && _controller.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isAnimating) {
          _controller.stop();
          _controller.reset();
        }
      });
    }

    return AnimatedBuilder(
      animation: _swingAnimation,
      builder: (context, _) {
        return IconButton(
          tooltip: 'Notifications',
          onPressed: widget.onPressed,
          icon: Transform.rotate(
            alignment: Alignment.topCenter,
            angle: _swingAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Remix.notification_3_line,
                  color: widget.iconColor ?? AppColors.textPrimary,
                  size: widget.iconSize,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.dotColor ?? AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
