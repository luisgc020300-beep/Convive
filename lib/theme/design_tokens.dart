// lib/theme/design_tokens.dart
//
// Identidad visual de Convive: "la pared del piso", de noche o de día según
// el tema elegido. Fondo cálido (no el negro azulado ni el blanco puro por
// defecto de Material) con acentos de materiales físicos de un piso
// compartido -- corcho, post-its, recibos. Cada acento tiene un significado
// fijo, no es decoración intercambiable, y su tono (más pálido en oscuro,
// más saturado en claro) cambia para mantener contraste en cada modo.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores con significado de la app, accesibles vía `context.colors.x` --
/// se resuelven al tema activo (oscuro/claro), a diferencia de una
/// constante fija que no podría cambiar con el modo.
class ConviveColorsExt extends ThemeExtension<ConviveColorsExt> {
  const ConviveColorsExt({
    required this.wall,
    required this.cork,
    required this.corkDark,
    required this.paper,
    required this.paperMuted,
    required this.amber,
    required this.coral,
    required this.mint,
    required this.rust,
    required this.onAccent,
  });

  final Color wall; // fondo general
  final Color cork; // superficie de tarjetas
  final Color corkDark; // corcho / campos de entrada, más marcado que una tarjeta suelta
  final Color paper; // texto principal
  final Color paperMuted; // texto secundario
  final Color amber; // Tareas / calendario
  final Color coral; // Chat
  final Color mint; // Pagos / dinero a favor
  final Color rust; // dinero en contra / tarea fallada
  final Color onAccent; // texto/icono sobre un fondo ámbar o menta rellenos

  static const dark = ConviveColorsExt(
    wall: Color(0xFF1C1815),
    cork: Color(0xFF33281F),
    corkDark: Color(0xFF241C16),
    paper: Color(0xFFF2EAD9),
    paperMuted: Color(0xFFB8AC98),
    amber: Color(0xFFE8B94E),
    coral: Color(0xFFE8735A),
    mint: Color(0xFF6FBF8B),
    rust: Color(0xFFC96450),
    onAccent: Color(0xFF241A05),
  );

  static const light = ConviveColorsExt(
    wall: Color(0xFFF5F0E8),
    cork: Color(0xFFE8DCC8),
    corkDark: Color(0xFFDCCDB0),
    paper: Color(0xFF2A2118),
    paperMuted: Color(0xFF6B5D4A),
    amber: Color(0xFFA6741E),
    coral: Color(0xFFC24E36),
    mint: Color(0xFF2F7D52),
    rust: Color(0xFFA13F2C),
    onAccent: Color(0xFFFFFFFF),
  );

  @override
  ConviveColorsExt copyWith({
    Color? wall, Color? cork, Color? corkDark, Color? paper, Color? paperMuted,
    Color? amber, Color? coral, Color? mint, Color? rust, Color? onAccent,
  }) {
    return ConviveColorsExt(
      wall: wall ?? this.wall,
      cork: cork ?? this.cork,
      corkDark: corkDark ?? this.corkDark,
      paper: paper ?? this.paper,
      paperMuted: paperMuted ?? this.paperMuted,
      amber: amber ?? this.amber,
      coral: coral ?? this.coral,
      mint: mint ?? this.mint,
      rust: rust ?? this.rust,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  ConviveColorsExt lerp(ThemeExtension<ConviveColorsExt>? other, double t) {
    if (other is! ConviveColorsExt) return this;
    return t < 0.5 ? this : other;
  }
}

extension ConviveThemeContextX on BuildContext {
  ConviveColorsExt get colors => Theme.of(this).extension<ConviveColorsExt>()!;
}

class ConviveColors {
  ConviveColors._();

  // Colores de post-it, cíclicos -- son objetos físicos de color fijo (un
  // post-it amarillo es amarillo de día o de noche), no cambian con el
  // tema. Sin significado individual, solo dan variedad visual al corcho.
  static const postIts = [
    Color(0xFFE8B94E), Color(0xFFE8735A), Color(0xFF6FBF8B), Color(0xFFB08FD8),
  ];
}

class ConviveText {
  ConviveText._();

  static TextTheme uiTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final palette = brightness == Brightness.dark ? ConviveColorsExt.dark : ConviveColorsExt.light;
    return GoogleFonts.figtreeTextTheme(base.textTheme).apply(
      bodyColor: palette.paper,
      displayColor: palette.paper,
    );
  }

  /// Letra de rotulador a mano -- solo para el texto de las notas del
  /// corcho, nunca para la interfaz general. El post-it es un objeto físico
  /// de color fijo, así que por defecto usa el mismo marrón oscuro en
  /// cualquier tema (se puede pisar con [color] si hace falta).
  static TextStyle handwritten({double fontSize = 16, Color color = const Color(0xFF2A2118)}) =>
      GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.15,
      );

  /// Letra mono -- solo para importes de dinero en Pagos, para que se lean
  /// como un recibo en vez de texto normal.
  static TextStyle amount({required Color color, double fontSize = 16, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
      );
}

ThemeData _buildConviveTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? ConviveColorsExt.dark : ConviveColorsExt.light;
  final textTheme = ConviveText.uiTextTheme(brightness);
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: palette.wall,
    textTheme: textTheme,
    extensions: [palette],
    colorScheme: ColorScheme(
      brightness: brightness,
      surface: palette.cork,
      onSurface: palette.paper,
      primary: palette.amber,
      onPrimary: palette.onAccent,
      secondary: palette.coral,
      onSecondary: palette.onAccent,
      tertiary: palette.mint,
      onTertiary: palette.onAccent,
      error: palette.rust,
      onError: palette.onAccent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.wall,
      foregroundColor: palette.paper,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: palette.cork,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: palette.paperMuted.withValues(alpha: 0.2),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.corkDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: palette.paperMuted.withValues(alpha: 0.7)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.amber,
        foregroundColor: palette.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.paper,
      unselectedLabelColor: palette.paperMuted,
      indicatorColor: palette.amber,
    ),
  );
}

ThemeData buildConviveDarkTheme() => _buildConviveTheme(Brightness.dark);
ThemeData buildConviveLightTheme() => _buildConviveTheme(Brightness.light);
