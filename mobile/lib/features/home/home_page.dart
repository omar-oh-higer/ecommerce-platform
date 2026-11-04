import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

/// Placeholder until the catalogue arrives in the next step.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final user = state is Authenticated ? state.user : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Center(child: Text('Signed in as ${user?.name ?? ''} (${user?.email ?? ''})')),
    );
  }
}
