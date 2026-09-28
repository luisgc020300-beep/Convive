// lib/main.dart
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

  // App Check: Play Integrity (Android) / App Attest (iOS) en release, token
  // de depuración en debug. Sin proveedor de reCAPTCHA configurado para web
  // todavía, así que se salta ahí (web es solo para previsualizar cambios
  // en local, no el objetivo real de la app).
  //
  // IMPORTANTE -- no activar "Enforce" en la consola de Firebase todavía:
  // los builds actuales de Android/iOS se instalan por sideload (Sideloadly/
  // APK suelto), no desde Play Store/TestFlight, así que Play Integrity y
  // App Attest no pueden validarlos de verdad. Activar el modo estricto
  // ahora mismo bloquearía las llamadas a Firestore/Cloud Functions en los
  // dispositivos de prueba. Dejar en modo "Monitor" (el de por defecto)
  // hasta que la app pase a TestFlight/Play Store de verdad.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
    );
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Crashlytics no tiene implementación web -- solo Android/iOS. Sin este
  // guard, arrancar en Chrome (flutter run -d chrome) revienta al intentar
  // leer una constante de plugin que no existe en esa plataforma.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

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
