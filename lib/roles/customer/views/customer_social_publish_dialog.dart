import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../models/ai_studio_model.dart';
import '../services/customer_ai_studio_service.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';
import 'customer_social_connect_modal.dart';

class CustomerSocialPublishDialog extends ConsumerStatefulWidget {
  final AiGenerationModel generation;

  const CustomerSocialPublishDialog({super.key, required this.generation});

  @override
  ConsumerState<CustomerSocialPublishDialog> createState() =>
      _CustomerSocialPublishDialogState();
}

class _CustomerSocialPublishDialogState
    extends ConsumerState<CustomerSocialPublishDialog> {
  /// Store the selected account ID (not the whole object) to survive provider refreshes.
  int? _selectedAccountId;
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with currently selected account ID if available
    _selectedAccountId = ref.read(selectedSocialAccountProvider)?.id;
  }

  void _openConnectModal(BuildContext context) {
    showModalBottomSheet<SocialAccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerSocialConnectModal(
        initialPlatform: widget.generation.platform,
      ),
    ).then((acc) {
      if (acc != null && mounted) {
        setState(() => _selectedAccountId = acc.id);
        ref.read(selectedSocialAccountProvider.notifier).selectAccount(acc);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  Future<void> _handlePublish() async {
    if (_isPublishing) return;

    // Resolve the selected account from the live list using the stored ID
    final accounts = ref.read(customerSocialAccountsProvider).value ?? [];
    final selectedAccount = _selectedAccountId == null
        ? null
        : accounts.cast<SocialAccountModel?>().firstWhere(
            (a) => a?.id == _selectedAccountId,
            orElse: () => null,
          );

    if (selectedAccount == null) {
      // No account selected — open the connect flow
      _openConnectModal(context);
      return;
    }

    setState(() => _isPublishing = true);
    final service = ref.read(customerAiStudioServiceProvider);

    DateTime? targetSchedule;
    if (_isScheduled) {
      targetSchedule = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );
    }

    try {
      final pub = await service.publishContent(
        socialAccountId: selectedAccount.id,
        generationId: widget.generation.id,
        content: widget.generation.caption,
        mediaUrls:
            widget.generation.mediaUrl != null &&
                widget.generation.mediaUrl!.isNotEmpty
            ? [widget.generation.mediaUrl!]
            : [],
        scheduledFor: targetSchedule,
      );

      if (pub != null) {
        ref.read(customerSocialPublishesProvider.notifier).addPublish(pub);

        if (mounted) {
          final isFailed = pub.status.toUpperCase() == 'FAILED';

          if (isFailed) {
            // Backend published but the platform returned an error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  pub.errorMessage?.isNotEmpty == true
                      ? 'Publish failed: ${pub.errorMessage}'
                      : 'Publish failed on ${selectedAccount.platform}. Please try again.',
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isScheduled
                      ? 'Post scheduled successfully!'
                      : 'Published to ${selectedAccount.platform}!',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Publishing failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(customerSocialAccountsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Publish to Social Channels',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Select Account Dropdown or Connect Channel Card
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Remix.information_line,
                              size: 18,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No Social Channel Connected',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Link your Instagram, Facebook, or YouTube channel to publish this post directly.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            icon: const Icon(
                              Remix.add_circle_line,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Connect Social Channel Now',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => _openConnectModal(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Deduplicate by ID to prevent assertion "more than one item"
                final seenIds = <int>{};
                final uniqueAccounts = accounts
                    .where((a) => seenIds.add(a.id))
                    .toList();

                // If no account selected or the selected ID is gone, auto-pick
                if (_selectedAccountId == null ||
                    !uniqueAccounts.any((a) => a.id == _selectedAccountId)) {
                  final match = uniqueAccounts.where(
                    (a) =>
                        a.platform.toUpperCase() ==
                        (widget.generation.platform?.toUpperCase() ?? ''),
                  );
                  final autoSelected = match.isNotEmpty
                      ? match.first
                      : uniqueAccounts.first;

                  // Update ID and provider outside of build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _selectedAccountId = autoSelected.id);
                      ref
                          .read(selectedSocialAccountProvider.notifier)
                          .selectAccount(autoSelected);
                    }
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Use InputDecorator + DropdownButton to avoid the
                    // deprecated `value:` parameter on DropdownButtonFormField.
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Select Destination Channel',
                        labelStyle: GoogleFonts.outfit(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButton<int>(
                        value:
                            uniqueAccounts.any(
                              (a) => a.id == _selectedAccountId,
                            )
                            ? _selectedAccountId
                            : null,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        items: uniqueAccounts.map((acc) {
                          return DropdownMenuItem<int>(
                            value: acc.id,
                            child: Text(
                              '${acc.platform} \u2014 ${acc.accountName}',
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final picked = uniqueAccounts
                              .cast<SocialAccountModel?>()
                              .firstWhere(
                                (a) => a?.id == id,
                                orElse: () => null,
                              );
                          setState(() => _selectedAccountId = id);
                          if (picked != null) {
                            ref
                                .read(selectedSocialAccountProvider.notifier)
                                .selectAccount(picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Remix.add_line,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'Connect another channel',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () => _openConnectModal(context),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Remix.error_warning_line,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Failed to load channels. Tap retry.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(customerSocialAccountsProvider.notifier)
                          .refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Publish Mode Toggle: Immediate vs Scheduled
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isScheduled = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isScheduled
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_isScheduled
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Publish Now',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: !_isScheduled
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isScheduled = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isScheduled
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isScheduled
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Schedule for Later',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isScheduled
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Schedule Pickers (if scheduled)
            if (_isScheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Remix.calendar_line, size: 16),
                      label: Text(
                        '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}',
                        style: GoogleFonts.outfit(fontSize: 12),
                      ),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Remix.time_line, size: 16),
                      label: Text(
                        _scheduledTime.format(context),
                        style: GoogleFonts.outfit(fontSize: 12),
                      ),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // Action Button
            Builder(
              builder: (ctx) {
                final hasAccounts = (accountsAsync.value ?? []).isNotEmpty;
                final buttonText = _isScheduled
                    ? 'Schedule Post'
                    : 'Post to Channel Now';

                return SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isPublishing
                        ? null
                        : (hasAccounts
                              ? _handlePublish
                              : () => _openConnectModal(context)),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            hasAccounts ? buttonText : 'Connect Social Channel',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
