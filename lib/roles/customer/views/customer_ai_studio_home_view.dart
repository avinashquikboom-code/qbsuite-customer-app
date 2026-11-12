import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';
import 'customer_ai_creation_form_view.dart';
import 'customer_ai_history_view.dart';
import 'customer_ai_preview_view.dart';
import 'customer_social_connect_modal.dart';
import '../widgets/ai_credit_top_up_modal.dart';

/// Redesigned Screen for QB Marketplace AI Content Studio & Creation Suite
class CustomerAiStudioHomeView extends ConsumerStatefulWidget {
  const CustomerAiStudioHomeView({super.key});

  @override
  ConsumerState<CustomerAiStudioHomeView> createState() =>
      _CustomerAiStudioHomeViewState();
}

class _CustomerAiStudioHomeViewState
    extends ConsumerState<CustomerAiStudioHomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerAiWalletProvider.notifier).refresh();
      ref.read(customerAiServicesProvider.notifier).refresh();
      ref.read(customerAiGenerationsProvider.notifier).refresh();
      ref.read(customerSocialAccountsProvider.notifier).refresh();
      ref.read(customerSocialPublishesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreationForm(String type, String title, int credits) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerAiCreationFormView(
          serviceType: type,
          serviceTitle: title,
          creditCost: credits,
        ),
      ),
    ).then((_) {
      if (mounted) {
        ref.read(customerAiWalletProvider.notifier).refresh();
        ref.read(customerAiGenerationsProvider.notifier).refresh();
      }
    });
  }

  void _openHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerAiHistoryView()),
    );
  }

  void _openTopUpSheet() => showAiCreditTopUpModal(context);

  void _openConnectAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CustomerSocialConnectModal(),
    );
  }

  Future<void> _confirmDisconnectAccount(SocialAccountModel acc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Disconnect ${acc.platform}?',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to disconnect ${acc.accountName} (${acc.platform})?',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await ref
          .read(customerAiStudioServiceProvider)
          .disconnectSocialAccount(acc.id);
      if (ok) {
        await ref.read(customerSocialAccountsProvider.notifier).refresh();
        if (ref.read(selectedSocialAccountProvider)?.id == acc.id) {
          ref.read(selectedSocialAccountProvider.notifier).selectAccount(null);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${acc.platform} disconnected'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to disconnect account. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(customerAiWalletProvider);
    final wallet = walletAsync.value;
    final generationsAsync = ref.watch(customerAiGenerationsProvider);
    final socialAccountsAsync = ref.watch(customerSocialAccountsProvider);

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
              'AI Content Studio',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'QB Marketplace Creative Suite',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          // Wallet Balance Pill
          GestureDetector(
            onTap: _openTopUpSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Remix.copper_coin_line,
                    size: 15,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${wallet?.balance ?? 0} Credits',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Remix.add_circle_fill,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(customerAiWalletProvider.notifier).refresh(),
            ref.read(customerAiGenerationsProvider.notifier).refresh(),
            ref.read(customerSocialAccountsProvider.notifier).refresh(),
            ref.read(customerSocialPublishesProvider.notifier).refresh(),
            ref.read(customerAiServicesProvider.notifier).refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Section
              _buildHeroSection(wallet?.balance ?? 0),

              const SizedBox(height: 16),

              // 2. Credit / Wallet Card
              _buildWalletCard(wallet),

              const SizedBox(height: 20),

              // 3. Quick Actions / Generation Options Grid (6 Tools)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Select a creative model',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildToolsGrid(),

              const SizedBox(height: 22),

              // 4. Recent AI Generations Section
              _buildRecentGenerationsHeader(),
              const SizedBox(height: 10),
              _buildRecentGenerationsPreview(generationsAsync),

              const SizedBox(height: 22),

              // 5. Marketplace / AI Tools Section
              _buildMarketplaceAiToolsSection(),

              const SizedBox(height: 22),

              // 6. Connected Social Accounts Section
              _buildSocialAccountsSection(socialAccountsAsync),

              const SizedBox(height: 22),

              // 7. Tabs Section: History & Social Publishing Queue
              _buildTabsSection(generationsAsync),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Hero Section ────────────────────────────────────────────────────────
  Widget _buildHeroSection(int balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Color(0xFFA5B4FC),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AI STUDIO POWERED',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFA5B4FC),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$balance credits available',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Smart AI Content & Media Creator',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Generate posts, reels, video scripts, ad copy, and visuals tailored for your brand.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Primary CTA: Generate Content
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openCreationForm('POST', 'AI Social Post', 1),
                  icon: const Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Generate Content',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Secondary CTA: View History
              OutlinedButton.icon(
                onPressed: _openHistoryScreen,
                icon: const Icon(
                  Remix.history_line,
                  size: 15,
                  color: Colors.white,
                ),
                label: Text(
                  'View History',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Credit / Wallet Card ────────────────────────────────────────────────
  Widget _buildWalletCard(AiWalletModel? wallet) {
    final balance = wallet?.balance ?? 0;
    final isLowCredit = balance < 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowCredit
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Remix.copper_coin_fill,
                  size: 22,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Credit Wallet',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$balance Credits',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openTopUpSheet,
                icon: const Icon(Remix.add_line, size: 14, color: Colors.white),
                label: Text(
                  'Top-Up',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),

          // Low Credit Warning Banner
          if (isLowCredit) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Remix.alert_line,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      balance == 0
                          ? 'You have 0 credits. Recharge to start generating content.'
                          : 'Low credit balance ($balance left). Recharge to prevent generation interruptions.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Quick Actions / Generation Options Grid (6 Tools) ──────────────────
  Widget _buildToolsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildToolCard(
          title: 'Social Post Generator',
          desc: 'High-engaging copy & tags',
          costText: '1 Credit',
          icon: Remix.file_text_line,
          iconBg: const Color(0xFFEEF2FF),
          iconColor: const Color(0xFF4F46E5),
          onTap: () => _openCreationForm('POST', 'Social Post Generator', 1),
        ),
        _buildToolCard(
          title: 'Video Script Writer',
          desc: '15-60s reels, hooks & scenes',
          costText: '5 Credits',
          icon: Remix.video_line,
          iconBg: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFDC2626),
          onTap: () => _openCreationForm('VIDEO', 'Video Script Writer', 5),
        ),
        _buildToolCard(
          title: 'Ad Copy Generator',
          desc: 'High-conversion sales copy',
          costText: '1 Credit',
          icon: Remix.advertisement_line,
          iconBg: const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          onTap: () => _openCreationForm('AD_COPY', 'Ad Copy Generator', 1),
        ),
        _buildToolCard(
          title: 'Marketing Email Writer',
          desc: 'Newsletters & cold outreach',
          costText: '1 Credit',
          icon: Remix.mail_send_line,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          onTap: () => _openCreationForm('EMAIL', 'Marketing Email Writer', 1),
        ),
        _buildToolCard(
          title: 'AI Image Generator',
          desc: 'Branded promotional graphics',
          costText: '2 Credits',
          icon: Remix.image_2_line,
          iconBg: const Color(0xFFFAF5FF),
          iconColor: const Color(0xFF9333EA),
          onTap: () => _openCreationForm('POSTER', 'AI Image Generator', 2),
        ),
        _buildToolCard(
          title: 'Captions & Tags',
          desc: 'Viral hooks & trending hashtags',
          costText: '1 Credit',
          icon: Remix.hashtag,
          iconBg: const Color(0xFFCCFBF1),
          iconColor: const Color(0xFF0F766E),
          onTap: () => _openCreationForm('CAPTIONS', 'Captions & Tags', 1),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required String title,
    required String desc,
    required String costText,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    costText,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Recent AI Generations Section ──────────────────────────────────────
  Widget _buildRecentGenerationsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent AI Generations',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: _openHistoryScreen,
          child: Row(
            children: [
              Text(
                'View All',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
        ),
      ],
    );
  }

  Widget _buildRecentGenerationsPreview(
    AsyncValue<List<AiGenerationModel>> gensAsync,
  ) {
    return gensAsync.when(
      data: (gens) {
        if (gens.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 32,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 8),
                Text(
                  'No Generations Yet',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select any tool above to create your first content.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        final recentThree = gens.take(3).toList();
        return Column(
          children: recentThree.map((gen) {
            final isCompleted = gen.status.toUpperCase() == 'COMPLETED';
            final isProcessing =
                gen.status.toUpperCase() == 'PROCESSING' ||
                gen.status.toUpperCase() == 'PENDING';

            Color statusColor = isCompleted
                ? const Color(0xFF10B981)
                : (isProcessing
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerAiPreviewView(generation: gen),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          gen.type == 'POSTER'
                              ? Remix.image_2_line
                              : gen.type == 'VIDEO'
                              ? Remix.video_line
                              : Remix.file_text_line,
                          color: const Color(0xFF4F46E5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    gen.product.isNotEmpty
                                        ? gen.product
                                        : 'AI Creation',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    gen.status,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              gen.caption ??
                                  gen.objective ??
                                  'AI Generated Content',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Remix.arrow_right_s_line,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // ── 5. Marketplace Creative Tools Section ──────────────────────────────────
  Widget _buildMarketplaceAiToolsSection() {
    final servicesAsync = ref.watch(customerAiServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Creative Tools Marketplace',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'On-Demand Suite',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        servicesAsync.when(
          data: (services) {
            final activeServices = services.where((s) => s.isActive).toList();
            if (activeServices.isEmpty) {
              return const SizedBox.shrink();
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeServices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final s = activeServices[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Remix.sparkling_line,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (s.description != null &&
                                s.description!.isNotEmpty)
                              Text(
                                s.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final type = s.code.replaceFirst('AI_', '');
                          _openCreationForm(type, s.name, s.creditCost);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2FF),
                          foregroundColor: const Color(0xFF4F46E5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${s.creditCost} Crd • Use',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── 6. Connected Social Accounts Section ──────────────────────────────────
  Widget _buildSocialAccountsSection(
    AsyncValue<List<SocialAccountModel>> accountsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  const Icon(
                    Remix.share_line,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected Channels',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openConnectAccountSheet,
                child: Row(
                  children: [
                    const Icon(
                      Remix.add_line,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Connect Channel',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return Text(
                  'No social accounts connected yet. Connect Instagram, Facebook, or LinkedIn to publish generated content instantly.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accounts.map((acc) {
                  return Container(
                    padding: const EdgeInsets.only(
                      left: 8,
                      top: 4,
                      bottom: 4,
                      right: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${acc.platform}: ${acc.accountName}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _confirmDisconnectAccount(acc),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE2E8F0),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Text('Loading channels...'),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── 7. Tabbed Section: History & Social Publishing Queue ───────────────────
  Widget _buildTabsSection(AsyncValue<List<AiGenerationModel>> gensAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Creation Log'),
            Tab(text: 'Social Queue'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGenerationsList(gensAsync),
              _buildSocialQueueList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationsList(AsyncValue<List<AiGenerationModel>> gensAsync) {
    return gensAsync.when(
      data: (gens) {
        if (gens.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 8),
                Text(
                  'No Content Logged',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Generated copy and media will appear here.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: gens.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final gen = gens[i];
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        gen.type == 'POSTER'
                            ? Remix.image_2_line
                            : gen.type == 'VIDEO'
                            ? Remix.video_line
                            : Remix.file_text_line,
                        color: const Color(0xFF4F46E5),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gen.product,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gen.caption ?? gen.objective ?? 'AI Generated',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Remix.arrow_right_s_line,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSocialQueueList() {
    final publishesAsync = ref.watch(customerSocialPublishesProvider);
    return publishesAsync.when(
      data: (publishes) {
        if (publishes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Remix.time_line, size: 36, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 8),
                Text(
                  'No Scheduled Posts',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'After generating content, tap "Publish to Social Media" to queue posts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: publishes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final pub = publishes[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pub.platform} Post',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          pub.content ?? '(Media post)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pub.status == 'PUBLISHED'
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pub.status,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pub.status == 'PUBLISHED'
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
