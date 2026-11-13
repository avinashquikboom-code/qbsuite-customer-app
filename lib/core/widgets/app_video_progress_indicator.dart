import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// A robust, lifecycle-safe replacement for Flutter's [VideoProgressIndicator].
///
/// Standard [VideoProgressIndicator] calls `setState()` directly within its
/// controller listener whenever the player emits a progress or state tick. If
/// this occurs during Flutter's persistentCallbacks (widget build/layout) phase,
/// it crashes with:
/// "setState() or markNeedsBuild() called during build. VideoProgressIndicator
/// widget cannot be marked as needing to build because the framework is already
/// in the process of building widgets."
///
/// This component:
/// 1. Defers `setState()` calls to [addPostFrameCallback] when called during
///    the `persistentCallbacks` phase or while [debugBuilding] is active.
/// 2. Correctly unsubscribes and re-subscribes in [didUpdateWidget] if the controller instance changes.
/// 3. Ensures clean disposal without leaking listeners.
/// 4. Provides identical appearance, scrubbing physics, colors, and layout metrics.
class AppVideoProgressIndicator extends StatefulWidget {
  /// The controller that drives this progress indicator.
  final VideoPlayerController controller;

  /// Colors used for the played, buffered, and background bars.
  final VideoProgressColors colors;

  /// Whether scrubbing (drag/tap seeking) is enabled.
  final bool allowScrubbing;

  /// Padding around the indicator bar.
  final EdgeInsets padding;

  const AppVideoProgressIndicator(
    this.controller, {
    super.key,
    this.colors = const VideoProgressColors(),
    required this.allowScrubbing,
    this.padding = const EdgeInsets.only(top: 5.0),
  });

  @override
  State<AppVideoProgressIndicator> createState() =>
      _AppVideoProgressIndicatorState();
}

class _AppVideoProgressIndicatorState extends State<AppVideoProgressIndicator> {
  VideoPlayerController get controller => widget.controller;
  VideoProgressColors get colors => widget.colors;

  void _didUpdateControllerValue() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        (WidgetsBinding.instance.buildOwner?.debugBuilding ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_didUpdateControllerValue);
  }

  @override
  void didUpdateWidget(covariant AppVideoProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didUpdateControllerValue);
      widget.controller.addListener(_didUpdateControllerValue);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_didUpdateControllerValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget progressIndicator;
    if (controller.value.isInitialized) {
      final int duration = controller.value.duration.inMilliseconds;
      final int position = controller.value.position.inMilliseconds;

      final double maxBuffering = duration == 0
          ? 0.0
          : controller.value.buffered
                    .map((range) => range.end.inMilliseconds)
                    .fold<int>(0, math.max) /
                duration;

      progressIndicator = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          LinearProgressIndicator(
            value: maxBuffering.clamp(0.0, 1.0),
            valueColor: AlwaysStoppedAnimation<Color>(colors.bufferedColor),
            backgroundColor: colors.backgroundColor,
          ),
          LinearProgressIndicator(
            value: duration == 0 ? 0.0 : (position / duration).clamp(0.0, 1.0),
            valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
            backgroundColor: Colors.transparent,
          ),
        ],
      );
    } else {
      progressIndicator = LinearProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
        backgroundColor: colors.backgroundColor,
      );
    }

    final Widget paddedProgressIndicator = Padding(
      padding: widget.padding,
      child: progressIndicator,
    );

    if (widget.allowScrubbing) {
      return _AppVideoScrubber(
        controller: controller,
        child: paddedProgressIndicator,
      );
    } else {
      return paddedProgressIndicator;
    }
  }
}

class _AppVideoScrubber extends StatefulWidget {
  final Widget child;
  final VideoPlayerController controller;

  const _AppVideoScrubber({required this.child, required this.controller});

  @override
  State<_AppVideoScrubber> createState() => _AppVideoScrubberState();
}

class _AppVideoScrubberState extends State<_AppVideoScrubber> {
  bool _controllerWasPlaying = false;
  VideoPlayerController get controller => widget.controller;

  void _seekToRelativePosition(Offset globalPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || renderBox.size.width <= 0) {
      return;
    }
    final Offset tapPos = renderBox.globalToLocal(globalPosition);
    final double relative = (tapPos.dx / renderBox.size.width).clamp(0.0, 1.0);
    final Duration position = controller.value.duration * relative;
    controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.isInitialized) return;
        _controllerWasPlaying = controller.value.isPlaying;
        if (_controllerWasPlaying) {
          controller.pause();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.isInitialized) return;
        _seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_controllerWasPlaying) {
          controller.play();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.value.isInitialized) return;
        _seekToRelativePosition(details.globalPosition);
      },
    );
  }
}
