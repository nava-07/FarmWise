import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/language_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/welcome_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AIService().init();

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();
    await WelcomeService.checkAndShowWelcomeNotification();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmWise',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
      home: const SplashScreen(),
    );
  }
}
