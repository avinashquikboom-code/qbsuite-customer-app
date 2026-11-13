import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../core/theme/app_colors.dart';
import '../services/customer_influencer_service.dart';
import '../viewmodels/customer_influencer_viewmodel.dart';
import 'influencer_application_status_view.dart';

/// Screen — Influencer Self-Registration View
class InfluencerRegistrationView extends ConsumerStatefulWidget {
  const InfluencerRegistrationView({super.key});

  @override
  ConsumerState<InfluencerRegistrationView> createState() =>
      _InfluencerRegistrationViewState();
}

class _InfluencerRegistrationViewState
    extends ConsumerState<InfluencerRegistrationView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _locationController = TextEditingController(text: 'India');
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _bioController = TextEditingController();
  final _followersController = TextEditingController();
  final _startingPriceController = TextEditingController();

  int? _selectedCategoryId;
  String _selectedPlatform = 'INSTAGRAM';
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _bioController.dispose();
    _followersController.dispose();
    _startingPriceController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(customerInfluencerServiceProvider);

      final followers = int.tryParse(_followersController.text.trim()) ?? 0;
      final startingPrice = double.tryParse(
        _startingPriceController.text.trim(),
      );

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'platform': _selectedPlatform,
        'location': _locationController.text.trim().isEmpty
            ? 'India'
            : _locationController.text.trim(),
        'city': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        'instagramHandle': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'youtubeHandle': _youtubeController.text.trim().isEmpty
            ? null
            : _youtubeController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'followers': followers,
        'categoryId': ?_selectedCategoryId,
        'startingPrice': ?startingPrice,
      };

      final created = await service.registerInfluencer(payload);

      if (!mounted) return;

      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application submitted! Status: ${created.status}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InfluencerApplicationStatusView(
              email:
                  created.email ?? _emailController.text.trim().toLowerCase(),
              initialInfluencer: created,
            ),
          ),
        );
      } else {
        throw Exception('Server returned empty registration response');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(customerInfluencerCategoriesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Join as an Influencer',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InfluencerApplicationStatusView(),
                ),
              );
            },
            child: Text(
              'Check Status',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
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
              // Header Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8F7EE), Color(0xFFD4EFE0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBEAD7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Remix.user_star_line,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Become a Verified Creator',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Submit your application. Once approved by admin, you will receive client bookings.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Personal & Account Information',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Full Name
              _buildTextField(
                controller: _nameController,
                label: 'Full Name *',
                hint: 'e.g. Rohan Joshi',
                prefixIcon: Remix.user_line,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Full name is required'
                    : null,
              ),

              const SizedBox(height: 14),

              // Email Address
              _buildTextField(
                controller: _emailController,
                label: 'Email Address *',
                hint: 'e.g. rohan.creator@gmail.com',
                prefixIcon: Remix.mail_line,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Mobile Number
              _buildTextField(
                controller: _phoneController,
                label: 'Mobile Number *',
                hint: 'e.g. 9876543210',
                prefixIcon: Remix.phone_line,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Mobile number is required'
                    : null,
              ),

              const SizedBox(height: 14),

              // Password
              _buildTextField(
                controller: _passwordController,
                label: 'Account Password *',
                hint: 'Minimum 6 characters',
                prefixIcon: Remix.lock_line,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Remix.eye_close_line : Remix.eye_line,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Creator Profile & Socials',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Category Picker
              categoriesAsync.when(
                data: (categories) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedCategoryId,
                        hint: Text(
                          'Select Category (Optional)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem<int>(
                            value: cat.id,
                            child: Text(
                              cat.name,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 14),

              // Primary Platform
              Text(
                'Primary Platform',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _selectedPlatform = 'INSTAGRAM'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedPlatform == 'INSTAGRAM'
                              ? const Color(0xFFFDF2F8)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPlatform == 'INSTAGRAM'
                                ? const Color(0xFFE1306C)
                                : Colors.grey.shade300,
                            width: _selectedPlatform == 'INSTAGRAM' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Remix.instagram_line,
                              color: Color(0xFFE1306C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instagram',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlatform == 'INSTAGRAM'
                                    ? const Color(0xFFE1306C)
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _selectedPlatform = 'YOUTUBE'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedPlatform == 'YOUTUBE'
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedPlatform == 'YOUTUBE'
                                ? Colors.red
                                : Colors.grey.shade300,
                            width: _selectedPlatform == 'YOUTUBE' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Remix.youtube_line,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'YouTube',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlatform == 'YOUTUBE'
                                    ? Colors.red
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Instagram Handle
              _buildTextField(
                controller: _instagramController,
                label: 'Instagram Profile / Handle',
                hint: '@username or profile link',
                prefixIcon: Remix.instagram_line,
              ),

              const SizedBox(height: 14),

              // YouTube Handle
              _buildTextField(
                controller: _youtubeController,
                label: 'YouTube Channel / URL',
                hint: '@channel or channel link',
                prefixIcon: Remix.youtube_line,
              ),

              const SizedBox(height: 14),

              // City & Location
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      hint: 'e.g. Mumbai',
                      prefixIcon: Remix.building_line,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _followersController,
                      label: 'Followers Count',
                      hint: 'e.g. 50000',
                      prefixIcon: Remix.group_line,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Bio
              _buildTextField(
                controller: _bioController,
                label: 'Bio & What you offer',
                hint:
                    'Describe your content niche, audience, and past campaign experience...',
                prefixIcon: Remix.file_text_line,
                maxLines: 3,
              ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Remix.check_line,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Submit Application',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
