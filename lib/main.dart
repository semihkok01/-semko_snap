import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
// import 'services/api_service.dart'; // Only used in comments
import 'utils/app_format.dart';
import 'widgets/app_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppFormat.initialize();

  // 🔧 API Configuration
  // For development with local PHP server: http://localhost:8000
  // For production: https://it-dienst-hamburg.de/semkosnap/api
  // Uncomment the line below for development:
  // ApiService.setBaseUrl('http://localhost:8000');

  runApp(const SemkoScanApp());
}

class SemkoScanApp extends StatelessWidget {
  const SemkoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);
    const background = Color(0xFFF8FAFC);
    const accent = Color(0xFFF59E0B);

    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..bootstrap(),
      child: MaterialApp(
        title: 'Semko Scan',
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Inter',
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            primary: primary,
            secondary: accent,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: background,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: background,
            foregroundColor: Colors.black87,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: primary, width: 1.4),
            ),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isInitialized) {
              return const _SplashScreen();
            }

            return auth.isAuthenticated
                ? const DashboardScreen()
                : const LoginScreen();
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            AppLogo(size: 120, radius: 28),
            SizedBox(height: 20),
            Text(
              'Semko Scan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
