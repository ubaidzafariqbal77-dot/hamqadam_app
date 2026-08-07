import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'constants/app_strings.dart';
import 'controllers/theme_controller.dart';
import 'core/dependency/app_dependencies.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register all app-lifetime dependencies (no Bindings classes).
  await AppDependencies.init();
  runApp(const HamQadamApp());
}

class HamQadamApp extends StatelessWidget {
  const HamQadamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = Get.find<ThemeController>();
    // Reactive themeMode: switching in the drawer rebuilds MaterialApp with the
    // new mode. The navigator is preserved (stable GetX key), so routes/state
    // are not lost. All colours come from AppTheme.light / AppTheme.dark.
    return Obx(
      () => GetMaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.mode.value,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}
