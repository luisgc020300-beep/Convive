// lib/screens/settings_screen.dart
//
// Mismo patrón que el settings_screen.dart de RiskRunner: cerrar sesión con
// confirmación, eliminar cuenta con confirmación explicando las
// consecuencias y manejando requires-recent-login.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('APARIENCIA', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.paperMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: const _SelectorDeTema(),
          ),
          const SizedBox(height: 20),
          Text('CUENTA', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.paperMuted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.amber),
                  title: Text('Cerrar sesión', style: TextStyle(color: colors.amber)),
                  onTap: _procesando ? null : _confirmarCerrarSesion,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: colors.rust),
                  title: Text('Eliminar cuenta', style: TextStyle(color: colors.rust)),
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) await FirebaseAuth.instance.signOut();
  }

  Future<void> _confirmarEliminarCuenta() async {
    final colors = context.colors;
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: colors.rust, size: 20),
            const SizedBox(width: 8),
            const Text('Eliminar cuenta'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta acción es permanente e irreversible:'),
            SizedBox(height: 10),
            Text('• Tu perfil se elimina de la app.'),
            Text('• Sigues apareciendo por tu nombre en notas, tareas y mensajes ya publicados en tus pisos -- no se borran retroactivamente.'),
            Text('• No podrás recuperar el acceso a tus pisos.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR'),
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
          ? 'Por seguridad, cierra sesión, vuelve a iniciarla y repite esta acción.'
          : 'No se pudo eliminar la cuenta. Inténtalo de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }
}

class _SelectorDeTema extends StatelessWidget {
  const _SelectorDeTema();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        children: [
          _OpcionTema(
            icon: Icons.dark_mode_outlined,
            titulo: 'Oscuro',
            seleccionado: controller.mode == ThemeMode.dark,
            onTap: () => controller.setMode(ThemeMode.dark),
          ),
          const Divider(height: 1),
          _OpcionTema(
            icon: Icons.light_mode_outlined,
            titulo: 'Claro',
            seleccionado: controller.mode == ThemeMode.light,
            onTap: () => controller.setMode(ThemeMode.light),
          ),
          const Divider(height: 1),
          _OpcionTema(
            icon: Icons.smartphone_outlined,
            titulo: 'Según el sistema',
            seleccionado: controller.mode == ThemeMode.system,
            onTap: () => controller.setMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _OpcionTema extends StatelessWidget {
  const _OpcionTema({
    required this.icon,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: seleccionado ? colors.amber : colors.paperMuted),
      title: Text(titulo, style: TextStyle(color: seleccionado ? colors.amber : colors.paper)),
      trailing: seleccionado ? Icon(Icons.check, color: colors.amber, size: 20) : null,
      onTap: onTap,
    );
  }
}
