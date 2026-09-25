// lib/screens/settings_screen.dart
//
// Mismo patrón que el settings_screen.dart de RiskRunner: cerrar sesión con
// confirmación, eliminar cuenta con confirmación explicando las
// consecuencias y manejando requires-recent-login.
// Distribución de filas al estilo Ajustes de iOS: grupos con fondo propio,
// filas simples que navegan a una subpantalla en vez de controles inline.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/design_tokens.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _FilaAjuste(
                  icon: Icons.palette_outlined,
                  titulo: l10n.settingsAppearance,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                  ),
                ),
                const Divider(height: 1),
                _FilaAjuste(
                  icon: Icons.language_outlined,
                  titulo: l10n.settingsLanguage,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.settingsAccount, style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.paperMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.amber),
                  title: Text(l10n.settingsSignOut, style: TextStyle(color: colors.amber)),
                  onTap: _procesando ? null : _confirmarCerrarSesion,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: colors.rust),
                  title: Text(l10n.settingsDeleteAccount, style: TextStyle(color: colors.rust)),
                  onTap: _procesando ? null : _confirmarEliminarCuenta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    if (confirmar == true) await FirebaseAuth.instance.signOut();
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

class _FilaAjuste extends StatelessWidget {
  const _FilaAjuste({required this.icon, required this.titulo, required this.onTap});

  final IconData icon;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: colors.paper),
      title: Text(titulo, style: TextStyle(color: colors.paper)),
      trailing: Icon(Icons.chevron_right, color: colors.paperMuted),
      onTap: onTap,
    );
  }
}
