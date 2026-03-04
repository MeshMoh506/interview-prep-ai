// lib/features/shell/main_shell.dart
// Persistent bottom nav â€” biggest UX improvement for mobile
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab(
        icon: Icons.home_outlined,
        active: Icons.home_rounded,
        label: 'Home',
        path: '/home'),
    _Tab(
        icon: Icons.description_outlined,
        active: Icons.description_rounded,
        label: 'Resume',
        path: '/resumes'),
    _Tab(
        icon: Icons.mic_none_rounded,
        active: Icons.mic_rounded,
        label: 'Interview',
        path: '/interview'),
    _Tab(
        icon: Icons.map_outlined,
        active: Icons.map_rounded,
        label: 'Roadmap',
        path: '/roadmap'),
  ];

  int _index(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).matchedLocation;
    if (loc.startsWith('/resumes') || loc.startsWith('/resume')) return 1;
    if (loc.startsWith('/interview')) return 2;
    if (loc.startsWith('/roadmap')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _index(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: AppColors.darkSurface,
            border: const Border(top: BorderSide(color: AppColors.darkBorder)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, -4))
            ]),
        child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                  children: _tabs.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final sel = i == cur;
                return Expanded(
                    child: _NavItem(
                        tab: t,
                        selected: sel,
                        onTap: () {
                          if (!sel) context.go(t.path);
                        }));
              }).toList()),
            )),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.tab, required this.selected, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                  color: sel
                      ? AppColors.violet.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20)),
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(sel ? widget.tab.active : widget.tab.icon,
                      key: ValueKey(sel),
                      size: 22,
                      color: sel ? AppColors.violet : AppColors.darkInk40))),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? AppColors.violet : AppColors.darkInk40),
              child: Text(widget.tab.label)),
        ]),
      ),
    );
  }
}

class _Tab {
  final IconData icon, active;
  final String label, path;
  const _Tab(
      {required this.icon,
      required this.active,
      required this.label,
      required this.path});
}


