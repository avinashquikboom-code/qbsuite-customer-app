import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_video_progress_indicator.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';
import '../utils/media_share_util.dart';
import 'customer_social_publish_dialog.dart';
import 'customer_social_connect_modal.dart';
import 'customer_ai_creation_form_view.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';

/// Generation Output screen.
///
/// Shows:
///  - Actual generated image (with loading + error states)
///  - Actual generated video with play/pause, mute, progress (video_player)
///  - Generated caption + hashtags
///
/// Two share paths:
///  - Appbar icon → native OS share sheet (share_plus) — NEW
///  - "Publish to Social Media" button → OAuth backend publish — UNCHANGED
class CustomerAiPreviewView extends ConsumerStatefulWidget {
  final AiGenerationModel generation;

  const CustomerAiPreviewView({super.key, required this.generation});

  @override
  ConsumerState<CustomerAiPreviewView> createState() =>
      _CustomerAiPreviewViewState();
}

class _CustomerAiPreviewViewState extends ConsumerState<CustomerAiPreviewView> {
  // ── Generation State ──────────────────────────────────────────────────────
  late AiGenerationModel _gen;
  bool _isPolling = false;

  // ── Video player ──────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  bool _videoMuted = false;

  // ── Native share state ────────────────────────────────────────────────────
  bool _isSharing = false;
  double _shareDownloadProgress = 0;
  bool _isBookmarked = false;

  // ── Computed helpers ──────────────────────────────────────────────────────

  String? get _mediaUrl => _gen.effectiveMediaUrl;

  bool get _hasMedia => _mediaUrl != null && _mediaUrl!.isNotEmpty;

  bool get _isSvg {
    if (!_hasMedia) return false;
    final lower = _mediaUrl!.toLowerCase();
    return lower.endsWith('.svg') ||
        lower.contains('.svg?') ||
        lower.startsWith('data:image/svg');
  }

