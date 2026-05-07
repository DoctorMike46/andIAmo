import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../locales/data/locale_models.dart';
import '../locales/locales_controller.dart';
import 'data/admin_api.dart';

class AdminLocalesScreen extends ConsumerWidget {
  const AdminLocalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLocales = ref.watch(localesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Locali')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/locales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
      body: asyncLocales.when(
        data: (locales) => _LocalesAdminList(locales: locales),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

class _LocalesAdminList extends ConsumerWidget {
  const _LocalesAdminList({required this.locales});
  final List<LocaleSummary> locales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locales.isEmpty) {
      return const Center(child: Text('Nessun locale.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: locales.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final l = locales[i];
        return ListTile(
          title: Text(l.name),
          subtitle: Text('${l.type} · ${l.city}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifica',
                onPressed: () => context.push('/admin/locales/${l.id}'),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                tooltip: 'Elimina',
                onPressed: () => _confirmDelete(context, ref, l),
              ),
            ],
          ),
          onTap: () => context.push('/admin/locales/${l.id}'),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, LocaleSummary l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminare "${l.name}"?'),
        content: const Text('Operazione irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminApiProvider).delete(l.id);
      ref.invalidate(localesListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Eliminato.')));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}
