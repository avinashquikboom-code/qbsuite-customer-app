import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/widgets/app_video_progress_indicator.dart';
import '../models/marketing_video_model.dart';
import '../viewmodels/customer_marketing_video_viewmodel.dart';

/// Dynamic Marketing Video Section displayed on the Customer Home Screen
/// positioned directly between QB Marketplace and Influencer Hub.
///
/// CRITICAL REQUIREMENT:
/// When there are NO active marketing videos, this widget collapses to `const SizedBox.shrink()`
/// leaving behind zero padding, zero reserved space, and zero placeholder content.
///
/// VISIBILITY LIFECYCLE:
/// - Uses [NotificationListener<ScrollNotification>] to detect when the section
///   enters/leaves the visible viewport and signals cards via [_visibleNotifier].
/// - Each [_MarketingVideoCard] pauses when it becomes invisible and resumes
///   when it comes back into view.
/// - App lifecycle (background/foreground) is handled via [WidgetsBindingObserver].
class CustomerMarketingVideoSection extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const CustomerMarketingVideoSection({super.key, this.onNavigateToTab});

  @override
  ConsumerState<CustomerMarketingVideoSection> createState() =>
      _CustomerMarketingVideoSectionState();
}

class _CustomerMarketingVideoSectionState
    extends ConsumerState<CustomerMarketingVideoSection> {
  int _currentPage = 0;
  late final PageController _pageController;

  /// Shared notifier — true when this section is on-screen, false when scrolled away.
  /// Passed down to each [_MarketingVideoCard] so they can pause/resume accordingly.
  final ValueNotifier<bool> _visibleNotifier = ValueNotifier<bool>(true);

  /// The [GlobalKey] is attached to the outermost widget so we can measure its
  /// position in the scroll viewport.
  final GlobalKey _sectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _visibleNotifier.dispose();
    super.dispose();
  }

  // ── Scroll visibility detection ─────────────────────────────────────────────

  /// Called on every scroll notification.  Checks whether the widget keyed by
  /// [_sectionKey] is at least partially within the scroll viewport.
  void _onScrollNotification(ScrollNotification notification) {
    if (!mounted) return;
    final renderBox = _sectionKey.currentContext?.findRenderObject();
    if (renderBox == null || renderBox is! RenderBox) return;

    // Find the nearest scroll viewport ancestor.
    final viewport = RenderAbstractViewport.of(renderBox);

    // Offset of the top/bottom of the widget relative to the viewport.
    final revealTop = viewport
        .getOffsetToReveal(renderBox, 0.0, rect: Offset.zero & renderBox.size)
        .offset;
    final revealBottom = viewport
        .getOffsetToReveal(renderBox, 1.0, rect: Offset.zero & renderBox.size)
        .offset;

    final scrollOffset = notification.metrics.pixels;
    final viewportDimension = notification.metrics.viewportDimension;

    // Widget is visible if ANY part of it overlaps the viewport.
    final isNowVisible =
        scrollOffset < revealBottom &&
        (scrollOffset + viewportDimension) > revealTop;

    if (_visibleNotifier.value != isNowVisible) {
      _visibleNotifier.value = isNowVisible;
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(customerMarketingVideosProvider);

    return videosAsync.when(
      data: (videos) {
        final eligibleVideos = videos
            .where((v) => v.isEligibleForHome)
            .toList();

        debugPrint('[MARKETING_VIDEO_HOME]');
        debugPrint('rendering: ${eligibleVideos.isNotEmpty}');

        if (eligibleVideos.isEmpty) {
          return const SizedBox.shrink();
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScrollNotification(notification);
            // Return false so the notification continues to bubble up.
            return false;
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _buildSectionContainer(context, eligibleVideos),
          ),
        );
      },
      loading: () {
        debugPrint('[MARKETING_VIDEO_HOME]');
        debugPrint('rendering: false (loading)');
        return const SizedBox.shrink();
      },
      error: (err, stack) {
        debugPrint('[MARKETING_VIDEO_HOME]');
        debugPrint('rendering: false (error: $err)');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionContainer(
    BuildContext context,
    List<MarketingVideoModel> videos,
  ) {
    return Container(
      key: _sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Remix.play_circle_fill,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Marketing Videos',
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Watch platform guides, tips & offers 🎬',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (videos.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${videos.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Video Content (Single Card or PageView Carousel) ────────────────
          if (videos.length == 1)
            _MarketingVideoCard(
              key: ValueKey('marketing_video_${videos.first.id}'),
              video: videos.first,
              visibleNotifier: _visibleNotifier,
            )
          else ...[
            SizedBox(
              height: 290,
              child: PageView.builder(
                controller: _pageController,
                itemCount: videos.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, idx) {
                  final v = videos[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _MarketingVideoCard(
                      key: ValueKey('marketing_video_${v.id}'),
                      video: v,
                      visibleNotifier: _visibleNotifier,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  videos.length,
                  (idx) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == idx ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == idx
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _MarketingVideoCard
// ═══════════════════════════════════════════════════════════════════════════════

/// Interactive card component that renders inline video playback.
///
/// VISIBILITY / LIFECYCLE:
/// - Listens to [visibleNotifier]: when false → pause; when true → resume.
/// - [WidgetsBindingObserver] pauses on app background, resumes on foreground
///   (only if [visibleNotifier] is currently true).
/// - Scroll position is preserved on pause — resuming continues from ~00:15.
/// - Mute/unmute state is fully preserved across pause/resume and loop cycles.
class _MarketingVideoCard extends StatefulWidget {
  final MarketingVideoModel video;

  /// Shared notifier from parent section — true = section on screen.
  final ValueNotifier<bool> visibleNotifier;

  const _MarketingVideoCard({
    super.key,
    required this.video,
    required this.visibleNotifier,
  });

  @override
  State<_MarketingVideoCard> createState() => _MarketingVideoCardState();
}

class _MarketingVideoCardState extends State<_MarketingVideoCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;

  // Playback state flags
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isLoading = false;

  /// Muted by default — volume starts at 0.
  /// State is preserved across pause/resume and loop iterations.
  bool _isMuted = true;

  /// True when app is in the foreground (resumed lifecycle state).
  bool _appIsActive = true;

  bool get _isYouTube {
    final url = widget.video.videoUrl;
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  // ─── Safe State Update ───────────────────────────────────────────────────────

  /// Safe helper that defers setState to post-frame if called during build/layout.
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

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen to scroll visibility changes from the parent section
    widget.visibleNotifier.addListener(_onVisibilityChanged);
    // Autoplay on first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoplay();
    });
  }

  @override
  void didUpdateWidget(covariant _MarketingVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleNotifier != widget.visibleNotifier) {
      oldWidget.visibleNotifier.removeListener(_onVisibilityChanged);
      widget.visibleNotifier.addListener(_onVisibilityChanged);
    }
    if (oldWidget.video.videoUrl != widget.video.videoUrl) {
      _disposeControllers();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAutoplay();
      });
    }
  }

  @override
  void deactivate() {
    // Note: NEVER call setState() or synchronous notify-triggering controller calls
    // in deactivate(). Deactivate is called during the build/layout phase when a widget
    // is being detached or moved by KeyedSubtree.
    _isPlaying = false;
    final ctrl = _videoController;
    if (ctrl != null && ctrl.value.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
          }
        } catch (_) {}
      });
      debugPrint(
        '[MARKETING_VIDEO] scheduled pause — navigated away from Home',
      );
    }
    super.deactivate();
  }

  void _disposeControllers() {
    _videoController?.removeListener(_onVideoPlayerUpdate);
    _videoController?.dispose();
    _videoController = null;

    _youtubeController?.close();
    _youtubeController = null;

    _isInitialized = false;
    _isPlaying = false;
    _isLoading = false;
    _hasError = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.visibleNotifier.removeListener(_onVisibilityChanged);
    _disposeControllers();
    super.dispose();
  }

  // ─── Visibility listener ────────────────────────────────────────────────────

  /// Called whenever the parent section's scroll visibility changes.
  void _onVisibilityChanged() {
    if (!mounted || _isYouTube) return;
    final isVisible = widget.visibleNotifier.value;

    if (!isVisible) {
      // Scrolled off-screen → pause post-frame, preserve position.
      if (_videoController?.value.isPlaying == true) {
        _safeSetState(() => _isPlaying = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _videoController?.value.isPlaying == true) {
            _videoController!.pause();
            debugPrint('[MARKETING_VIDEO] paused — scrolled off-screen');
          }
        });
      }
    } else {
      // Scrolled back into view — only resume if app is active and video
      // was playing before (not in a user-paused state before scrolling).
      if (_appIsActive &&
          _isInitialized &&
          !(_videoController?.value.isPlaying ?? false)) {
        _safeSetState(() => _isPlaying = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _appIsActive &&
              !(_videoController?.value.isPlaying ?? false)) {
            _videoController!.play();
            debugPrint('[MARKETING_VIDEO] resumed — scrolled back into view');
          }
        });
      }
    }
  }

  // ─── App lifecycle observer ─────────────────────────────────────────────────

  /// Pause on app background; resume on foreground ONLY if section is visible.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized || _isYouTube) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appIsActive = false;
        if (_videoController?.value.isPlaying == true) {
          _videoController!.pause();
          _safeSetState(() => _isPlaying = false);
          debugPrint('[MARKETING_VIDEO] paused — app backgrounded');
        }
        break;

      case AppLifecycleState.resumed:
        _appIsActive = true;
        // Only resume if the section is currently visible on screen
        if (widget.visibleNotifier.value &&
            _isInitialized &&
            !(_videoController?.value.isPlaying ?? false)) {
          _videoController!.play();
          _safeSetState(() => _isPlaying = true);
          debugPrint(
            '[MARKETING_VIDEO] resumed — app foregrounded + section visible',
          );
        }
        break;
    }
  }

  // ─── Video Player Listener ──────────────────────────────────────────────────

  void _onVideoPlayerUpdate() {
    if (_videoController == null) return;
    final val = _videoController!.value;

    // Keep isPlaying UI state in sync with actual player state
    final nowPlaying = val.isPlaying;
    if (nowPlaying != _isPlaying && mounted) {
      _safeSetState(() => _isPlaying = nowPlaying);
    }

    // Ensure mute state is preserved on every loop tick without mutating volume synchronously in listener
    final expectedVolume = _isMuted ? 0.0 : 1.0;
    if ((val.volume - expectedVolume).abs() > 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _videoController != null) {
          _videoController!.setVolume(expectedVolume);
        }
      });
    }
  }

  // ─── Playback Control ───────────────────────────────────────────────────────

  /// Initialises and begins playback — muted by default.
  Future<void> _startAutoplay() async {
    // Guard: do not re-initialise if already running
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
            showFullscreenButton: true,
            mute: true,
          ),
        );
        if (mounted) {
          _safeSetState(() {
            _isPlaying = true;
            _isInitialized = true;
          });
        }
      }
      return;
    }

    // S3 / direct video URL
    if (mounted) _safeSetState(() => _isLoading = true);

    try {
      final uri = Uri.parse(widget.video.videoUrl);
      _videoController = VideoPlayerController.networkUrl(uri);

      await _videoController!.initialize();

      // Apply default muted volume before calling play()
      await _videoController!.setVolume(0.0);

      // Seamless looping — loop only resets position, NOT volume
      await _videoController!.setLooping(true);

      // Register listener BEFORE playing
      _videoController!.addListener(_onVideoPlayerUpdate);

      await _videoController!.play();

      if (mounted) {
        _safeSetState(() {
          _isPlaying = true;
          _isInitialized = true;
          _isLoading = false;
          _isMuted = true;
        });
      }
      debugPrint('[MARKETING_VIDEO] autoplay started | id: ${widget.video.id}');
    } catch (e) {
      debugPrint('[MARKETING_VIDEO] autoplay error: $e');
      if (mounted) {
        _safeSetState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Toggle play/pause on user tap (non-YouTube only).
  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      _safeSetState(() => _isPlaying = false);
    } else {
      _videoController!.play();
      _safeSetState(() => _isPlaying = true);
    }
  }

  /// Toggle mute/unmute — persists across pause/resume and loop iterations.
  void _toggleMute() {
    if (_videoController == null || !_isInitialized) return;
    final nextMuted = !_isMuted;
    _videoController!.setVolume(nextMuted ? 0.0 : 1.0);
    _safeSetState(() => _isMuted = nextMuted);
  }

  /// Handles the CTA button ("Watch Now" or custom label) tap.
  ///
  /// Behaviour:
  /// - If [ctaUrl] is a valid external URL → pause home video, open browser.
  /// - If [ctaUrl] is empty/null → "Watch Now" means play + unmute inline.
  Future<void> _handleCtaPress(String? ctaUrl) async {
    final url = ctaUrl?.trim() ?? '';

    debugPrint(
      '[MARKETING_VIDEO] Watch Now tapped'
      ' | videoId: ${widget.video.id}'
      ' | videoUrl: ${widget.video.videoUrl}'
      ' | controllerInitialized: $_isInitialized'
      ' | ctaUrl: "$url"',
    );

    if (url.isNotEmpty) {
      // Pause the inline video before handing off to external browser
      if (_videoController?.value.isPlaying == true) {
        await _videoController!.pause();
        if (mounted) _safeSetState(() => _isPlaying = false);
      }
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        // After returning from browser, resume only if section is visible
        if (mounted && widget.visibleNotifier.value && _isInitialized) {
          await _videoController?.play();
          if (mounted) _safeSetState(() => _isPlaying = true);
        }
      } catch (e) {
        debugPrint('[MARKETING_VIDEO] CTA launch error: $e');
      }
      return;
    }

    // No external URL → "Watch Now" = play + unmute inline video.
    if (!_isInitialized) {
      debugPrint('[MARKETING_VIDEO] action: trigger autoplay');
      await _startAutoplay();
      return;
    }

    if (_videoController != null) {
      if (!_videoController!.value.isPlaying) {
        debugPrint('[MARKETING_VIDEO] action: resume play');
        await _videoController!.play();
        if (mounted) _safeSetState(() => _isPlaying = true);
      }
      if (_isMuted) {
        debugPrint('[MARKETING_VIDEO] action: unmute');
        await _videoController!.setVolume(1.0);
        if (mounted) _safeSetState(() => _isMuted = false);
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 16:9 Video Container ──────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Player (direct, no thumbnail layer) ──────────────────
                  if (_isInitialized &&
                      _isYouTube &&
                      _youtubeController != null)
                    YoutubePlayer(controller: _youtubeController!)
                  else if (_isInitialized &&
                      _videoController != null &&
                      _videoController!.value.isInitialized)
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: VideoPlayer(_videoController!),
                    )
                  else
                    // Dark placeholder while video is buffering/initialising.
                    // No thumbnail — the real video appears as soon as ready.
                    _buildVideoPlaceholder(),

                  // ── Loading spinner (only during init) ────────────────────
                  if (_isLoading && !_hasError)
                    const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // ── Play button overlay (shown when paused & no error) ─────
                  if (!_isPlaying && !_hasError && !_isLoading)
                    Center(
                      child: GestureDetector(
                        onTap: _isInitialized
                            ? _togglePlayPause
                            : _startAutoplay,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Remix.play_fill,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                  // ── Inline controls (non-YouTube only) ────────────────────
                  // Mute button always visible once video is initialised.
                  if (_isInitialized &&
                      _videoController != null &&
                      !_isYouTube) ...[
                    // Mute / Unmute — top-right corner
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.60),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted
                                ? Remix.volume_mute_line
                                : Remix.volume_up_line,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // Progress bar — bottom edge
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AppVideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFF4F46E5),
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.black26,
                        ),
                      ),
                    ),
                  ],

                  // ── Error state ───────────────────────────────────────────
                  if (_hasError)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Video unavailable',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Text & CTA Section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.video.subtitle != null &&
                          widget.video.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.video.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.video.ctaText != null &&
                    widget.video.ctaText!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleCtaPress(widget.video.ctaUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.video.ctaText!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Remix.arrow_right_line, size: 14),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Icon(
          Remix.movie_2_line,
          color: Colors.white.withValues(alpha: 0.3),
          size: 40,
        ),
      ),
    );
  }
}
