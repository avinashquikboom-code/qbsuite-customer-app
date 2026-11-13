import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';

class CustomerWorkRequestsView extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final String? customerId;

  const CustomerWorkRequestsView({
    super.key,
    this.onNavigateToTab,
    this.customerId,
  });

  @override
  ConsumerState<CustomerWorkRequestsView> createState() =>
      _CustomerWorkRequestsViewState();
}

class _CustomerWorkRequestsViewState
    extends ConsumerState<CustomerWorkRequestsView> {
  int _selectedFilter =
      0; // 0: All, 1: In Progress, 2: Under Review, 3: Completed

  final List<String> _filters = const [
    'All Requests',
    'In Progress',
    'Under Review',
    'Completed',
  ];

  final List<Map<String, dynamic>> _requests = [
    {
      'id': 'REQ-2041',
      'customerId': 'T001',
      'title': 'Monsoon Fat Loss Transformation Reel',
      'type': 'Reels Shoot',
      'platform': 'Instagram Reels',
      'status': 'In Progress',
      'statusColor': const Color(0xFF0284C7),
      'statusBg': const Color(0xFFE0F2FE),
      'icon': Remix.video_fill,
      'typeColor': const Color(0xFF0284C7),
      'submittedDate': '18 Aug 2026',
      'dueDate': '21 Aug 2026',
      'assignedTeam': 'Production Crew A',
      'concept':
          '15-sec high energy workout montage with beat drops and discount overlay.',
      'revisions': 0,
    },
    {
      'id': 'REQ-2038',
      'customerId': 'T001',
      'title': 'Gym Anniversary 50% Off Story Ad',
      'type': 'Story Design',
      'platform': 'Instagram Story',
      'status': 'Under Review',
      'statusColor': const Color(0xFFD97706),
      'statusBg': const Color(0xFFFEF3C7),
      'icon': Remix.flashlight_fill,
      'typeColor': const Color(0xFFF59E0B),
      'submittedDate': '16 Aug 2026',
      'dueDate': '19 Aug 2026',
      'assignedTeam': 'Creative Graphics B',
      'concept':
          'Animated story banner with countdown timer sticker and CTA swipe-up link.',
      'revisions': 1,
    },
    {
      'id': 'REQ-2035',
      'customerId': 'T001',
      'title': 'Weekly Nutrition & Diet Carousels (5 Slides)',
      'type': 'Post Design',
      'platform': 'Instagram Feed',
      'status': 'Completed',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
      'icon': Remix.palette_fill,
      'typeColor': const Color(0xFF9333EA),
      'submittedDate': '12 Aug 2026',
      'dueDate': '15 Aug 2026',
      'assignedTeam': 'Design Team Alpha',
      'concept':
          '5 high-contrast educational slides explaining protein intake for beginners.',
      'revisions': 0,
    },
    {
      'id': 'REQ-2029',
      'customerId': 'T001',
      'title': 'Client UGC Testimonial Video Edit',
      'type': 'Video Editing',
      'platform': 'Meta Ads',
      'status': 'Completed',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
      'icon': Remix.film_fill,
      'typeColor': const Color(0xFF0D9488),
      'submittedDate': '08 Aug 2026',
      'dueDate': '11 Aug 2026',
      'assignedTeam': 'Video Post Crew',
      'concept':
          'Audio cleanup, animated captions, and hook pacing for customer review clip.',
      'revisions': 0,
    },
    // ── CUSTOMER B (T002) Isolated Work Requests ────────────────────────────
    {
      'id': 'REQ-T2-001',
      'customerId': 'T002',
      'title': 'Crossfit High-Rep Reel Shoot',
      'type': 'Reels Shoot',
      'platform': 'Instagram Reels',
      'status': 'In Progress',
      'statusColor': const Color(0xFF0284C7),
      'statusBg': const Color(0xFFE0F2FE),
      'icon': Remix.video_fill,
      'typeColor': const Color(0xFF0284C7),
      'submittedDate': '19 Aug 2026',
      'dueDate': '22 Aug 2026',
      'assignedTeam': 'Growth Team 1',
      'concept': 'High rep bench press and cardio circuit reel capture.',
      'revisions': 0,
    },
    {
      'id': 'REQ-T2-002',
      'customerId': 'T002',
      'title': 'Fine Dining Sizzler Special Post',
      'type': 'Post Design',
      'platform': 'Instagram Feed',
      'status': 'Completed',
      'statusColor': const Color(0xFF16A34A),
      'statusBg': const Color(0xFFDCFCE7),
      'icon': Remix.palette_fill,
      'typeColor': const Color(0xFF9333EA),
      'submittedDate': '14 Aug 2026',
      'dueDate': '17 Aug 2026',
      'assignedTeam': 'Creative Team Alpha',
      'concept': 'Highlight chef recommended sizzler platter.',
      'revisions': 0,
    },
  ];

  List<Map<String, dynamic>> get _filteredRequests {
    final customerIdAsync = ref.watch(currentCustomerIdProvider);
    final targetId =
        (widget.customerId ??
                customerIdAsync.asData?.value ??
                customerIdAsync.value ??
                '')
            .toUpperCase();
    final scopedRequests = _requests.where((r) {
      final reqCid = (r['customerId'] ?? '').toString().toUpperCase();
      return reqCid == targetId || targetId.isEmpty;
    }).toList();

    debugPrint('==================================================');
    debugPrint('[CUSTOMER WORK REQUESTS]');
    debugPrint('Target Customer ID: $targetId');
    debugPrint('Scoped Requests Count: ${scopedRequests.length}');
    for (final req in scopedRequests) {
      debugPrint(
        '  Req: ${req['id']} | CustomerId: ${req['customerId']} | Title: ${req['title']}',
      );
    }
    debugPrint('==================================================');

    if (_selectedFilter == 0) return scopedRequests;
    final filterText = _filters[_selectedFilter];
    return scopedRequests.where((r) => r['status'] == filterText).toList();
  }

  void _openNewRequestSheet() {
    final titleController = TextEditingController();
    final conceptController = TextEditingController();
    String selectedType = 'Reels Shoot';
    String selectedPlatform = 'Instagram Reels';

    final types = [
      'Reels Shoot',
      'Video Editing',
      'Post Design',
      'Story Design',
      'Custom Ad',
    ];
    final platforms = [
      'Instagram Reels',
      'Instagram Story',
      'Instagram Feed',
      'Meta Ads',
      'YouTube Shorts',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Creative Request',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Remix.close_line, size: 20),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Request Type
                Text(
                  'Creative Type',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: types.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = types[i];
                      final isSel = selectedType == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isSel ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (_) =>
                            setModalState(() => selectedType = t),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // Title
                Text(
                  'Request Title / Campaign Name',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Sunday Boot Camp Promo Video',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Platform
                Text(
                  'Target Platform',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlatform,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: platforms
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setModalState(
                    () => selectedPlatform = v ?? selectedPlatform,
                  ),
                ),

                const SizedBox(height: 14),

                // Concept & Instructions
                Text(
                  'Brief / Instructions / Hook Idea',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: conceptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Mention special offers, key hooks, colors or reference links...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      setState(() {
                        _requests.insert(0, {
                          'id':
                              'REQ-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
                          'title': title,
                          'type': selectedType,
                          'platform': selectedPlatform,
                          'status': 'In Progress',
                          'statusColor': const Color(0xFF0284C7),
                          'statusBg': const Color(0xFFE0F2FE),
                          'icon': Remix.video_fill,
                          'typeColor': const Color(0xFF0284C7),
                          'submittedDate': 'Today',
                          'dueDate': 'In 3 Days',
                          'assignedTeam': 'Creative Production Team',
                          'concept': conceptController.text.trim().isNotEmpty
                              ? conceptController.text.trim()
                              : 'Custom creative request submitted by customer.',
                          'revisions': 0,
                        });
                      });

                      Navigator.pop(modalCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Request "$title" submitted successfully!',
                          ),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                    },
                    child: Text(
                      'Submit Creative Request',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context)) ...[
                        const BackButton(color: AppColors.textPrimary),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Remix.task_fill,
                            color: Color(0xFF0284C7),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Work Requests',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'SUBMIT & TRACK CREATIVES',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openNewRequestSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.add_line,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New Request',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSel = _selectedFilter == index;
                    return InkWell(
                      onTap: () => setState(() => _selectedFilter = index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primaryDark
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            _filters[index],
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Requests Feed List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Remix.inbox_line,
                            size: 44,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No requests found in this status',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final req = filtered[index];
                        return _buildRequestCard(context, req);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> req) {
    final statusBg = req['statusBg'] as Color;
    final statusColor = req['statusColor'] as Color;
    final typeColor = req['typeColor'] as Color;
    final icon = req['icon'] as IconData;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Type & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(icon, size: 14, color: typeColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    req['type'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• ${req['platform']}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req['status'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            req['title'] as String,
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // Concept note
          Text(
            req['concept'] as String,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Meta row (Submitted, Due Date, Assigned Team)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Remix.time_line,
                    size: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${req['dueDate']}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Remix.team_line,
                    size: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    req['assignedTeam'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
