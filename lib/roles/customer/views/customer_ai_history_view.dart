import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../models/ai_studio_model.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';
import 'customer_ai_preview_view.dart';

class CustomerAiHistoryView extends ConsumerStatefulWidget {
  const CustomerAiHistoryView({super.key});

  @override
  ConsumerState<CustomerAiHistoryView> createState() =>
      _CustomerAiHistoryViewState();
}

class _CustomerAiHistoryViewState extends ConsumerState<CustomerAiHistoryView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'ALL'; // ALL, POST, VIDEO, AD_COPY, EMAIL, POSTER
  String _selectedStatus = 'ALL'; // ALL, COMPLETED, PROCESSING, FAILED

  final List<Map<String, String>> _toolTypes = const [
    {'id': 'ALL', 'label': 'All Tools'},
    {'id': 'POST', 'label': 'Social Posts'},
    {'id': 'VIDEO', 'label': 'Video Scripts'},
    {'id': 'POSTER', 'label': 'AI Images'},
    {'id': 'AD_COPY', 'label': 'Ad Copy'},
    {'id': 'EMAIL', 'label': 'Emails'},
    {'id': 'CAPTION', 'label': 'Captions'},
  ];

  final List<Map<String, String>> _statusFilters = const [
    {'id': 'ALL', 'label': 'All Status'},
    {'id': 'COMPLETED', 'label': 'Completed'},
    {'id': 'PROCESSING', 'label': 'Processing'},
    {'id': 'FAILED', 'label': 'Failed'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerAiGenerationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m, $h:$min';
  }

  bool _matchesFilter(AiGenerationModel gen) {
    // Type match
    if (_selectedType != 'ALL') {
      final genType = gen.type.toUpperCase();
      final obj = (gen.objective ?? '').toUpperCase();
      final cta = (gen.cta ?? '').toUpperCase();
      final product = gen.product.toUpperCase();

      if (_selectedType == 'POSTER') {
        if (genType != 'POSTER') return false;
      } else if (_selectedType == 'VIDEO') {
        if (genType != 'VIDEO') return false;
      } else if (_selectedType == 'AD_COPY') {
        final isAd =
            obj.contains('AD') ||
            product.contains('AD') ||
            cta.contains('BUY') ||
            cta.contains('ORDER');
        if (!isAd && genType != 'AD_COPY') return false;
      } else if (_selectedType == 'EMAIL') {
        final isEmail =
            obj.contains('EMAIL') ||
            product.contains('EMAIL') ||
            genType == 'EMAIL';
        if (!isEmail) return false;
      } else if (_selectedType == 'CAPTION') {
        if (genType != 'CAPTION' && genType != 'HASHTAGS') return false;
      } else if (_selectedType == 'POST') {
        if (genType != 'POST') return false;
      }
    }

    // Status match
    if (_selectedStatus != 'ALL') {
      final status = gen.status.toUpperCase();
      if (_selectedStatus == 'COMPLETED' && status != 'COMPLETED') return false;
      if (_selectedStatus == 'PROCESSING' &&
          status != 'PROCESSING' &&
          status != 'PENDING') {
        return false;
      }
      if (_selectedStatus == 'FAILED' && status != 'FAILED') return false;
    }

    // Search query match
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final p = gen.product.toLowerCase();
      final c = (gen.caption ?? '').toLowerCase();
      final o = (gen.objective ?? '').toLowerCase();
      if (!p.contains(q) && !c.contains(q) && !o.contains(q)) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final gensAsync = ref.watch(customerAiGenerationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Generation History',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'All creations, drafts & published scripts',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(customerAiGenerationsProvider.notifier).refresh();
        },
        child: Column(
          children: [
            // Search Bar & Filter Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search content, topic, or tags...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Remix.search_line,
                          color: Color(0xFF64748B),
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tool Type Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _toolTypes.map((t) {
                        final isSel = _selectedType == t['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(t['label']!),
                            selected: isSel,
                            onSelected: (_) =>
                                setState(() => _selectedType = t['id']!),
                            selectedColor: AppColors.primary,
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSel
                                    ? AppColors.primary
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Status Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _statusFilters.map((s) {
                        final isSel = _selectedStatus == s['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(s['label']!),
                            selected: isSel,
                            onSelected: (_) =>
                                setState(() => _selectedStatus = s['id']!),
                            selectedColor: const Color(0xFFE0E7FF),
                            backgroundColor: Colors.transparent,
                            labelStyle: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSel
                                  ? const Color(0xFF4338CA)
                                  : const Color(0xFF64748B),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSel
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Generation Cards List
            Expanded(
              child: gensAsync.when(
                data: (gens) {
                  final filtered = gens.where(_matchesFilter).toList();
                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final gen = filtered[i];
                      return _buildGenerationCard(gen);
                    },
                  );
                },
                loading: () => const SkeletonList(count: 4),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Remix.error_warning_line,
                        size: 36,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load history',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => ref
                            .read(customerAiGenerationsProvider.notifier)
                            .refresh(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.sparkling_line,
                size: 30,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Content Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty ||
                      _selectedType != 'ALL' ||
                      _selectedStatus != 'ALL'
                  ? 'Try adjusting your filters or search terms.'
                  : 'You haven\'t created any AI content yet. Start your first generation now!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationCard(AiGenerationModel gen) {
    final status = gen.status.toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isProcessing = status == 'PROCESSING' || status == 'PENDING';

    Color statusBg;
    Color statusFg;
    String statusText;
    if (isCompleted) {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF059669);
      statusText = 'Completed';
    } else if (isProcessing) {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
      statusText = 'Processing';
    } else {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFFDC2626);
      statusText = 'Failed';
    }

    final typeUpper = gen.type.toUpperCase();
    IconData typeIcon = Remix.file_text_line;
    Color typeColor = const Color(0xFF4F46E5);
    String typeLabel = typeUpper;

    if (typeUpper == 'POSTER') {
      typeIcon = Remix.image_2_line;
      typeColor = const Color(0xFF9333EA);
      typeLabel = 'AI Image';
    } else if (typeUpper == 'VIDEO') {
      typeIcon = Remix.video_line;
      typeColor = const Color(0xFFDC2626);
      typeLabel = 'Video Script';
    } else if (typeUpper == 'CAPTION' || typeUpper == 'HASHTAGS') {
      typeIcon = Remix.hashtag;
      typeColor = const Color(0xFF059669);
      typeLabel = 'Captions & Tags';
    } else {
      typeLabel = 'Social Post';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerAiPreviewView(generation: gen),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: Type Badge + Date + Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 13, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(gen.createdAt),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Product / Prompt Title
            Text(
              gen.product.isNotEmpty ? gen.product : 'AI Creation',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Caption / Content Snippet
            Text(
              gen.caption != null && gen.caption!.isNotEmpty
                  ? gen.caption!
                  : (gen.objective != null
                        ? 'Objective: ${gen.objective}'
                        : 'Tap to view generated content output'),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF475569),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Footer: Credits spent + Platform tag + Arrow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Remix.copper_coin_line,
                        size: 11,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${gen.creditsSpent} Credit${gen.creditsSpent > 1 ? 's' : ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                if (gen.platform != null && gen.platform!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      gen.platform!,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'View Output',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
