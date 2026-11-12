import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_video_progress_indicator.dart';
import '../models/trending_content.dart';

/// Full-screen in-app Reels / TikTok-style vertical video feed viewer.
/// Plays MP4 / S3 presigned videos using `video_player` and YouTube videos using `youtube_player_iframe`.
/// Supports vertical swiping (`PageView.builder`), autoplay, pause on swipe, progress bar, mute toggle, and back navigation.
class ReelsStyleVideoFeedView extends StatefulWidget {
  final List<TrendingContent> videos;
  final int initialIndex;

  const ReelsStyleVideoFeedView({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<ReelsStyleVideoFeedView> createState() =>
      _ReelsStyleVideoFeedViewState();
}

class _ReelsStyleVideoFeedViewState extends State<ReelsStyleVideoFeedView> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.videos.isEmpty ? 0 : widget.videos.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleGlobalMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'No trending videos available',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // 1. Vertical PageView Feed
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = widget.videos[index];
                final isCurrent = index == _currentIndex;

                return _ReelVideoItemPlayer(
                  key: ValueKey('reel_item_${item.id}_$index'),
                  item: item,
                  isActive: isCurrent,
                  isMuted: _isMuted,
                  onToggleMute: _toggleGlobalMute,
                );
              },
            ),

            // 2. Top Header Floating Controls
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / Close Button
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Center(
                        child: IconTheme(
                          data: IconThemeData(color: Colors.white, size: 20),
                          child: BackButtonIcon(),
                        ),
                      ),
                    ),
                  ),

                  // Feed Position Counter & Category Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.videos.length}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mute / Unmute Button
                      GestureDetector(
                        onTap: _toggleGlobalMute,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Icon(
                            _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single Reel Video Player Item with autoplay and controller lifecycle management.
class _ReelVideoItemPlayer extends StatefulWidget {
  final TrendingContent item;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const _ReelVideoItemPlayer({
    super.key,
    required this.item,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<_ReelVideoItemPlayer> createState() => _ReelVideoItemPlayerState();
}

class _ReelVideoItemPlayerState extends State<_ReelVideoItemPlayer> {
  // Direct Video Player (MP4 / S3 presigned)
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;
  bool _isPlaying = true;
  bool _showPlayPauseOverlay = false;
  Timer? _overlayTimer;

  // YouTube Player
  YoutubePlayerController? _youtubeController;
  bool _isYouTubeInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
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

  @override
  void didUpdateWidget(_ReelVideoItemPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      final shouldPlay = widget.isActive;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (shouldPlay) {
          _play();
        } else {
          _pause();
        }
      });
    }

    if (oldWidget.isMuted != widget.isMuted) {
      final mute = widget.isMuted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyMute(mute);
      });
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _videoController?.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  void _setupPlayer() {
    final youTubeId = widget.item.youTubeVideoId;

    if (youTubeId != null && youTubeId.isNotEmpty) {
      // Setup in-app YouTube Player using youtube_player_iframe
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: youTubeId,
        autoPlay: widget.isActive,
        params: YoutubePlayerParams(
          mute: widget.isMuted,
          showControls: true,
          showFullscreenButton: false,
          loop: true,
        ),
      );
      _isYouTubeInitialized = true;
    } else {
      // Setup Native Video Player (MP4 / S3 URL)
      final url = widget.item.playOrTargetUrl;
      if (url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize()
              .then((_) {
                if (mounted) {
                  _safeSetState(() {
                    _isVideoInitialized = true;
                    _isVideoError = false;
                  });
                  _videoController?.setLooping(true);
                  _videoController?.setVolume(widget.isMuted ? 0.0 : 1.0);
                  if (widget.isActive) {
                    _videoController?.play();
                    _isPlaying = true;
                  }
                }
              })
              .catchError((err) {
                debugPrint('[REEL_VIDEO_ERROR] Could not load video: $err');
                if (mounted) {
                  _safeSetState(() {
                    _isVideoError = true;
                    _isVideoInitialized = false;
                  });
                }
              });
      } else {
        _isVideoError = true;
      }
    }
  }

  void _play() {
    if (_videoController != null && _isVideoInitialized) {
      _videoController?.play();
      _safeSetState(() => _isPlaying = true);
    }
    if (_youtubeController != null && _isYouTubeInitialized) {
      _youtubeController?.playVideo();
      _safeSetState(() => _isPlaying = true);
    }
  }

  void _pause() {
    if (_videoController != null && _isVideoInitialized) {
      _videoController?.pause();
      _safeSetState(() => _isPlaying = false);
    }
    if (_youtubeController != null && _isYouTubeInitialized) {
      _youtubeController?.pauseVideo();
      _safeSetState(() => _isPlaying = false);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }

    setState(() {
      _showPlayPauseOverlay = true;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showPlayPauseOverlay = false;
        });
      }
    });
  }

  void _applyMute(bool muted) {
    if (_videoController != null && _isVideoInitialized) {
      _videoController?.setVolume(muted ? 0.0 : 1.0);
    }
    if (_youtubeController != null && _isYouTubeInitialized) {
      if (muted) {
        _youtubeController?.mute();
      } else {
        _youtubeController?.unMute();
      }
    }
  }

  Future<void> _handleCtaAction(String? ctaUrl) async {
    if (ctaUrl == null || ctaUrl.trim().isEmpty) return;
    try {
      final uri = Uri.parse(ctaUrl.trim());
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final item = widget.item;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size.width,
        height: size.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Layer (Centered 9:16 or aspect fill)
            Center(child: _buildVideoSurface()),

            // 2. Play / Pause animated center pulse indicator
            if (_showPlayPauseOverlay)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),

            // 3. Bottom Gradient Scrim & Info Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 60,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category & Platform Tag
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF23C45E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.category.emoji,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.category.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.platform.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (item.formattedDateOnly.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      item.formattedDateOnly,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),

                    // Description / Subtitle
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // CTA Button if ctaUrl exists
                    if (item.ctaUrl != null && item.ctaUrl!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleCtaAction(item.ctaUrl),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                          label: Text(
                            item.ctaText?.isNotEmpty == true
                                ? item.ctaText!
                                : 'Learn More',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF23C45E),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    // Video Scrubbing Progress Bar & Realtime Timestamp for Direct Videos
                    if (_videoController != null && _isVideoInitialized) ...[
                      const SizedBox(height: 12),
                      _ReelVideoProgressWithTimestamp(
                        controller: _videoController!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSurface() {
    // 1. YouTube Player
    if (_youtubeController != null && _isYouTubeInitialized) {
      return YoutubePlayer(
        controller: _youtubeController!,
        aspectRatio: 9 / 16,
      );
    }

    // 2. Direct Video Player
    if (_videoController != null && _isVideoInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio > 0
            ? _videoController!.value.aspectRatio
            : 9 / 16,
        child: VideoPlayer(_videoController!),
      );
    }

    // 3. Fallback / Loading / Thumbnail Image Preview
    if (!_isVideoError) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.item.effectiveThumbnailUrl.isNotEmpty)
            Image.network(widget.item.effectiveThumbnailUrl, fit: BoxFit.cover),
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF23C45E)),
            ),
          ),
        ],
      );
    }

    // 4. Video Error State
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to play video',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.item.effectiveThumbnailUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.item.effectiveThumbnailUrl,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper to format video duration into `mm:ss` or `hh:mm:ss`
String _formatVideoDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    final hoursStr = hours.toString().padLeft(2, '0');
    return '$hoursStr:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

/// Localized video progress and timestamp widget.
/// Only rebuilds this specific control area upon position updates without rebuilding the whole screen.
class _ReelVideoProgressWithTimestamp extends StatelessWidget {
  final VideoPlayerController controller;

  const _ReelVideoProgressWithTimestamp({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppVideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: Color(0xFF23C45E),
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (!value.isInitialized) return const SizedBox.shrink();

            final position = value.position;
            final duration = value.duration;
            final posFormatted = _formatVideoDuration(position);
            final durFormatted = _formatVideoDuration(duration);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$posFormatted / $durFormatted',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (value.isBuffering)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF23C45E),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
