import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import 'data/friends_api.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amici'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'I miei'),
              Tab(text: 'Richieste'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Cerca utente',
              onPressed: () => _openSearch(context),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _FriendsTab(),
            _RequestsTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SearchUsersSheet(),
    );
    ref.invalidate(outgoingRequestsProvider);
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFriends = ref.watch(friendsListProvider);
    return asyncFriends.when(
      data: (friends) {
        if (friends.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'Nessun amico ancora',
            message: 'Usa l\'icona ➕ in alto per cercare e aggiungere persone.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(friendsListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _FriendTile(friend: friends[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIn = ref.watch(incomingRequestsProvider);
    final asyncOut = ref.watch(outgoingRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(outgoingRequestsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _SectionHeader('In arrivo'),
          asyncIn.when(
            data: (rs) => rs.isEmpty
                ? const _InlineEmpty('Nessuna richiesta in arrivo.')
                : Column(children: [
                    for (final r in rs)
                      _RequestTile(request: r, incoming: true),
                  ]),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore: $e'),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Inviate'),
          asyncOut.when(
            data: (rs) => rs.isEmpty
                ? const _InlineEmpty('Nessuna richiesta inviata.')
                : Column(children: [
                    for (final r in rs)
                      _RequestTile(request: r, incoming: false),
                  ]),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore: $e'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend});
  final FriendCard friend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(friend.initial)),
        title: Text(friend.displayName),
        subtitle: friend.fullName != null ? Text(friend.email) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'remove') {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(friendsApiProvider).remove(friend.id);
                ref.invalidate(friendsListProvider);
                messenger.showSnackBar(const SnackBar(content: Text('Amicizia rimossa.')));
              } on DioException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request, required this.incoming});
  final FriendRequest request;
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(request.user.initial)),
        title: Text(request.user.displayName),
        subtitle: Text(request.user.email),
        trailing: incoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _respond(context, ref, accept: true),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _respond(context, ref, accept: false),
                  ),
                ],
              )
            : const Text('In attesa'),
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(friendsApiProvider).respond(request.id, accept: accept);
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(friendsListProvider);
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}

class _SearchUsersSheet extends ConsumerStatefulWidget {
  const _SearchUsersSheet();

  @override
  ConsumerState<_SearchUsersSheet> createState() => _SearchUsersSheetState();
}

class _SearchUsersSheetState extends ConsumerState<_SearchUsersSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<FriendCard> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q.trim()));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(friendsApiProvider).search(q);
      if (!mounted) return;
      setState(() => _results = results);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(FriendCard user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(friendsApiProvider).sendRequest(user.email);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Richiesta inviata a ${user.displayName}.')));
      Navigator.of(context).pop();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String _friendlyError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) return 'Utente non trovato.';
    if (code == 409) return 'Già amici o richiesta in attesa.';
    if (code == 400) return 'Operazione non valida.';
    return 'Errore di rete.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cerca utente', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Email o nome',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onChanged,
              ),
              const SizedBox(height: 12),
              if (_loading) const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(u.initial)),
                      title: Text(u.displayName),
                      subtitle: Text(u.email),
                      trailing: FilledButton.tonal(
                        onPressed: () => _send(u),
                        child: const Text('Aggiungi'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
