import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await ApiService.loadConfig();
  runApp(const FitnessApp());

  // Android permission dialogs require a resumed Activity. Calling the
  // notification plugin before runApp() can make POST_NOTIFICATIONS (and the
  // exact-alarm settings intent) fail silently on Android while still working
  // on iOS. Wait until the first frame so the Activity is ready.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService.init();
    } catch (_) {}
  });
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: kBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SolidCore AMS',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const AuthScreen(),
    );
  }
}
