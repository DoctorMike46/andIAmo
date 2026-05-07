import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/stat_tile.dart';
import '../auth/auth_controller.dart';
import '../auth/data/auth_models.dart';
import '../favorites/data/favorites_api.dart';
import '../friends/data/friends_api.dart';
import '../outings/data/outings_api.dart';
import 'data/profile_api.dart';

const _consentLabels = {
  'terms_of_service': 'Termini di servizio',
  'privacy_policy': 'Privacy policy',
  'ai_profiling': 'Profilazione AI',
  'marketing_emails': 'Email marketing',
  'analytics': 'Analytics',
};

const _consentSubtitles = {
  'terms_of_service': 'Necessario per usare l\'app',
  'privacy_policy': 'Necessario per usare l\'app',
  'ai_profiling': 'Suggerimenti personalizzati',
  'marketing_emails': 'Newsletter e novità',
  'analytics': 'Statistiche di utilizzo anonime',
};

const _requiredConsents = {'terms_of_service', 'privacy_policy'};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthLoggedIn ? authState.user : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(user: user)),
          if (user != null) ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space5)),
            const SliverToBoxAdapter(child: _StatsRow()),
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space5)),
          ],
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Account',
                children: [
                  _CardTile(
                    icon: Icons.tune_outlined,
                    title: 'Le mie preferenze',
                    subtitle: 'Cucine, mood, budget, raggio',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/me/preferences'),
                  ),
                  const Divider(height: 1, indent: 60),
                  _CardTile(
                    icon: Icons.favorite_outline,
                    title: 'I miei preferiti',
                    subtitle: 'Locali che hai salvato',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/me/favorites'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space4)),
          if (user?.isAdmin ?? false) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
              sliver: SliverToBoxAdapter(
                child: _SectionCard(
                  title: 'Admin',
                  children: [
                    _CardTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Gestisci locali',
                      subtitle: 'Crea, modifica, elimina',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/locales'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space4)),
          ],
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Consensi',
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final asyncConsents = ref.watch(consentsProvider);
                      return asyncConsents.when(
                        data: (consents) =>
                            _ConsentsList(consents: consents),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(AppTheme.space4),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(AppTheme.space4),
                          child: Text('Errore: $e'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space4)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Privacy & dati',
                children: [
                  _CardTile(
                    icon: Icons.download_outlined,
                    title: 'Scarica i miei dati',
                    subtitle: 'Export JSON di tutti i tuoi dati',
                    onTap: () => _onExport(context, ref),
                  ),
                  const Divider(height: 1, indent: 60),
                  _CardTile(
                    icon: Icons.delete_forever,
                    iconColor: Theme.of(context).colorScheme.error,
                    title: 'Elimina account',
                    titleColor: Theme.of(context).colorScheme.error,
                    subtitle: 'Cancellazione permanente',
                    onTap: () => _onDelete(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space4)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                children: [
                  _CardTile(
                    icon: Icons.logout,
                    title: 'Esci',
                    onTap: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Future<void> _onExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(profileApiProvider).exportData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dati esportati'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: SelectableText(jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
          ],
        ),
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Copiato negli appunti.')));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export fallito: $e')));
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare l\'account?'),
        content: const Text(
          'Tutti i tuoi dati (preferenze, consensi, cronologia) saranno cancellati. '
          'Questa operazione è irreversibile.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileApiProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).logout();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Eliminazione fallita: $e')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final UserOut? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppTheme.space5,
        MediaQuery.of(context).padding.top + AppTheme.space5,
        AppTheme.space5,
        AppTheme.space6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(
              scheme.tertiary.withValues(alpha: 0.7),
              scheme.primary,
            ),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onPrimary.withValues(alpha: 0.2),
              border: Border.all(color: scheme.onPrimary, width: 3),
            ),
            child: Center(
              child: Text(
                _initial(user),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            user?.fullName ?? user?.email ?? '—',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          if (user?.fullName != null && user!.email != user!.fullName) ...[
            const SizedBox(height: AppTheme.space1),
            Text(
              user!.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _initial(UserOut? user) {
    if (user == null) return '?';
    if (user.fullName?.isNotEmpty ?? false) {
      return user.fullName!.substring(0, 1).toUpperCase();
    }
    return user.email.substring(0, 1).toUpperCase();
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFriends = ref.watch(friendsListProvider);
    final asyncOutings = ref.watch(outingsListProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.people_outline,
              value: asyncFriends.maybeWhen(
                data: (f) => '${f.length}',
                orElse: () => '–',
              ),
              label: 'AMICI',
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: StatTile(
              icon: Icons.celebration_outlined,
              value: asyncOutings.maybeWhen(
                data: (o) => '${o.length}',
                orElse: () => '–',
              ),
              label: 'USCITE',
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final asyncFavs = ref.watch(favoritesListProvider);
                return StatTile(
                  icon: Icons.favorite_outline,
                  value: asyncFavs.maybeWhen(
                    data: (l) => '${l.length}',
                    orElse: () => '–',
                  ),
                  label: 'PREFERITI',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space3,
              0,
              AppTheme.space3,
              AppTheme.space2,
            ),
            child: Text(
              title!.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space3,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? scheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? scheme.primary),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: titleColor,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ConsentsList extends ConsumerWidget {
  const _ConsentsList({required this.consents});
  final List<ConsentSnapshot> consents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byPurpose = {for (final c in consents) c.purpose: c};
    final purposes = _consentLabels.keys.toList();
    return Column(
      children: [
        for (var i = 0; i < purposes.length; i++) ...[
          _ConsentRow(
            purpose: purposes[i],
            granted: byPurpose[purposes[i]]?.granted ?? false,
            onChanged: _requiredConsents.contains(purposes[i])
                ? null
                : (v) => _toggle(context, ref, purpose: purposes[i], granted: v),
          ),
          if (i < purposes.length - 1) const Divider(height: 1, indent: 60),
        ],
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required String purpose,
    required bool granted,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileApiProvider).setConsent(purpose: purpose, granted: granted);
      ref.invalidate(consentsProvider);
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.purpose,
    required this.granted,
    required this.onChanged,
  });

  final String purpose;
  final bool granted;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(_iconFor(purpose), size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_consentLabels[purpose] ?? purpose,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  _consentSubtitles[purpose] ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(value: granted, onChanged: onChanged),
        ],
      ),
    );
  }

  IconData _iconFor(String purpose) => switch (purpose) {
        'terms_of_service' => Icons.gavel_outlined,
        'privacy_policy' => Icons.privacy_tip_outlined,
        'ai_profiling' => Icons.auto_awesome_outlined,
        'marketing_emails' => Icons.email_outlined,
        'analytics' => Icons.analytics_outlined,
        _ => Icons.info_outline,
      };
}
