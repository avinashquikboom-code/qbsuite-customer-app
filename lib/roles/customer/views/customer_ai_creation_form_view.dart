import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';
import 'customer_ai_preview_view.dart';
import '../widgets/ai_credit_top_up_modal.dart';
import '../widgets/ai_generation_loading_dialog.dart';

/// Redesigned AI Content Generation Form Screen
class CustomerAiCreationFormView extends ConsumerStatefulWidget {
  final String
  serviceType; // 'POST', 'POSTER', 'VIDEO', 'AD_COPY', 'EMAIL', 'CUSTOM'
  final String serviceTitle;
  final int creditCost;

  const CustomerAiCreationFormView({
    super.key,
    required this.serviceType,
    required this.serviceTitle,
    required this.creditCost,
  });

  @override
  ConsumerState<CustomerAiCreationFormView> createState() =>
      _CustomerAiCreationFormViewState();
}

class _CustomerAiCreationFormViewState
    extends ConsumerState<CustomerAiCreationFormView> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _ctaController = TextEditingController();
  final _customInstructionsController = TextEditingController();

  late String _currentToolType;
  late String _currentToolTitle;
  late int _currentCreditCost;

  String _objective = 'Brand Awareness';
  String _platform = 'Instagram';
  String _language = 'English';
  String _tone = 'Professional & Engaging';
  String _targetAudience = 'All Audiences';
  String _aspectRatio = '1:1 (Square)';
  String _visualStyle = 'Modern & Sleek';
  String _duration = '30s Reel';

  bool _isGenerating = false;

  final List<Map<String, dynamic>> _tools = const [
    {
      'id': 'POST',
      'title': 'Social Post',
      'credits': 1,
      'icon': Remix.file_text_line,
    },
    {
      'id': 'VIDEO',
      'title': 'Video Script',
      'credits': 5,
      'icon': Remix.video_line,
    },
    {
      'id': 'AD_COPY',
      'title': 'Ad Copy',
      'credits': 1,
      'icon': Remix.advertisement_line,
    },
    {
      'id': 'EMAIL',
      'title': 'Marketing Email',
      'credits': 1,
      'icon': Remix.mail_send_line,
    },
    {
      'id': 'POSTER',
      'title': 'AI Image',
      'credits': 2,
      'icon': Remix.image_2_line,
    },
    {
      'id': 'CAPTIONS',
      'title': 'Captions & Tags',
      'credits': 1,
      'icon': Remix.hashtag,
    },
    {
      'id': 'CUSTOM',
      'title': 'Custom Prompt',
      'credits': 1,
      'icon': Remix.magic_line,
    },
  ];

  final List<String> _objectives = const [
    'Brand Awareness',
    'Sales & Conversions',
    'Lead Generation',
    'Product Launch',
    'Flash Sale & Discount',
    'Customer Retention',
  ];

  final List<String> _platforms = const [
    'Instagram',
    'Facebook',
    'LinkedIn',
    'YouTube',
    'Twitter / X',
    'TikTok',
  ];

  final List<String> _tones = const [
    'Professional & Engaging',
    'Casual & Friendly',
    'Persuasive & Sales-Driven',
    'Energetic & Bold',
    'Luxury & Premium',
    'Urgent & Time-Sensitive',
  ];

  final List<String> _languages = const [
    'English',
    'Hindi',
    'Marathi',
    'Hinglish',
    'Spanish',
  ];

  final List<String> _audiences = const [
    'All Audiences',
    'Working Professionals',
    'Gen-Z & Youth',
    'Small Business Owners',
    'Parents & Families',
    'Fitness Enthusiasts',
  ];

  final List<String> _ctaOptions = const [
    'Order Now',
    'Sign Up Today',
    'Learn More',
    'Book a Free Demo',
    'Claim Offer',
    'DM for Details',
  ];

  @override
  void initState() {
    super.initState();
    _currentToolType = widget.serviceType;
    _currentToolTitle = widget.serviceTitle;
    _currentCreditCost = widget.creditCost;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerAiWalletProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _productController.dispose();
    _ctaController.dispose();
    _customInstructionsController.dispose();
    super.dispose();
  }

  void _switchTool(String id, String title, int credits) {
    setState(() {
      _currentToolType = id;
      _currentToolTitle = title;
      _currentCreditCost = credits;
    });
  }

  Future<void> _handleGenerate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final trimmedProduct = _productController.text.trim();
    if (trimmedProduct.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what you are promoting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var wallet = ref.read(customerAiWalletProvider).value;
    if (wallet == null) {
      await ref.read(customerAiWalletProvider.notifier).refresh();
      if (!mounted) return;
      wallet = ref.read(customerAiWalletProvider).value;
    }

    final currentBalance = wallet?.balance ?? 0;
    if (currentBalance < _currentCreditCost) {
      AppToast.error(
        context,
        'Insufficient AI credits. You need $_currentCreditCost credits, but you have $currentBalance.',
        title: 'Insufficient Credits',
      );
      showAiCreditTopUpModal(context);
      return;
    }

    setState(() => _isGenerating = true);
    final service = ref.read(customerAiStudioServiceProvider);

    // Map UI tool selection to backend payload
    String backendType = _currentToolType;
    final instructionsParts = <String>[];

    if (_currentToolType == 'AD_COPY') {
      backendType = 'POST';
      instructionsParts.add(
        'Format as high-converting Sales & Ad Copy with strong Hook, Value Proposition, Urgency, and CTA',
      );
    } else if (_currentToolType == 'EMAIL') {
      backendType = 'POST';
      instructionsParts.add(
        'Format as engaging Marketing Email with Subject Line, Preview Text, Body, and Call To Action Button',
      );
    } else if (_currentToolType == 'CUSTOM') {
      backendType = 'POST';
      instructionsParts.add('Follow custom user guidelines closely');
    } else if (_currentToolType == 'POSTER') {
      instructionsParts.add('Aspect ratio: $_aspectRatio');
      instructionsParts.add('Visual style: $_visualStyle');
    } else if (_currentToolType == 'CAPTIONS') {
      backendType = 'POST';
      instructionsParts.add(
        'Focus on generating ultra-engaging, witty captions with a high volume of viral, targeted, and trending hashtags',
      );
    } else if (_currentToolType == 'VIDEO') {
      instructionsParts.add('Duration: $_duration');
      instructionsParts.add(
        'Include Scene-by-Scene breakdown with Visuals and Voiceover lines',
      );
    }

    if (_targetAudience != 'All Audiences') {
      instructionsParts.add('Target Audience: $_targetAudience');
    }

    final userCustomText = _customInstructionsController.text.trim();
    if (userCustomText.isNotEmpty) {
      instructionsParts.add(userCustomText);
    }

    final combinedInstructions = instructionsParts.isNotEmpty
        ? instructionsParts.join('. ')
        : null;

    final effectiveCta = _ctaController.text.trim().isNotEmpty
        ? _ctaController.text.trim()
        : null;

    // ValueNotifier for streaming status updates to the loading dialog
    final statusNotifier = ValueNotifier<String>(
      'Starting generation with AI...',
    );
    bool dialogOpen = false;

    try {
      // Show the animated modal using user-selected tool type
      AiGenerationLoadingDialog.show(
        context,
        generatorType: _currentToolType,
        statusNotifier: statusNotifier,
      );
      dialogOpen = true;

      statusNotifier.value = _currentToolType == 'VIDEO'
          ? 'Contacting Gemini video generation engine...'
          : _currentToolType == 'POSTER'
          ? 'Sending prompt to OpenAI DALL-E...'
          : _currentToolType == 'CAPTIONS'
          ? 'AI is writing viral captions & trending tags...'
          : 'AI is crafting your creative copy...';

      final gen = await service.generateContent(
        type: backendType,
        product: trimmedProduct,
        objective: _objective.trim().isNotEmpty ? _objective.trim() : null,
        targetAudience: _targetAudience != 'All Audiences'
            ? _targetAudience
            : null,
        platform: _platform.trim().isNotEmpty ? _platform.trim() : null,
        language: _language.trim().isNotEmpty ? _language.trim() : null,
        tone: _tone.trim().isNotEmpty ? _tone.trim() : null,
        cta: effectiveCta,
        instructions: combinedInstructions,
      );

      if (gen != null) {
        AiGenerationModel finalGen = gen;
        if (finalGen.status.toUpperCase() == 'PROCESSING' ||
            finalGen.status.toUpperCase() == 'PENDING') {
          final genId = finalGen.generationId.isNotEmpty
              ? finalGen.generationId
              : finalGen.id.toString();

          statusNotifier.value = backendType == 'VIDEO'
              ? 'Gemini is rendering video scenes & audio...'
              : 'Processing output with AI backend...';

          for (int i = 0; i < 25; i++) {
            await Future.delayed(const Duration(seconds: 2));
            if (!mounted) break;

            if (backendType == 'VIDEO') {
              if (i == 4) {
                statusNotifier.value =
                    'Rendering frames & visual transitions...';
              } else if (i == 9) {
                statusNotifier.value =
                    'Synthesizing voiceover & audio tracks...';
              } else if (i == 14) {
                statusNotifier.value = 'Finalizing video output & encoding...';
              } else if (i >= 18) {
                statusNotifier.value = 'Almost ready! Packaging final reel...';
              }
            }

            final updated = await service.fetchGenerationDetails(genId);
            if (updated != null) {
              finalGen = updated;
              if (updated.status.toUpperCase() == 'COMPLETED' ||
                  updated.status.toUpperCase() == 'FAILED') {
                break;
              }
            }
          }
        }

        if (finalGen.status.toUpperCase() == 'FAILED') {
          throw ApiException(
            message:
                'AI generation failed during processing. Please try again.',
          );
        }

        statusNotifier.value = 'Content ready! Loading preview...';

        ref
            .read(customerAiGenerationsProvider.notifier)
            .addGeneration(finalGen);
        await ref.read(customerAiWalletProvider.notifier).refresh();

        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogOpen = false;
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerAiPreviewView(generation: finalGen),
            ),
          );
        }
      } else {
        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogOpen = false;
        }
      }
    } catch (e) {
      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Content generation failed. Please try again.';
        if (e is ApiException && e.isInsufficientCredits) {
          AppToast.error(context, message, title: 'Insufficient Credits');
          showAiCreditTopUpModal(context);
        } else {
          AppToast.error(context, message, title: 'Generation Failed');
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(customerAiWalletProvider).value;
    final balance = wallet?.balance ?? 0;
    final hasEnoughCredits = balance >= _currentCreditCost;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentToolTitle,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Cost: $_currentCreditCost Credit${_currentCreditCost > 1 ? 's' : ''}',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => showAiCreditTopUpModal(context),
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasEnoughCredits
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasEnoughCredits
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Remix.copper_coin_line,
                    size: 14,
                    color: hasEnoughCredits
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$balance cr',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasEnoughCredits
                          ? const Color(0xFF065F46)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Remix.add_circle_fill,
                    size: 12,
                    color: hasEnoughCredits
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Tool Selector Pill Bar at Top
            _buildToolSelectorBar(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credit Cost & Balance Card
                    _buildCreditPreviewCard(balance, hasEnoughCredits),

                    const SizedBox(height: 16),

                    // Topic / Product / Brand Name Input
                    _buildSectionHeader(
                      'Topic, Product or Offer',
                      subtitle: 'What do you want this AI content to promote?',
                      requiredField: true,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _productController,
                      maxLines: 3,
                      minLines: 2,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Summer Flat 30% Off sale on Organic Green Tea. Mention fast delivery & natural antioxidants.',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a product or topic description';
                        }
                        if (val.trim().length < 5) {
                          return 'Description must be at least 5 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Campaign Objective
                    _buildSectionHeader('Campaign Objective'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _objective,
                      items: _objectives,
                      onChanged: (val) => setState(() => _objective = val!),
                    ),

                    const SizedBox(height: 18),

                    // Target Audience Chips
                    _buildSectionHeader('Target Audience'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _audiences.map((aud) {
                        final isSel = _targetAudience == aud;
                        return ChoiceChip(
                          label: Text(aud),
                          selected: isSel,
                          onSelected: (_) =>
                              setState(() => _targetAudience = aud),
                          selectedColor: const Color(0xFFEEF2FF),
                          backgroundColor: const Color(0xFFF8FAFC),
                          labelStyle: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF475569),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Two Column Row: Platform & Language
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Platform'),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _platform,
                                items: _platforms,
                                onChanged: (val) =>
                                    setState(() => _platform = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Language'),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _language,
                                items: _languages,
                                onChanged: (val) =>
                                    setState(() => _language = val!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Tone of Voice
                    _buildSectionHeader('Tone of Voice'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _tone,
                      items: _tones,
                      onChanged: (val) => setState(() => _tone = val!),
                    ),

                    const SizedBox(height: 18),

                    // Tool-specific fields
                    if (_currentToolType == 'POSTER') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Aspect Ratio'),
                                const SizedBox(height: 8),
                                _buildDropdown(
                                  value: _aspectRatio,
                                  items: const [
                                    '1:1 (Square)',
                                    '9:16 (Story/Reel)',
                                    '16:9 (Landscape)',
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _aspectRatio = val!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Visual Style'),
                                const SizedBox(height: 8),
                                _buildDropdown(
                                  value: _visualStyle,
                                  items: const [
                                    'Modern & Sleek',
                                    'Minimalist',
                                    'Vibrant & Bold',
                                    'Photorealistic',
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _visualStyle = val!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ] else if (_currentToolType == 'VIDEO') ...[
                      _buildSectionHeader('Video Reel Duration'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _duration,
                        items: const [
                          '15s Reel / Short',
                          '30s Reel',
                          '60s Explainer',
                        ],
                        onChanged: (val) => setState(() => _duration = val!),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Call to Action (CTA)
                    _buildSectionHeader(
                      'Call to Action (Optional)',
                      subtitle: 'Choose an action prompt or write custom',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _ctaOptions.map((cta) {
                        final isSel = _ctaController.text == cta;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _ctaController.text = isSel ? '' : cta;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              cta,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ctaController,
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Or enter custom CTA (e.g. Claim 50% Off Now)',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Custom Instructions / Prompt Input
                    _buildSectionHeader(
                      'Custom Prompt / Extra Instructions (Optional)',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customInstructionsController,
                      maxLines: 3,
                      minLines: 2,
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Include emoji accents, mention free shipping over ₹499, and include a strong hook in the first sentence.',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Generate Action Bar
            _buildBottomActionBar(balance, hasEnoughCredits),
          ],
        ),
      ),
    );
  }

  Widget _buildToolSelectorBar() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _tools.map((t) {
            final isSel = _currentToolType == t['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _switchTool(t['id'], t['title'], t['credits']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t['icon'] as IconData,
                        size: 14,
                        color: isSel ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t['title'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${t['credits']}c',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSel
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCreditPreviewCard(int balance, bool hasEnough) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasEnough ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasEnough ? const Color(0xFFC7D2FE) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasEnough ? Icons.auto_awesome : Remix.alert_line,
            size: 18,
            color: hasEnough
                ? const Color(0xFF4F46E5)
                : const Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasEnough
                      ? 'Requires $_currentCreditCost Credit${_currentCreditCost > 1 ? 's' : ''} (Balance: $balance)'
                      : 'Insufficient Credits: Needs $_currentCreditCost, you have $balance',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasEnough
                        ? const Color(0xFF3730A3)
                        : const Color(0xFF92400E),
                  ),
                ),
                Text(
                  hasEnough
                      ? 'Credits are deducted only upon successful generation.'
                      : 'Recharge your wallet to run this generation model.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: hasEnough
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          if (!hasEnough)
            TextButton(
              onPressed: () => showAiCreditTopUpModal(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Top-Up',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? subtitle,
    bool requiredField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (requiredField)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(
            Remix.arrow_down_s_line,
            color: Color(0xFF64748B),
            size: 18,
          ),
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          items: items.map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(int balance, bool hasEnough) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: (_isGenerating || !hasEnough) ? null : _handleGenerate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: const Color(0xFF94A3B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isGenerating
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '✨ Creating...',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasEnough
                            ? '✨ Generate ${_getGenerateButtonNoun()} • $_currentCreditCost Credit${_currentCreditCost > 1 ? 's' : ''}'
                            : 'Insufficient Credits (Recharge to Generate)',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _getGenerateButtonNoun() {
    switch (_currentToolType.toUpperCase()) {
      case 'POST':
        return 'Post';
      case 'POSTER':
        return 'Poster';
      case 'VIDEO':
        return 'Video';
      case 'CAPTIONS':
        return 'Captions';
      case 'AD_COPY':
        return 'Ad Copy';
      case 'EMAIL':
        return 'Email';
      default:
        return 'Content';
    }
  }
}
