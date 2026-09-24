// lib/screens/settings_screen.dart
//
// Mismo patrón que el settings_screen.dart de RiskRunner: cerrar sesión con
// confirmación, eliminar cuenta con confirmación explicando las
// consecuencias y manejando requires-recent-login.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: ConviveColors.cork,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: ConviveColors.amber),
                  title: const Text('Cerrar sesión', style: TextStyle(color: ConviveColors.amber)),
                  onTap: _procesando ? null : _confirmarCerrarSesion,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: ConviveColors.rust),
                  title: const Text('Eliminar cuenta', style: TextStyle(color: ConviveColors.rust)),
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
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: ConviveColors.rust, size: 20),
            SizedBox(width: 8),
            Text('Eliminar cuenta'),
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
            style: FilledButton.styleFrom(backgroundColor: ConviveColors.rust),
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
