// lib/theme/design_tokens.dart
//
// Identidad visual de Convive: "la pared del piso de noche". Fondo cálido
// oscuro (no el negro azulado por defecto de Material) con acentos de
// materiales físicos de un piso compartido -- corcho, post-its, recibos.
// Cada acento tiene un significado fijo, no es decoración intercambiable.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConviveColors {
  ConviveColors._();

  static const wall = Color(0xFF1C1815); // fondo general
  static const cork = Color(0xFF33281F); // superficie de tarjetas
  static const corkDark = Color(0xFF241C16); // corcho, más oscuro que una tarjeta suelta
  static const paper = Color(0xFFF2EAD9); // texto principal sobre fondo oscuro
  static const paperMuted = Color(0xFFB8AC98); // texto secundario

  static const amber = Color(0xFFE8B94E); // Tareas / calendario
  static const coral = Color(0xFFE8735A); // Chat
  static const mint = Color(0xFF6FBF8B); // Pagos / dinero a favor
  static const rust = Color(0xFFC96450); // dinero en contra / fallado

  // Colores de post-it, cíclicos -- no llevan significado individual, solo
  // dan variedad visual al corcho.
  static const postIts = [amber, coral, mint, Color(0xFFB08FD8)];
}

class ConviveText {
  ConviveText._();

  static TextTheme uiTextTheme() =>
      GoogleFonts.figtreeTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: ConviveColors.paper,
        displayColor: ConviveColors.paper,
      );

  /// Letra de rotulador a mano -- solo para el texto de las notas del
  /// corcho, nunca para la interfaz general.
  static TextStyle handwritten({double fontSize = 16, Color? color}) =>
      GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color ?? const Color(0xFF2A2118),
        height: 1.15,
      );

  /// Letra mono -- solo para importes de dinero en Pagos, para que se lean
  /// como un recibo en vez de texto normal.
  static TextStyle amount({double fontSize = 16, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? ConviveColors.paper,
      );
}

ThemeData buildConviveTheme() {
  final textTheme = ConviveText.uiTextTheme();
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ConviveColors.wall,
    textTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      surface: ConviveColors.cork,
      primary: ConviveColors.amber,
      secondary: ConviveColors.coral,
      tertiary: ConviveColors.mint,
      onSurface: ConviveColors.paper,
      onPrimary: Color(0xFF241A05),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ConviveColors.wall,
      foregroundColor: ConviveColors.paper,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: ConviveColors.cork,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: ConviveColors.paperMuted.withValues(alpha: 0.2),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ConviveColors.corkDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: ConviveColors.paperMuted.withValues(alpha: 0.7)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ConviveColors.amber,
        foregroundColor: const Color(0xFF241A05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: ConviveColors.paper,
      unselectedLabelColor: ConviveColors.paperMuted,
      indicatorColor: ConviveColors.amber,
    ),
  );
}
