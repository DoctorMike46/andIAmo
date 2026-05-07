import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import 'data/favorites_api.dart';
import 'widgets/favorite_button.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFavs = ref.watch(favoritesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('I miei preferiti')),
      body: asyncFavs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (locales) {
          if (locales.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_outline,
              title: 'Nessun preferito ancora',
              message:
                  'Tocca il cuoricino su un locale per salvarlo qui per dopo.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space3,
                AppTheme.space3,
                AppTheme.space3,
                AppTheme.space5,
              ),
              itemCount: locales.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppTheme.space2),
              itemBuilder: (_, i) {
                final l = locales[i];
                return Card(
                  child: InkWell(
                    onTap: () => context.push('/locales/${l.id}'),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(AppTheme.radiusLarge),
                          ),
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: l.primaryMediaUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: l.primaryMediaUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.storefront, size: 32),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.space3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('${l.type} · ${l.city}',
                                    style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text('€' * l.priceLevel,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        FavoriteButton(localeId: l.id, size: 22),
                        const SizedBox(width: AppTheme.space2),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