  bool get _isVideo {
    final type = _gen.type.toUpperCase();
    final mt = (_gen.mediaType ?? '').toLowerCase();
    final url = (_mediaUrl ?? '').toLowerCase();
    return type == 'VIDEO' ||
        mt.contains('video') ||
        mt.contains('mp4') ||
        mt.contains('mov') ||
        url.contains('.mp4') ||
        url.contains('.mov');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _gen = widget.generation;
    if (_hasMedia && _isVideo) _initVideoPlayer();

    if (_gen.status.toUpperCase() == 'PROCESSING' ||
        _gen.status.toUpperCase() == 'PENDING') {
      _pollStatus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(customerSocialAccountsProvider.notifier).refresh();
      final accounts = ref.read(customerSocialAccountsProvider).value ?? [];
      var selected = ref.read(selectedSocialAccountProvider);
      if (selected == null && accounts.isNotEmpty) {
        final match = accounts.where(
          (a) =>
              a.platform.toUpperCase() == (_gen.platform?.toUpperCase() ?? ''),
        );
        selected = match.isNotEmpty ? match.first : accounts.first;
        ref
            .read(selectedSocialAccountProvider.notifier)
            .selectAccount(selected);
      }
    });
  }

  Future<void> _pollStatus() async {
    if (_isPolling) return;
    setState(() => _isPolling = true);
    final service = ref.read(customerAiStudioServiceProvider);
    final genId = _gen.generationId.isNotEmpty
        ? _gen.generationId
        : _gen.id.toString();

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) break;
      final updated = await service.fetchGenerationDetails(genId);
      if (updated != null) {
        setState(() {
          _gen = updated;
        });
        if (updated.status.toUpperCase() == 'COMPLETED') {
          if (_isVideo && !_videoInitialized) {
            _initVideoPlayer();
          }
          break;
        } else if (updated.status.toUpperCase() == 'FAILED') {
          break;
        }
      }
    }
    if (mounted) setState(() => _isPolling = false);
  }

  Future<void> _initVideoPlayer() async {
    final url = _mediaUrl;
    if (url == null || url.isEmpty) return;

    debugPrint(
      '[AI_GENERATION_FLUTTER] Initializing video player with url: $url',
    );
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = ctrl;
      await ctrl.initialize();
      if (mounted) {
        setState(() => _videoInitialized = true);
        ctrl.setLooping(true);
        ctrl.play();
      }
    } catch (e) {
      debugPrint('[VIDEO_INIT_ERROR] $e');
      if (mounted) setState(() => _videoError = true);
    }
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
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllText(BuildContext context) {
    final buffer = StringBuffer();
    if (widget.generation.caption != null &&
        widget.generation.caption!.trim().isNotEmpty) {
      buffer.writeln(widget.generation.caption!.trim());
    }
    if (widget.generation.hashtags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(widget.generation.hashtags.join(' '));
    }
    _copyToClipboard(context, buffer.toString().trim(), 'All Content');
  }

  void _showFullscreenImage(BuildContext context) {
    final url = _mediaUrl;
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Regenerate Content?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'This will open the creator form to generate a fresh variation using ${widget.generation.creditsSpent} credit(s).',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerAiCreationFormView(
            serviceType: widget.generation.type,
            serviceTitle: 'Regenerate ${widget.generation.type}',
            creditCost: widget.generation.creditsSpent,
          ),
        ),
      );
    }
  }

  void _openPublishDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          CustomerSocialPublishDialog(generation: widget.generation),
    );
  }

  void _openConnectThenPublish(BuildContext context) {
    showModalBottomSheet<SocialAccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerSocialConnectModal(
        initialPlatform: widget.generation.platform,
      ),
    ).then((newAcc) {
      if (newAcc != null && mounted) {
        // ignore: use_build_context_synchronously
        _openPublishDialog(context);
      }
    });
  }

  /// Native OS share — downloads to temp file, invokes the OS share sheet.
  Future<void> _handleNativeShare(BuildContext context) async {
    if (_isSharing) return;

    final caption = [
      widget.generation.caption ?? '',
      widget.generation.hashtags.join(' '),
    ].where((s) => s.isNotEmpty).join('\n\n');

    final shareUrl = _mediaUrl;

    // Caption-only share when no media URL
    if (!_hasMedia || shareUrl == null || shareUrl.isEmpty) {
      if (caption.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to share.')));
        return;
      }
      await SharePlus.instance.share(ShareParams(text: caption));
      return;
    }

    setState(() {
      _isSharing = true;
      _shareDownloadProgress = 0;
    });

    await MediaShareUtil.shareMedia(
      context: context,
      mediaUrl: shareUrl,
      caption: caption.isNotEmpty ? caption : null,
      mediaType: widget.generation.mediaType,
      onProgress: (p) {
        if (mounted) setState(() => _shareDownloadProgress = p);
      },
    );

    if (mounted) setState(() => _isSharing = false);
  }

  void _togglePlayPause() {
    final ctrl = _videoController;
    if (ctrl == null || !_videoInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    _safeSetState(() {});
  }

  void _toggleMute() {
    final ctrl = _videoController;
    if (ctrl == null) return;
    _videoMuted = !_videoMuted;
    ctrl.setVolume(_videoMuted ? 0 : 1);
    _safeSetState(() {});
  }

  Future<void> _retryVideo() async {
    _videoController?.dispose();
    _videoController = null;
    _safeSetState(() {
      _videoInitialized = false;
      _videoError = false;
    });
    await _initVideoPlayer();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Generation Output',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Remix.bookmark_fill : Remix.bookmark_line,
              color: _isBookmarked
                  ? AppColors.primary
                  : const Color(0xFF64748B),
              size: 20,
            ),
            tooltip: _isBookmarked ? 'Bookmarked' : 'Bookmark',
            onPressed: () {
              setState(() => _isBookmarked = !_isBookmarked);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isBookmarked
                        ? 'Saved to Bookmarks'
                        : 'Removed from Bookmarks',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          if (_hasMedia || (widget.generation.caption?.isNotEmpty ?? false))
            _isSharing
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                          value: _shareDownloadProgress > 0
                              ? _shareDownloadProgress
                              : null,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Remix.share_line,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'Share via installed apps',
                    onPressed: () => _handleNativeShare(context),
                  ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_isPolling ||
                            _gen.status.toUpperCase() == 'PROCESSING')
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (_isPolling ||
                              _gen.status.toUpperCase() == 'PROCESSING')
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                          : const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isPolling ||
                          _gen.status.toUpperCase() == 'PROCESSING') ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rendering Video...',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready to Publish',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _gen.generationId,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Media preview
            if (_hasMedia) ...[
              _isVideo ? _buildVideoPlayer() : _buildImagePreview(),
              const SizedBox(height: 14),
            ],

            // Share download progress banner
            if (_isSharing) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                        value: _shareDownloadProgress > 0
                            ? _shareDownloadProgress
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _shareDownloadProgress > 0
                            ? 'Preparing to share… ${(_shareDownloadProgress * 100).toStringAsFixed(0)}%'
                            : 'Preparing to share…',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Caption
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _gen.type.toUpperCase() == 'VIDEO'
                              ? 'Generated Video Script & Breakdown'
                              : 'Generated Copy / Caption',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _copyToClipboard(
                          context,
                          _gen.caption ?? '',
                          'Caption',
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Remix.file_copy_line,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _gen.caption ?? 'No caption generated.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.5,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Hashtags
            if (_gen.hashtags.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Trending Hashtags',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _copyToClipboard(
                            context,
                            _gen.hashtags.join(' '),
                            'Hashtags',
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Remix.file_copy_line,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy All',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _gen.hashtags.map((tag) {
                        return GestureDetector(
                          onTap: () => _copyToClipboard(context, tag, tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Remix.share_circle_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      'Publish to Social Media',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () {
                      final accounts =
                          ref.read(customerSocialAccountsProvider).value ?? [];
                      if (accounts.isEmpty) {
                        _openConnectThenPublish(context);
                      } else {
                        _openPublishDialog(context);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyAllText(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(
                          Remix.file_copy_line,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                        label: Text(
                          'Copy All Text',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleRegenerate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          backgroundColor: const Color(0xFFEEF2FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(
                          Remix.refresh_line,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                        label: Text(
                          'Regenerate',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Image preview widget ──────────────────────────────────────────────────

  Widget _buildImagePreview() {
    final url = _mediaUrl;
    if (url == null || url.isEmpty) {
      return _buildImageError('No image URL available');
    }

    Widget content;
    if (_isSvg) {
      if (url.startsWith('data:image/svg')) {
        try {
          final commaIndex = url.indexOf(',');
          final raw = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
          final isBase64 = url.contains(';base64,');
          final svgString = isBase64
              ? utf8.decode(base64Decode(raw))
              : Uri.decodeComponent(raw);
          content = SvgPicture.string(
            svgString,
            fit: BoxFit.contain,
            placeholderBuilder: (ctx) => _buildLoadingPlaceholder(),
          );
        } catch (e) {
          debugPrint('[SVG_PARSE_ERROR] $e');
          content = _buildImageError('Could not parse SVG vector data.');
        }
      } else {
        content = SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (ctx) => _buildLoadingPlaceholder(),
        );
      }
    } else {
      content = Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final progress = total != null
              ? loadingProgress.cumulativeBytesLoaded / total
              : null;
          return _buildLoadingPlaceholder(progress: progress);
        },
        errorBuilder: (context, error, _) {
          debugPrint('[IMAGE_LOAD_ERROR] $error');
          return _buildImageError('Could not load generated image.');
        },
      );
    }

    return GestureDetector(
      onTap: () => _showFullscreenImage(context),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Remix.zoom_in_line, color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to zoom',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _buildLoadingPlaceholder({double? progress}) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 12),
            Text(
              progress != null
                  ? 'Loading… ${(progress * 100).toStringAsFixed(0)}%'
                  : 'Loading image…',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError(String message) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Remix.image_2_line, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(
                Remix.refresh_line,
                size: 14,
                color: AppColors.primary,
              ),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Video player widget ───────────────────────────────────────────────────

  Widget _buildVideoPlayer() {
    if (_videoError) return _buildVideoError();
    if (!_videoInitialized || _videoController == null) {
      return _buildVideoLoading();
    }

    final ctrl = _videoController!;
    final ar = ctrl.value.aspectRatio;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: AspectRatio(
                aspectRatio: ar > 0 ? ar : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(ctrl),
                    AnimatedOpacity(
                      opacity: ctrl.value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      ctrl.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppVideoProgressIndicator(
                      ctrl,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primary,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _videoMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleMute,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLoading() => Container(
    height: 220,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading video…',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    ),
  );

  Widget _buildVideoError() => Container(
    height: 220,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Remix.video_off_line, size: 40, color: Colors.white54),
          const SizedBox(height: 10),
          Text(
            'Could not load video.',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _retryVideo,
            icon: const Icon(
              Remix.refresh_line,
              size: 14,
              color: AppColors.primary,
            ),
            label: Text(
              'Retry',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
