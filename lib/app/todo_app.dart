import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../constants/app_routes.dart';
import '../presentation/components/momentum_ui.dart';
import '../presentation/providers/theme_provider.dart';
import '../theme/app_theme.dart';

class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'TaskTrackr',
      themeMode: themeMode,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      scaffoldMessengerKey: rootMessengerKey,
      routeInformationParser: AppRoutes.router.routeInformationParser,
      routerDelegate: AppRoutes.router.routerDelegate,
      routeInformationProvider: AppRoutes.router.routeInformationProvider,
    );
  }
}
