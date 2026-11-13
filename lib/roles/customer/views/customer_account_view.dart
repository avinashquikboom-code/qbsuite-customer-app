import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_profile_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/viewmodels.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'social_media_work_handler_view.dart';
import 'customer_support_view.dart';

class CustomerAccountView extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOpenDrawer;

  const CustomerAccountView({
    super.key,
    this.onNavigateToTab,
    this.onOpenDrawer,
  });

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Remix.logout_box_r_line,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your customer workspace session?',
          style: GoogleFonts.outfit(
            fontSize: 14,
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
              await ref.read(loginStateProvider.notifier).logout();
              ref.invalidate(currentCustomerIdProvider);
              ref.invalidate(currentCustomerNameProvider);
              ref.invalidate(currentCustomerStateProvider);
              ref.invalidate(customerCalendarSelectedDateProvider);
              ref.invalidate(socialMediaWorkProvider);
              ref.invalidate(workProjectsProvider);
              ref.invalidate(leadsProvider);
              ref.invalidate(proposalsProvider);
              ref.invalidate(currentSubscriptionProvider);
              ref.invalidate(customerOrdersProvider);
              ref.invalidate(customerInvoicesProvider);
              ref.invalidate(paymentsProvider);
              ref.invalidate(customerSelectedWorkFilterProvider);
              ref.invalidate(customerProfileProvider);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerProfileModel profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileBottomSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(currentSubscriptionProvider);
    final profileAsync = ref.watch(customerProfileProvider);

    final customerNameAsync = ref.watch(currentCustomerNameProvider);
    final fallbackName =
        (customerNameAsync.asData?.value ??
                customerNameAsync.value ??
                'Customer')
            .trim();
    final customerBusinessAsync = ref.watch(currentCustomerBusinessProvider);
    final fallbackBusiness =
        (customerBusinessAsync.asData?.value ??
                customerBusinessAsync.value ??
                '')
            .trim();
    final fallbackPlan = subAsync.asData?.value?.planName ?? 'Standard Plan';
    final fallbackPlanCode = subAsync.asData?.value?.planCode ?? 'STANDARD';

    final fallbackProfile = CustomerProfileModel(
      id: 0,
      customerId: 'CUST-0000',
      name: fallbackName,
      companyName:
          (fallbackBusiness.isNotEmpty &&
              fallbackBusiness.toLowerCase() != fallbackName.toLowerCase())
          ? fallbackBusiness
          : 'Workspace',
      plan: fallbackPlan,
      planCode: fallbackPlanCode,
      subscriptionStatus: 'ACTIVE',
      isActive: true,
      userLimit: 5,
      leadLimit: 500,
      storageUsed: 0,
      storageLimit: 0,
    );

    final perms = ref.watch(permissionManagerProvider);
    if (!perms.customerCan('CUSTOMER_PROFILE', 'VIEW')) {
      return const PermissionGuardedView(
        moduleKey: 'CUSTOMER_PROFILE',
        moduleTitle: 'Account Details',
        child: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Account Details',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
            tooltip: 'Refresh Profile',
            onPressed: () async {
              await Future.wait([
                ref.read(customerProfileProvider.notifier).refreshProfile(),
                refreshAllCustomerSubscriptionData(ref),
              ]);
            },
          ),
          IconButton(
            icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _buildProfileContent(
          context,
          ref,
          profile ?? fallbackProfile,
          subAsync,
        ),
        loading: () => profileAsync.value != null
            ? _buildProfileContent(context, ref, profileAsync.value!, subAsync)
            : _buildLoadingSkeleton(),
        error: (err, _) => _buildErrorState(context, ref, err),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    CustomerProfileModel profile,
    AsyncValue<dynamic> subAsync,
  ) {
    final customerPersonName = profile.personFullName.isNotEmpty
        ? profile.personFullName
        : (profile.name.trim().isNotEmpty ? profile.name : 'Valued Customer');
    final customerEmail =
        profile.email ?? profile.user?.email ?? 'No email on record';
    final customerPhone =
        profile.phone ?? profile.user?.phone ?? 'Not provided';
    final alternatePhone = profile.alternatePhone ?? 'Not provided';
    final canEditProfile = ref
        .watch(permissionManagerProvider)
        .customerCan('CUSTOMER_PROFILE', 'EDIT');
    final activePlan = subAsync.asData?.value;
    final planName = (activePlan != null && activePlan.planName.isNotEmpty)
        ? activePlan.planName
        : (profile.plan.isNotEmpty ? profile.plan : 'Standard Plan');

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(customerProfileProvider.notifier).refreshProfile(),
          refreshAllCustomerSubscriptionData(ref),
        ]);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildAvatar(profile),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerPersonName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profile.businessWithCode.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.businessWithCode,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          customerEmail,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$planName Tier',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: profile.isActive
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: profile.isActive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canEditProfile)
                    IconButton(
                      icon: const Icon(
                        Remix.edit_box_line,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Edit Profile',
                      onPressed: () =>
                          _openEditProfileSheet(context, ref, profile),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Organization Information Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ORGANIZATION INFORMATION',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEditProfile)
                  InkWell(
                    onTap: () => _openEditProfileSheet(context, ref, profile),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Customer Name', customerPersonName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Customer ID', profile.customerId),
                  const SizedBox(height: 12),
                  _buildDetailRow('Company Name', profile.companyName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Workspace Domain', profile.domain ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Registered Email', customerEmail),
                  const SizedBox(height: 12),
                  _buildDetailRow('Contact Phone', customerPhone),
                  if (profile.alternatePhone != null &&
                      profile.alternatePhone!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Alternate Phone', alternatePhone),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailRow('Industry', profile.industry ?? 'General'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Primary Office', profile.formattedLocation),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Remix.price_tag_3_line,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Manage Subscription Plan',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Switch between Monthly & Yearly cycles',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                      onTap: () => onNavigateToTab?.call(1),
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.subtleGreenBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Remix.share_circle_line,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'SSM Account Access',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Linked Accounts & Schedules',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SocialMediaWorkHandlerView(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.pillBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Remix.file_list_3_line,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Invoices & Order History',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Download PDF tax receipts',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                      onTap: () => onNavigateToTab?.call(3),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // HELP & SUPPORT
            Text(
              'HELP & SUPPORT',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Remix.customer_service_2_line,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Customer Support & Helpdesk',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Create tickets, WhatsApp & 24/7 assistance',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Remix.arrow_right_s_line, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerSupportView(),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context, ref),
                icon: const Icon(Remix.logout_box_r_line, size: 18),
                label: Text(
                  'Sign Out of Customer Workspace',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(CustomerProfileModel profile) {
    if (profile.profileImage != null &&
        profile.profileImage!.trim().isNotEmpty &&
        profile.profileImage!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          profile.profileImage!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackAvatar(profile),
        ),
      );
    }
    return _buildFallbackAvatar(profile);
  }

  Widget _buildFallbackAvatar(CustomerProfileModel profile) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          profile.personInitials,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.error_warning_line,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Profile',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not load your customer profile data. Please verify your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await Future.wait([
                  ref.read(customerProfileProvider.notifier).refreshProfile(),
                  refreshAllCustomerSubscriptionData(ref),
                ]);
              },
              icon: const Icon(Remix.refresh_line, size: 16),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom Sheet for editing customer profile
