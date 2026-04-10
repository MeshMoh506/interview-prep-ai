// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/locale/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge: transparent status + nav bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.darkOverlay); // default dark

  runApp(const ProviderScope(child: KatwahApp()));
}

class KatwahApp extends ConsumerWidget {
  const KatwahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isAr = locale.languageCode == 'ar';

    return _SystemUiUpdater(
      themeMode: themeMode,
      child: MaterialApp.router(
        title: 'خطوة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: AppRouter.router,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // RTL wrapper + text scaling clamp (prevents huge text on accessibility)
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
              ),
            ),
            child: Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),
          );
        },
      ),
    );
  }
}

// ── Watches theme changes and updates SystemChrome accordingly ───
class _SystemUiUpdater extends StatefulWidget {
  final ThemeMode themeMode;
  final Widget child;
  const _SystemUiUpdater({required this.themeMode, required this.child});

  @override
  State<_SystemUiUpdater> createState() => _SystemUiUpdaterState();
}

class _SystemUiUpdaterState extends State<_SystemUiUpdater>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateSystemUi(widget.themeMode);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-apply when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _updateSystemUi(widget.themeMode);
    }
  }

  @override
  void didUpdateWidget(_SystemUiUpdater old) {
    super.didUpdateWidget(old);
    if (old.themeMode != widget.themeMode) {
      _updateSystemUi(widget.themeMode);
    }
  }

  void _updateSystemUi(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
        isDark ? AppTheme.darkOverlay : AppTheme.lightOverlay);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
