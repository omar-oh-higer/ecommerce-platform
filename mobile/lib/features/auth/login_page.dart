import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.read<AuthCubit>().login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final loading = state is AuthLoading;
    final failure = state is Unauthenticated ? state.failure : null;
    final expired = state is Unauthenticated && state.sessionExpired;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sign in',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    if (expired) ...[
                      const SessionExpiredBanner(),
                      const SizedBox(height: 16),
                    ],
                    if (failure != null) ...[
                      FailureBanner(failure),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                          labelText: 'Password', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter your password' : null,
                      onFieldSubmitted: (_) => loading ? null : _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => context.go('/register'),
                      child: const Text('Create an account'),
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
