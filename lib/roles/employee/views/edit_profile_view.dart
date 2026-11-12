import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/utils/permission_service.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_attendance_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_required_dialog.dart';

class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  File? _selectedAvatarFile;

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  late final TextEditingController _departmentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _designationController = TextEditingController();
    _departmentController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateFromProfile();
    });
  }

  void _populateFromProfile() {
    final profile = ref.read(employeeProfileProvider).asData?.value;
    final empInfo = ref.read(employeeAttendanceProvider).status.employee;
    final authState = ref.read(loginStateProvider);

    final name = profile?.name.isNotEmpty == true && profile!.name != 'Employee'
        ? profile.name
        : (empInfo?.name.isNotEmpty == true
              ? empInfo!.name
              : (authState.userName ?? ''));

    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : (empInfo?.email.isNotEmpty == true
              ? empInfo!.email
              : (authState.userEmail ?? ''));

    final phone = (profile != null && profile.phone.isNotEmpty)
        ? profile.phone
        : ((empInfo?.phone != null && empInfo!.phone!.isNotEmpty)
              ? empInfo.phone!
              : '');

    final designation =
        profile?.designation.isNotEmpty == true &&
            profile!.designation != 'Staff'
        ? profile.designation
        : (empInfo?.designation.isNotEmpty == true
              ? empInfo!.designation
              : (authState.userRole ?? ''));

    final department =
        profile?.department.isNotEmpty == true &&
            profile!.department != 'General'
        ? profile.department
        : (empInfo?.department.isNotEmpty == true ? empInfo!.department : '');

    if (mounted) {
      setState(() {
        if (_nameController.text.isEmpty) _nameController.text = name;
        if (_emailController.text.isEmpty) _emailController.text = email;
        if (_phoneController.text.isEmpty) _phoneController.text = phone;
        if (_designationController.text.isEmpty) {
          _designationController.text = designation;
        }
        if (_departmentController.text.isEmpty) {
          _departmentController.text = department;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Simulate API save
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isSaving = false);

    AppToast.success(context, 'Profile updated successfully.', title: 'Saved');
    Navigator.pop(context);
  }

  Future<void> _handlePhotoSelection() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Photo',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Remix.camera_line, color: AppColors.primary),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Use camera to capture a new photo',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Remix.image_line, color: AppColors.primary),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Select from photos using Android Photo Picker',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final permissionService = ref.read(permissionServiceProvider);

    if (source == ImageSource.camera) {
      var camStatus = await permissionService.checkCameraPermission();
      if (!camStatus.isGranted) {
        if (!mounted) return;
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => PermissionRequiredDialog(
            title: 'Camera Access Required',
            description:
                'QB Suite needs camera access so you can take a profile photo.',
            icon: Remix.camera_line,
            isPermanentlyDenied: camStatus.isPermanentlyDenied,
            onAllow: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
            onOpenSettings: () {
              permissionService.openAppSettings();
              Navigator.of(context).pop(false);
            },
          ),
        );
        if (shouldRequest != true) return;
        camStatus = await permissionService.requestCameraPermission();
        if (!camStatus.isGranted) return;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        setState(() {
          _selectedAvatarFile = File(pickedFile.path);
        });
        AppToast.success(context, 'Profile photo updated.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to select image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: AppBarTitles.editProfile,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _handleSave,
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar section
              _buildAvatarSection(),
              const SizedBox(height: 28),

              // Personal Info
              _buildSectionLabel('Personal Information'),
              const SizedBox(height: 12),
              _buildField(
                controller: _nameController,
                label: 'Full Name',
                icon: Remix.user_3_line,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _emailController,
                label: 'Work Email',
                icon: Remix.mail_line,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _phoneController,
                label: 'Mobile Number',
                icon: Remix.smartphone_line,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                ],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Phone is required'
                    : null,
              ),

              const SizedBox(height: 28),

              // Work Info
              _buildSectionLabel('Work Details'),
              const SizedBox(height: 12),
              _buildField(
                controller: _designationController,
                label: 'Designation',
                icon: Remix.briefcase_line,
                readOnly: true,
                helperText: 'Contact HR to update your designation',
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _departmentController,
                label: 'Department',
                icon: Remix.building_line,
                readOnly: true,
                helperText: 'Contact HR to update your department',
              ),

              const SizedBox(height: 32),

              // Change Password Section
              _buildChangePasswordCard(),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Remix.save_line, size: 18),
                  label: Text(
                    _isSaving ? 'Saving…' : 'Save Changes',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final empInfo = ref.watch(employeeAttendanceProvider).status.employee;
    final authState = ref.watch(loginStateProvider);

    final name = profile?.name.isNotEmpty == true && profile!.name != 'Employee'
        ? profile.name
        : (empInfo?.name.isNotEmpty == true
              ? empInfo!.name
              : (authState.userName ?? ''));
    final initials = name
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join('')
        .toUpperCase();
    final profilePhoto = profile?.profilePhoto ?? empInfo?.profilePhoto;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF1AA14D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(
                  child: _selectedAvatarFile != null
                      ? Image.file(
                          _selectedAvatarFile!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        )
                      : (profilePhoto != null && profilePhoto.trim().isNotEmpty)
                      ? Image.network(
                          profilePhoto,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initials.isNotEmpty ? initials : 'EM',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials.isNotEmpty ? initials : 'EM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                          ),
                        ),
                ),
              ),
              GestureDetector(
                onTap: _handlePhotoSelection,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Remix.camera_line,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap camera to change photo',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      validator: validator,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: readOnly ? AppColors.textPlaceholder : AppColors.primary,
        ),
        helperText: helperText,
        helperStyle: GoogleFonts.outfit(
          fontSize: 11,
          color: AppColors.textPlaceholder,
        ),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return InkWell(
      onTap: () => _showChangePasswordSheet(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Remix.lock_2_line,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Update your account password',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Remix.arrow_right_s_line,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showCurrent = false;
    bool showNew = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Password',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              // Current password
              _buildPasswordField(
                controller: currentCtrl,
                label: 'Current Password',
                isVisible: showCurrent,
                onToggle: () => setModalState(() => showCurrent = !showCurrent),
              ),
              const SizedBox(height: 14),
              _buildPasswordField(
                controller: newCtrl,
                label: 'New Password',
                isVisible: showNew,
                onToggle: () => setModalState(() => showNew = !showNew),
              ),
              const SizedBox(height: 14),
              _buildPasswordField(
                controller: confirmCtrl,
                label: 'Confirm New Password',
                isVisible: showNew,
                onToggle: () => setModalState(() => showNew = !showNew),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (newCtrl.text != confirmCtrl.text) {
                      AppToast.error(context, 'Passwords do not match.');
                      return;
                    }
                    Navigator.pop(context);
                    AppToast.success(
                      context,
                      'Password changed successfully.',
                      title: 'Done',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Update Password',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Remix.lock_2_line,
          size: 18,
          color: AppColors.textSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Remix.eye_off_line : Remix.eye_line,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
