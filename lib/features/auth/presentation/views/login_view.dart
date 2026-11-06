import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/responsive/responsive.dart';
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
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    return Scaffold(
      body: ResponsiveLoginLayout(
        logo: const AppLogo(),
        title: AppConfig.title,
        subtitle: 'Sign in to continue',
        form: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 16),
              if (auth.hasError)
                Text(
                  auth.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ResponsiveButton(
                label: 'Sign in',
                loading: auth.isLoading,
                onPressed: () => ref
                    .read(authViewModelProvider.notifier)
                    .signIn(_email.text, _password.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
