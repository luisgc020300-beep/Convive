// lib/main.dart
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'core/service_locator.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'screens/household_gate_screen.dart';
import 'screens/login_screen.dart';
import 'services/household_service.dart';
import 'theme/design_tokens.dart';
import 'theme/locale_controller.dart';
import 'theme/theme_controller.dart';

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
  final themeController = await ThemeController.load();
  final localeController = await LocaleController.load();

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      HouseholdService.asegurarPerfilUsuario();
      HouseholdService.reconciliarHouseholdIds();
    }
  });

  runApp(ConviveApp(themeController: themeController, localeController: localeController));
}

class ConviveApp extends StatelessWidget {
  const ConviveApp({required this.themeController, required this.localeController, super.key});

  final ThemeController themeController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, localeController]),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Convive',
        themeMode: themeController.mode,
        theme: buildConviveLightTheme(),
        darkTheme: buildConviveDarkTheme(),
        locale: localeController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
      ),
    );
  }
}
