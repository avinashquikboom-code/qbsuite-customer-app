import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/widgets/app_video_progress_indicator.dart';
import '../models/marketing_video_model.dart';
import '../services/customer_marketing_video_service.dart';

/// Full-screen Marketing Video Introduction screen.
///
/// Shown after the splash/launcher — before the rest of the customer experience —
/// when Admin has configured an active Marketing Video with [showInIntroduction=true]
/// that the customer has not yet seen.
///
/// REQUIREMENTS:
/// - Full-screen video, no thumbnail.
/// - Autoplays muted.
/// - Prominent Skip button (always tappable).
/// - Marks the video as seen/skipped via the existing backend tracking API.
/// - Pauses on app background; resumes on foreground.
/// - On completion or Skip → calls [onDone] to continue the normal flow.
/// - User is NEVER stuck: any error gracefully falls through via [onDone].
class MarketingVideoIntroductionScreen extends ConsumerStatefulWidget {
  /// The eligible Introduction marketing video (from backend).
  final MarketingVideoModel video;

  /// Called when the intro is done (skip, complete, or error).
  /// The caller navigates forward after this.
  final VoidCallback onDone;

  const MarketingVideoIntroductionScreen({
    super.key,
    required this.video,
    required this.onDone,
  });

  /// Convenience push helper — pushes the screen and awaits its completion.
  static Future<void> push(
    BuildContext context, {
    required MarketingVideoModel video,
    required VoidCallback onDone,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MarketingVideoIntroductionScreen(video: video, onDone: onDone),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
        // Full screen — remove app bar and status bar interference
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<MarketingVideoIntroductionScreen> createState() =>
      _MarketingVideoIntroductionScreenState();
}

class _MarketingVideoIntroductionScreenState
    extends ConsumerState<MarketingVideoIntroductionScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  bool _isLoading = false;

  /// Default: muted (volume = 0). User can toggle at any time.
  bool _isMuted = true;

  /// Guard: prevents double-marking or double-navigation.
  bool _isDone = false;

  bool get _isYouTube {
    final url = widget.video.videoUrl;
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Make the status bar transparent so the video fills edge-to-edge.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialise and autoplay after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.removeListener(_onPlayerUpdate);
    _videoController?.dispose();
    _youtubeController?.close();
    // Restore system UI when leaving.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        (WidgetsBinding.instance.buildOwner?.debugBuilding ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  /// Pause on app background; resume on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized || _isYouTube) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_videoController?.value.isPlaying == true) {
          _videoController!.pause();
          _safeSetState(() => _isPlaying = false);
        }
        break;
      case AppLifecycleState.resumed:
        if (_isInitialized && !(_videoController?.value.isPlaying ?? false)) {
          _videoController!.play();
          _safeSetState(() => _isPlaying = true);
        }
        break;
    }
  }

  // ─── Player Listener ────────────────────────────────────────────────────────

  void _onPlayerUpdate() {
    if (_videoController == null) return;
    final val = _videoController!.value;

    // Sync UI playing state
    if (val.isPlaying != _isPlaying && mounted) {
      _safeSetState(() => _isPlaying = val.isPlaying);
    }

    // Preserve mute state across any internal resets without mutating synchronously in listener
    final expectedVol = _isMuted ? 0.0 : 1.0;
    if ((val.volume - expectedVol).abs() > 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoController != null) {
          _videoController!.setVolume(expectedVol);
        }
      });
    }

    // Video completed → mark seen and move forward
    final isEnded =
        val.duration > Duration.zero && val.position >= val.duration;
    if (isEnded) {
      _markSeenAndDone();
    }
  }

  // ─── Initialisation ─────────────────────────────────────────────────────────

  Future<void> _initPlayer() async {
    if (_isInitialized || _isLoading) return;

    if (_isYouTube) {
      final videoId = YoutubePlayerController.convertUrlToId(
        widget.video.videoUrl,
      );
      if (videoId != null) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: false,
            mute: true,
          ),
        );
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isPlaying = true;
          });
        }
      } else {
        // Invalid YouTube URL — continue gracefully
        debugPrint('[INTRO_VIDEO] invalid YouTube URL, skipping');
        _markSeenAndDone();
      }
      return;
    }

    // S3 / direct URL
    if (mounted) setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(widget.video.videoUrl);
      _videoController = VideoPlayerController.networkUrl(uri);

      await _videoController!.initialize();

      // Muted by default
      await _videoController!.setVolume(0.0);

      // Introduction video does NOT loop — plays once, then marks seen
      await _videoController!.setLooping(false);

      _videoController!.addListener(_onPlayerUpdate);

      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
          _isLoading = false;
          _isMuted = true;
        });
      }
      debugPrint('[INTRO_VIDEO] playing | id: ${widget.video.id}');
    } catch (e) {
      debugPrint('[INTRO_VIDEO] init error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      // Error — continue gracefully after brief pause
      await Future.delayed(const Duration(seconds: 2));
      _markSeenAndDone();
    }
  }

  // ─── Controls ───────────────────────────────────────────────────────────────

  void _toggleMute() {
    if (_videoController == null || !_isInitialized) return;
    final nextMuted = !_isMuted;
    _videoController!.setVolume(nextMuted ? 0.0 : 1.0);
    setState(() => _isMuted = nextMuted);
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() => _isPlaying = false);
    } else {
      _videoController!.play();
      setState(() => _isPlaying = true);
    }
  }

  // ─── Skip / Completion ──────────────────────────────────────────────────────

  Future<void> _onSkip() async {
    debugPrint('[INTRO_VIDEO] skip tapped | id: ${widget.video.id}');
    _markSeenAndDone();
  }

  /// Marks the video as seen on the backend and calls [onDone].
  /// Safe to call multiple times — guarded by [_isDone].
  Future<void> _markSeenAndDone() async {
    if (_isDone) return;
    _isDone = true;

    // Stop playback immediately
    try {
      if (_videoController?.value.isPlaying == true) {
        await _videoController!.pause();
      }
    } catch (_) {}

    // Mark seen on backend (non-blocking — we don't await the result to block UX)
    ref
        .read(customerMarketingVideoServiceProvider)
        .markIntroductionVideoSeen(widget.video.id)
        .then((ok) {
          debugPrint(
            '[INTRO_VIDEO] markSeen result: $ok | id: ${widget.video.id}',
          );
        })
        .catchError((e) {
          debugPrint('[INTRO_VIDEO] markSeen error: $e');
        });

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
    // onDone is called by the caller (CustomerHomeView) after pop
    widget.onDone();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen Video Player ────────────────────────────────────────
          _buildVideoSurface(screenSize),

          // ── Loading Spinner ─────────────────────────────────────────────────
          if (_isLoading && !_hasError)
            const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),

          // ── Error State ─────────────────────────────────────────────────────
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Video unavailable.\nContinuing…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          // ── Play/Pause overlay (tap center when paused) ─────────────────────
          if (_isInitialized && !_isPlaying && !_hasError && !_isYouTube)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),

          // ── Top Controls (SafeArea: Skip + Mute) ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mute / Unmute
                  if (_isInitialized && !_isYouTube)
                    _ControlButton(
                      icon: _isMuted
                          ? Remix.volume_mute_line
                          : Remix.volume_up_line,
                      onTap: _toggleMute,
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                    )
                  else
                    const SizedBox(width: 40),

                  // Skip — always shown, even during loading/error
                  _SkipButton(onTap: _onSkip),
                ],
              ),
            ),
          ),

          // ── Bottom: Video Title + Progress ─────────────────────────────────
          if (_isInitialized && _videoController != null && !_isYouTube)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title/subtitle gradient overlay
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                          if (widget.video.subtitle != null &&
                              widget.video.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.video.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Progress bar
                    AppVideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF6366F1),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the full-screen video surface.
  Widget _buildVideoSurface(Size screenSize) {
    if (_isInitialized && _isYouTube && _youtubeController != null) {
      return YoutubePlayer(controller: _youtubeController!);
    }

    if (_isInitialized &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      // Cover-fill: expand the video to fill the screen while maintaining
      // aspect ratio (crops edges on non-matching aspect ratios).
      final videoAspect = _videoController!.value.aspectRatio;
      final screenAspect = screenSize.width / screenSize.height;

      final double scale = screenAspect > videoAspect
          ? screenAspect / videoAspect
          : videoAspect / screenAspect;

      return GestureDetector(
        onTap: _togglePlayPause,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: AspectRatio(
              aspectRatio: videoAspect,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      );
    }

    // Dark placeholder while loading — no thumbnail
    return const ColoredBox(color: Colors.black);
  }
}

// ─── Supporting Widgets ────────────────────────────────────────────────────────

/// Translucent circular icon control button used for mute/unmute.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// Pill-shaped Skip button — always tappable regardless of video state.
class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Remix.skip_forward_line, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}
