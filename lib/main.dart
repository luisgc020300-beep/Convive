// lib/main.dart
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/service_locator.dart';
import 'firebase_options.dart';
import 'screens/household_gate_screen.dart';
import 'screens/login_screen.dart';
import 'services/household_service.dart';
import 'theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  await setupLocator();

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) HouseholdService.asegurarPerfilUsuario();
  });

  runApp(const ConviveApp());
}

class ConviveApp extends StatefulWidget {
  const ConviveApp({super.key});

  @override
  State<ConviveApp> createState() => _ConviveAppState();
}

class _ConviveAppState extends State<ConviveApp> {
  @override
  void initState() {
    super.initState();
    ThemeNotifier.instance.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Convive',
      themeMode: ThemeNotifier.instance.mode,
      theme: ThemeData(brightness: Brightness.light, textTheme: textTheme),
      darkTheme: ThemeData(brightness: Brightness.dark, textTheme: textTheme),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const HouseholdGateScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}
