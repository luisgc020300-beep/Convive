// lib/screens/settings_screen.dart
//
// Mismo patrón que el settings_screen.dart de RiskRunner: cerrar sesión con
// confirmación, eliminar cuenta con confirmación explicando las
// consecuencias y manejando requires-recent-login. Estilo visual también
// tomado de RiskRunner (icono en chip cuadrado de color + título + subtítulo
// + accesorio), manteniendo las categorías propias de Convive -- Apariencia
// e Idioma siguen siendo filas que llevan a su propia subpantalla (no
// interruptores en línea, porque tienen 3 estados, no 2).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/design_tokens.dart';
import '../theme/locale_controller.dart';
import '../theme/theme_controller.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'notification_prefs_screen.dart';

// Colores de los chips de categoría -- fijos, no ligados al tema (como
// ConviveColors.postIts): son etiquetas de categoría de Ajustes, no
// acentos de significado en el resto de la app, así que no hace falta que
// cambien entre modo oscuro/claro.
class _BadgeColors {
  _BadgeColors._();
  static const apariencia = Color(0xFF4C5FA8);
  static const idioma = Color(0xFF3E8C86);
  static const notificaciones = Color(0xFFC9793D);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: AnimatedBuilder(
        animation: Listenable.merge([ThemeController.instance, LocaleController.instance]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsSection(children: [
              _SettingsRow(
                icon: Icons.dark_mode_rounded,
                badgeColor: _BadgeColors.apariencia,
                titulo: l10n.settingsAppearance,
                subtitulo: _nombreModoTema(l10n, ThemeController.instance.mode),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen())),
              ),
            ]),
            const SizedBox(height: 20),
            _SettingsSection(children: [
              _SettingsRow(
                icon: Icons.language_rounded,
                badgeColor: _BadgeColors.idioma,
                titulo: l10n.settingsLanguage,
                subtitulo: _nombreIdioma(l10n, LocaleController.instance.locale),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
              ),
            ]),
            const SizedBox(height: 20),
            _SettingsSection(children: [
              _SettingsRow(
                icon: Icons.notifications_rounded,
                badgeColor: _BadgeColors.notificaciones,
                titulo: l10n.settingsNotifications,
                subtitulo: l10n.settingsNotificationsSubtitle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPrefsScreen())),
              ),
            ]),
            const SizedBox(height: 20),
            Text(l10n.settingsAccount, style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.paperMuted)),
            const SizedBox(height: 8),
            _SettingsSection(children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                badgeColor: colors.amber,
                iconColor: colors.onAccent,
                titulo: l10n.settingsSignOut,
                tituloColor: colors.amber,
                onTap: _procesando ? null : _confirmarCerrarSesion,
                mostrarChevron: false,
              ),
              _SettingsRow(
                icon: Icons.delete_forever_rounded,
                badgeColor: colors.rust,
                iconColor: colors.onAccent,
                titulo: l10n.settingsDeleteAccount,
                tituloColor: colors.rust,
                onTap: _procesando ? null : _confirmarEliminarCuenta,
                mostrarChevron: false,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _nombreModoTema(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
        ThemeMode.dark => l10n.themeDark,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.system => l10n.themeSystem,
      };

  String _nombreIdioma(AppLocalizations l10n, Locale? locale) => switch (locale?.languageCode) {
        'es' => l10n.languageSpanish,
        'en' => l10n.languageEnglish,
        _ => l10n.languageSystem,
      };

  Future<void> _confirmarCerrarSesion() async {
    final l10n = context.l10n;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsSignOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await FirebaseAuth.instance.signOut();
    // El cambio de sesión lo detecta el StreamBuilder de MaterialApp y ya
    // muestra LoginScreen por debajo, pero esta pantalla sigue empujada
    // encima en la pila de navegación -- hay que volver a la raíz para que
    // se vea sin necesidad de pulsar "atrás" a mano.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmarEliminarCuenta() async {
    final l10n = context.l10n;
    final colors = context.colors;
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: colors.rust, size: 20),
            const SizedBox(width: 8),
            Text(l10n.settingsDeleteAccount),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsDeleteAccountBody),
            const SizedBox(height: 10),
            Text('• ${l10n.settingsDeleteBullet1}'),
            Text('• ${l10n.settingsDeleteBullet2}'),
            Text('• ${l10n.settingsDeleteBullet3}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final mensaje = e.code == 'requires-recent-login'
          ? l10n.settingsRequiresRecentLogin
          : l10n.settingsDeleteError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.colors.cork, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.badgeColor,
    required this.titulo,
    this.subtitulo,
    this.tituloColor,
    this.iconColor,
    this.onTap,
    this.mostrarChevron = true,
  });

  final IconData icon;
  final Color badgeColor;
  final String titulo;
  final String? subtitulo;
  final Color? tituloColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool mostrarChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 19),
      ),
      title: Text(titulo, style: TextStyle(color: tituloColor ?? colors.paper, fontWeight: FontWeight.w600)),
      subtitle: subtitulo != null
          ? Text(subtitulo!, style: TextStyle(color: colors.paperMuted, fontSize: 12))
          : null,
      trailing: mostrarChevron ? Icon(Icons.chevron_right, color: colors.paperMuted) : null,
      onTap: onTap,
    );
  }
}
