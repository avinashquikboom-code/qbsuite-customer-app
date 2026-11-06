import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}
class _LoginViewState extends ConsumerState<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
      child: AutofillGroup(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(AppConfig.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), const Text('Sign in to continue'), const SizedBox(height: 24),
        AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username]),
        const SizedBox(height: 16),
        AppTextField(label: 'Password', controller: _password, obscureText: true, autofillHints: const [AutofillHints.password]),
        const SizedBox(height: 16),
        if (auth.hasError) Text(auth.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        AppButton(label: 'Sign in', loading: auth.isLoading, onPressed: () => ref.read(authViewModelProvider.notifier).signIn(_email.text, _password.text)),
      ])))))));
  }
}
