import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';

/// Dynamic status details for each generator type
class AiGeneratorMeta {
  final String title;
  final String defaultSubtitle;
  final String processingSubtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;

  const AiGeneratorMeta({
    required this.title,
    required this.defaultSubtitle,
    required this.processingSubtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
  });

  static AiGeneratorMeta getForType(String type) {
    switch (type.toUpperCase()) {
      case 'POST':
      case 'AD_COPY':
      case 'EMAIL':
      case 'CUSTOM':
        return const AiGeneratorMeta(
          title: 'Creating your social post...',
          defaultSubtitle: 'AI is crafting your copy & hashtags...',
          processingSubtitle: 'Polishing message & optimizing engagement...',
          icon: Remix.file_text_line,
          gradient: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
          glowColor: Color(0xFF6366F1),
        );
      case 'POSTER':
      case 'IMAGE':
        return const AiGeneratorMeta(
          title: 'Creating your poster...',
          defaultSubtitle: 'OpenAI DALL-E is designing your image...',
          processingSubtitle:
              'Rendering textures, lighting & uploading to S3...',
          icon: Remix.image_2_line,
          gradient: [Color(0xFF9333EA), Color(0xFFA855F7), Color(0xFFC084FC)],
          glowColor: Color(0xFFA855F7),
        );
      case 'VIDEO':
      case 'REEL':
        return const AiGeneratorMeta(
          title: 'Creating your reel...',
          defaultSubtitle: 'Gemini is generating your video...',
          processingSubtitle: 'Rendering visual frames, animation & audio...',
          icon: Remix.video_line,
          gradient: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
          glowColor: Color(0xFFEF4444),
        );
      case 'CAPTIONS':
      case 'TAGS':
        return const AiGeneratorMeta(
          title: 'Creating captions & hashtags...',
          defaultSubtitle: 'AI is writing your content & trending tags...',
          processingSubtitle: 'Optimizing reach and viral hashtags...',
          icon: Remix.hashtag,
          gradient: [Color(0xFF0D9488), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
          glowColor: Color(0xFF14B8A6),
        );
      default:
        return const AiGeneratorMeta(
          title: 'Creating with AI...',
          defaultSubtitle: 'AI is crafting your content...',
          processingSubtitle: 'Finalizing and verifying results...',
          icon: Remix.sparkling_2_line,
          gradient: [Color(0xFF4F46E5), Color(0xFF23C45E), Color(0xFF0EA5E9)],
          glowColor: Color(0xFF23C45E),
        );
    }
  }
}

/// Premium AI Generation Loading Modal with glowing pulse, rotating sparkles,
/// and live request/processing state.
class AiGenerationLoadingDialog extends StatefulWidget {
  final String generatorType;
  final ValueNotifier<String>? statusNotifier;

  const AiGenerationLoadingDialog({
    super.key,
    required this.generatorType,
    this.statusNotifier,
  });

  static Future<void> show(
    BuildContext context, {
    required String generatorType,
    ValueNotifier<String>? statusNotifier,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => PopScope(
        canPop: false,
        child: AiGenerationLoadingDialog(
          generatorType: generatorType,
          statusNotifier: statusNotifier,
        ),
      ),
    );
  }

  @override
  State<AiGenerationLoadingDialog> createState() =>
      _AiGenerationLoadingDialogState();
}

class _AiGenerationLoadingDialogState extends State<AiGenerationLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for central orb
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 12.0, end: 28.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Continuous 360 rotation for outer sparkles/ring
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Continuous shimmer for progress bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = AiGeneratorMeta.getForType(widget.generatorType);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Premium dark slate background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: meta.glowColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: meta.glowColor.withValues(alpha: 0.25),
                blurRadius: 36,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Magic Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      meta.glowColor.withValues(alpha: 0.25),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: meta.glowColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFBBF24), // Gold sparkle
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CREATING WITH AI',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Animated Glowing AI Centerpiece
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating sparkle ring
                    RotationTransition(
                      turns: _rotateController,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: meta.glowColor.withValues(alpha: 0.3),
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 2,
                              left: 60,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: meta.glowColor,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 58,
                              child: const Icon(
                                Remix.sparkling_2_fill,
                                size: 12,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Glowing pulsing orb
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: meta.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: meta.glowColor.withValues(alpha: 0.6),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                meta.icon,
                                size: 38,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Central micro-sparkle badge
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Generator-specific Title
              Text(
                meta.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 8),

              // Dynamic live status subtitle
              if (widget.statusNotifier != null)
                ValueListenableBuilder<String>(
                  valueListenable: widget.statusNotifier!,
                  builder: (context, status, _) {
                    final displaySubtitle = status.isNotEmpty
                        ? status
                        : meta.defaultSubtitle;

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        displaySubtitle,
                        key: ValueKey<String>(displaySubtitle),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8), // Slate 400
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                )
              else
                Text(
                  meta.defaultSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),

              const SizedBox(height: 22),

              // Animated Shimmer Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 6,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFF1E293B)),
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment(
                              -1.0 + (_shimmerController.value * 2.0),
                              0.0,
                            ),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    meta.glowColor,
                                    Colors.white,
                                    meta.glowColor,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Realtime Note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generating via official AI backend...',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
