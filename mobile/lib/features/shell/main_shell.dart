import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Total vertical space the floating pill nav occupies (nav + bottom padding).
/// FABs inside shell-tab screens use this to sit above the nav.
const double islandNavHeight = 76.0;

/// FAB location that shifts the standard endFloat above the floating pill nav.
class IslandAwareFabLocation extends FloatingActionButtonLocation {
  const IslandAwareFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) {
    final base = FloatingActionButtonLocation.endFloat.getOffset(g);
    return Offset(base.dx, base.dy - islandNavHeight);
  }

  @override
  String toString() => 'IslandAwareFabLocation';
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _IslandNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _items = <_NavItem>[
  _NavItem(Icons.explore_outlined, Icons.explore, 'Esplora'),
  _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Chiedi'),
  _NavItem(Icons.people_outline, Icons.people, 'Amici'),
  _NavItem(Icons.celebration_outlined, Icons.celebration, 'Uscite'),
  _NavItem(Icons.person_outline, Icons.person, 'Profilo'),
];

class _IslandNavBar extends StatelessWidget {
  const _IslandNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavTile(
                    item: _items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
