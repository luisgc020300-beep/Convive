// lib/theme/theme_notifier.dart
import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  // Sin decisión de identidad visual tomada todavía (a diferencia del modo
  // oscuro exclusivo de RiskRunner) — de momento sigue el tema del sistema.
  ThemeMode get mode => ThemeMode.system;
}