class _EditProfileBottomSheet extends ConsumerStatefulWidget {
  final CustomerProfileModel profile;

  const _EditProfileBottomSheet({required this.profile});

  @override
  ConsumerState<_EditProfileBottomSheet> createState() =>
      _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState
    extends ConsumerState<_EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _altPhoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _industryController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _companyController = TextEditingController(
      text: widget.profile.companyName,
    );
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _altPhoneController = TextEditingController(
      text: widget.profile.alternatePhone ?? '',
    );
    _addressController = TextEditingController(
      text: widget.profile.address ?? '',
    );
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _stateController = TextEditingController(text: widget.profile.state ?? '');
    _countryController = TextEditingController(
      text: widget.profile.country ?? 'India',
    );
    _pincodeController = TextEditingController(
      text: widget.profile.pincode ?? '',
    );
    _industryController = TextEditingController(
      text: widget.profile.industry ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatePayload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'companyName': _companyController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (_altPhoneController.text.trim().isNotEmpty)
        'alternatePhone': _altPhoneController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'country': _countryController.text.trim(),
      'pincode': _pincodeController.text.trim(),
      'industry': _industryController.text.trim(),
    };

    try {
      final success = await ref
          .read(customerProfileProvider.notifier)
          .updateProfile(updatePayload);
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context);
          AppToast.success(context, 'Profile updated successfully!');
        } else {
          AppToast.error(
            context,
            'Unable to update profile. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, 'Update failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.90),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Customer Profile',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Remix.close_line),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                  ],
                ),
              ),

              // Scrollable Form Fields
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Customer / Business Name',
                        icon: Remix.building_line,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name cannot be empty'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _companyController,
                        label: 'Legal Company Name',
                        icon: Remix.briefcase_line,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Primary Phone Number',
                        icon: Remix.phone_line,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _altPhoneController,
                        label: 'Alternate Phone Number',
                        icon: Remix.phone_line,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _industryController,
                        label: 'Industry / Domain',
                        icon: Remix.pie_chart_line,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Office Address',
                        icon: Remix.map_pin_line,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Remix.building_2_line,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: 'State',
                              icon: Remix.government_line,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              icon: Remix.numbers_line,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _countryController,
                              label: 'Country',
                              icon: Remix.global_line,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Persistent Bottom Action Button (always above Android navigation / safe area)
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: bottomInset > 0
                      ? bottomInset + 12
                      : math.max(bottomPadding, 16.0),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderLight.withValues(alpha: 0.8),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
