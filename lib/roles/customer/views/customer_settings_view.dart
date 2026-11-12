import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';

class CustomerSettingsView extends ConsumerStatefulWidget {
  const CustomerSettingsView({super.key});

  @override
  ConsumerState<CustomerSettingsView> createState() =>
      _CustomerSettingsViewState();
}

class _CustomerSettingsViewState extends ConsumerState<CustomerSettingsView> {
  Future<void> _changePassword() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final dialogRoute = DialogRoute<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    );
    final passwordChanged = await navigator.push<bool>(dialogRoute);
    await dialogRoute.completed;

    if (!mounted || passwordChanged != true) return;

    AppToast.success(
      context,
      'Password changed. Please sign in with your new password.',
    );
    await ref.read(loginStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final login = ref.watch(loginStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(loginStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome${login.userName?.trim().isNotEmpty == true ? ', ${login.userName}' : ''}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (login.userEmail?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(login.userEmail!),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change password'),
                      subtitle: const Text(
                        'Update your customer login password',
                      ),
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newPassword.text.length < 6) {
      AppToast.error(context, 'New password must be at least 6 characters.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      AppToast.error(context, 'New passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            AppUrl.customerChangePassword,
            data: {
              'currentPassword': _currentPassword.text,
              'newPassword': _newPassword.text,
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final data = error.response?.data;
      final message = data is Map
          ? data['message']?.toString() ?? 'Unable to change password.'
          : 'Unable to change password.';
      AppToast.error(context, message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.error(context, 'Unable to change password. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password (at least 6 characters)',
            ),
          ),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update password'),
        ),
      ],
    );
  }
}
