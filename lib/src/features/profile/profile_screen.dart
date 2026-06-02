import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../shared/app_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return AppShell(
      title: 'Profil',
      selectedIndex: 3,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          user.when(
            data: (value) => Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(value?.nickname ?? 'Spieler'),
                subtitle: Text(value?.email ?? 'Anonymer Account'),
              ),
            ),
            error: (error, _) => Text(error.toString()),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-Mail',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _linkEmail,
            icon: const Icon(Icons.link),
            label: const Text('Verknüpfen'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(repositoryProvider).signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Abmelden'),
          ),
          const SizedBox(height: 24),
          const Text('Open Source · MIT License · de.capycode.voleo'),
        ],
      ),
    );
  }

  Future<void> _linkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    await ref.read(repositoryProvider).linkEmail(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail gespeichert.')),
      );
    }
  }
}
