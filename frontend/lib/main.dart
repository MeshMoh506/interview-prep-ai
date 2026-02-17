import 'core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

// ...rest of your code...
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HireIQApp()));
}

class HireIQApp extends ConsumerWidget {
  const HireIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Read the router from your provider
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'HireIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // 2. Use the router instance here
      routerConfig: router,
    );
  }
}
