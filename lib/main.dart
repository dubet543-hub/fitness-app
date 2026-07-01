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
  await loadAppThemeMode();
  try {
    await NotificationService.init();
  } catch (_) {}
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        // Resolve the chosen mode to a concrete brightness, swap the live
        // palette to match, then build the theme from it.
        final brightness = effectiveBrightness(mode);
        applyBrightness(brightness);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: kIsLight ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: kBg,
            systemNavigationBarIconBrightness: kIsLight ? Brightness.dark : Brightness.light,
          ),
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SolidCore AMS',
          theme: buildAppTheme(),
          home: const AuthScreen(),
        );
      },
    );
  }
}
