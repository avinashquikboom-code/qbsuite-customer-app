import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'package:quickboom_crm_customer/roles/customer/models/social_media_work_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/social_media_work_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/social_media_work_viewmodel.dart';

class SocialMediaWorkHandlerView extends ConsumerStatefulWidget {
  const SocialMediaWorkHandlerView({super.key});

  @override
  ConsumerState<SocialMediaWorkHandlerView> createState() =>
      _SocialMediaWorkHandlerViewState();
}

class _SocialMediaWorkHandlerViewState
    extends ConsumerState<SocialMediaWorkHandlerView> {
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountUrlController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _handlerNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CustomerSocialMediaHandler? _editingAccount;
  String _selectedPlatform = 'INSTAGRAM';
  String _selectedWorkType = 'Content Posting';
  bool _obscurePassword = true;
  final DateTime _startDate = DateTime.now();
  final int _durationDays = 30;

  static const List<Map<String, String>> _platformOptions = [
    {'label': 'Instagram', 'value': 'INSTAGRAM'},
    {'label': 'Facebook', 'value': 'FACEBOOK'},
    {'label': 'YouTube', 'value': 'YOUTUBE'},
    {'label': 'LinkedIn', 'value': 'LINKEDIN'},
    {'label': 'Twitter', 'value': 'TWITTER'},
    {'label': 'Other', 'value': 'OTHER'},
  ];

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountUrlController.dispose();
    _passwordController.dispose();
    _handlerNameController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startEditing(CustomerSocialMediaHandler account) {
    setState(() {
      _editingAccount = account;
      final upperPlatform = account.platform.toUpperCase();
      _selectedPlatform =
          _platformOptions.any((p) => p['value'] == upperPlatform)
          ? upperPlatform
          : 'OTHER';
      _accountNameController.text = account.accountName;
      _accountUrlController.text = account.accountUrl ?? '';
      _passwordController.clear();
      _obscurePassword = true;
      _selectedWorkType =
          SocialMediaWorkService.workTypes.contains(account.workType)
          ? account.workType
          : 'Content Posting';
      _notesController.text = account.notes ?? '';
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingAccount = null;
      _selectedPlatform = 'INSTAGRAM';
      _accountNameController.clear();
      _accountUrlController.clear();
      _passwordController.clear();
      _handlerNameController.clear();
      _selectedWorkType = 'Content Posting';
      _notesController.clear();
      _obscurePassword = true;
    });
  }

  Future<void> _handleSubmit() async {
    final isEdit = _editingAccount != null;
    final accountName = _accountNameController.text.trim();
    if (accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Account Handle / Name'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final password = _passwordController.text.trim();
    if (!isEdit && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Password'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final notifier = ref.read(socialMediaWorkProvider.notifier);
    bool success = false;

    if (isEdit) {
      success = await notifier.updateHandler(
        id: _editingAccount!.id,
        platform: _selectedPlatform,
        accountName: accountName,
        accountUrl: _accountUrlController.text.trim().isNotEmpty
            ? _accountUrlController.text.trim()
            : null,
        password: password.isNotEmpty ? password : null,
        handlerName: _handlerNameController.text.trim().isNotEmpty
            ? _handlerNameController.text.trim()
            : null,
        workType: _selectedWorkType,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
    } else {
      notifier.selectPlatform(_selectedPlatform);
      notifier.setAccountName(accountName);
      notifier.setAccountUrl(_accountUrlController.text.trim());
      notifier.setPassword(password);
      notifier.setHandlerName(_handlerNameController.text.trim());
      notifier.selectWorkType(_selectedWorkType);
      notifier.setStartDate(_startDate);
      notifier.setDurationDays(_durationDays);
      notifier.setNotes(_notesController.text.trim());

      success = await notifier.submit();
    }

    if (!mounted) return;

    if (success) {
      final wasEditing = isEdit;
      _cancelEdit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Remix.checkbox_circle_fill,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wasEditing
                      ? 'Social media account updated successfully.'
                      : 'Social media account saved successfully.',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      final error =
          ref.read(socialMediaWorkProvider).errorMessage ??
          'Failed to save account';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteAccount(CustomerSocialMediaHandler handler) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Social Handler',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Are you sure you want to remove ${handler.accountName} (${handler.platform})?',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(socialMediaWorkProvider.notifier)
                  .deleteHandler(handler.id);
              if (mounted) {
                if (_editingAccount?.id == handler.id) {
                  _cancelEdit();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account removed successfully'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    if (!perms.customerCan('CUSTOMER_SSM', 'VIEW')) {
      return const PermissionGuardedView(
        moduleKey: 'CUSTOMER_SSM',
        moduleTitle: 'SSM Account Access',
        child: SizedBox.shrink(),
      );
    }

    final state = ref.watch(socialMediaWorkProvider);
    final customerNameAsync = ref.watch(currentCustomerNameProvider);
    final customerName =
        (customerNameAsync.asData?.value ??
                customerNameAsync.value ??
                'Customer Workspace')
            .trim();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SSM ACCOUNT ACCESS',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Linked Accounts & Schedules',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Remix.refresh_line,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () =>
                ref.read(socialMediaWorkProvider.notifier).loadHandlers(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(socialMediaWorkProvider.notifier).loadHandlers(),
          color: AppColors.primary,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Info Banner ──
                _buildHeaderBanner(customerName),

                const SizedBox(height: 14),

                // ── Work Creation / Account Form Card ──
                _buildFormCard(state, customerName),

                const SizedBox(height: 20),

                // ── Accounts List Section ──
                _buildAccountsListSection(state),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(String customerName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subtleGreenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Remix.share_circle_fill,
              color: AppColors.primaryDark,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$customerName Social Accounts',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage social media accounts and active handling campaigns for $customerName.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(
    SocialMediaWorkState state,
    String loggedInCustomerName,
  ) {
    final isEdit = _editingAccount != null;
    final currentPlatform =
        _platformOptions.any(
          (opt) => opt['value'] == _selectedPlatform.toUpperCase(),
        )
        ? _selectedPlatform.toUpperCase()
        : 'OTHER';
    final currentWorkType =
        SocialMediaWorkService.workTypes.contains(_selectedWorkType)
        ? _selectedWorkType
        : SocialMediaWorkService.workTypes.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEdit ? AppColors.primary : AppColors.borderLight,
          width: isEdit ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEdit ? Remix.edit_box_line : Remix.file_edit_line,
                color: AppColors.primaryDark,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit ? 'Edit SSM Account' : 'Add SSM Account',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEdit)
                TextButton.icon(
                  onPressed: _cancelEdit,
                  icon: const Icon(
                    Remix.close_circle_line,
                    size: 14,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Cancel Edit',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Platform Selection Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('platform_$currentPlatform'),
            initialValue: currentPlatform,
            isExpanded: true,
            icon: const Icon(
              Remix.arrow_down_s_line,
              size: 18,
              color: AppColors.textSecondary,
            ),
            decoration: InputDecoration(
              labelText: 'Platform *',
              prefixIcon: const Icon(
                Remix.share_box_line,
                size: 18,
                color: AppColors.primaryDark,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: _platformOptions.map((opt) {
              return DropdownMenuItem<String>(
                value: opt['value'],
                child: Text(
                  opt['label']!,
                  style: GoogleFonts.outfit(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedPlatform = val);
              }
            },
          ),

          const SizedBox(height: 10),

          // 2. Account Name / Handle
          TextField(
            controller: _accountNameController,
            decoration: InputDecoration(
              labelText: 'Account Handle / Name *',
              hintText: 'e.g. @carefitnessgym or Care Fitness',
              prefixIcon: const Icon(
                Remix.at_line,
                size: 18,
                color: AppColors.primaryDark,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.outfit(fontSize: 13),
          ),

          const SizedBox(height: 10),

          // 3. Account Profile URL
          TextField(
            controller: _accountUrlController,
            decoration: InputDecoration(
              labelText: 'Account Profile URL',
              hintText: 'https://instagram.com/carefitnessgym',
              prefixIcon: const Icon(
                Remix.link,
                size: 18,
                color: AppColors.primaryDark,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.outfit(fontSize: 13),
          ),

          const SizedBox(height: 10),

          // 4. Password Field (Required on create, optional on edit)
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: isEdit
                  ? 'Password (Leave blank to keep unchanged)'
                  : 'Password *',
              hintText: isEdit ? '••••••••' : 'Enter account password',
              prefixIcon: const Icon(
                Remix.lock_password_line,
                size: 18,
                color: AppColors.primaryDark,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Remix.eye_close_line : Remix.eye_line,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.outfit(fontSize: 13),
          ),

          const SizedBox(height: 10),

          // 5. Work Type Selector
          DropdownButtonFormField<String>(
            key: ValueKey('work_type_$currentWorkType'),
            initialValue: currentWorkType,
            decoration: InputDecoration(
              labelText: 'Work Type',
              prefixIcon: const Icon(
                Remix.briefcase_line,
                size: 18,
                color: AppColors.primaryDark,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: SocialMediaWorkService.workTypes.map((w) {
              return DropdownMenuItem(
                value: w,
                child: Text(w, style: GoogleFonts.outfit(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedWorkType = val);
            },
          ),

          const SizedBox(height: 10),

          // 6. Notes / Guidelines
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes / Guidelines',
              hintText: 'e.g. 3 reels per week, transformation posts',
              prefixIcon: const Icon(
                Remix.sticky_note_line,
                size: 18,
                color: AppColors.primaryDark,
              ),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.outfit(fontSize: 13),
          ),

          const SizedBox(height: 14),

          // 7. Submit Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: state.isSaving ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: state.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'SUBMIT ACCOUNT DETAILS',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsListSection(SocialMediaWorkState state) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.handlers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            const Icon(
              Remix.share_line,
              size: 36,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'No Social Media Accounts Linked',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the form above to add your active social media handles.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked Accounts (${state.handlers.length})',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.handlers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = state.handlers[index];
            final isItemEditing = _editingAccount?.id == item.id;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isItemEditing
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: isItemEditing ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.subtleGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.platform == 'INSTAGRAM'
                          ? Remix.instagram_line
                          : item.platform == 'FACEBOOK'
                          ? Remix.facebook_fill
                          : item.platform == 'YOUTUBE'
                          ? Remix.youtube_fill
                          : item.platform == 'LINKEDIN'
                          ? Remix.linkedin_fill
                          : Remix.global_line,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.accountName,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${item.platform} • ${item.workType}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (item.handlerName != null &&
                            item.handlerName!.isNotEmpty)
                          Text(
                            'Handler: ${item.handlerName}',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Remix.edit_line,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    tooltip: 'Edit Account',
                    onPressed: () => _startEditing(item),
                  ),
                  IconButton(
                    icon: const Icon(
                      Remix.delete_bin_line,
                      size: 18,
                      color: AppColors.error,
                    ),
                    tooltip: 'Delete Account',
                    onPressed: () => _deleteAccount(item),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
