import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/favorites_api.dart';

/// Heart-shaped toggle to favorite/unfavorite a locale. Reflects optimistic
/// state and refreshes the list provider on success.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.localeId, this.size = 24});

  final String localeId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIds = ref.watch(favoriteIdsProvider);
    final isFav = asyncIds.maybeWhen(
      data: (ids) => ids.contains(localeId),
      orElse: () => false,
    );
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: isFav ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        size: size,
        color: isFav ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: () => _toggle(context, ref, currentlyFav: isFav),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref,
      {required bool currentlyFav}) async {
    final api = ref.read(favoritesApiProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (currentlyFav) {
        await api.remove(localeId);
      } else {
        await api.add(localeId);
      }
      ref.invalidate(favoritesListProvider);
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}
