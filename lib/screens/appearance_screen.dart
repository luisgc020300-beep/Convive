// lib/screens/appearance_screen.dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final controller = ThemeController.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Column(
                children: [
                  _OpcionTema(
                    icon: Icons.dark_mode_outlined,
                    titulo: l10n.themeDark,
                    seleccionado: controller.mode == ThemeMode.dark,
                    onTap: () => controller.setMode(ThemeMode.dark),
                  ),
                  const Divider(height: 1),
                  _OpcionTema(
                    icon: Icons.light_mode_outlined,
                    titulo: l10n.themeLight,
                    seleccionado: controller.mode == ThemeMode.light,
                    onTap: () => controller.setMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  _OpcionTema(
                    icon: Icons.smartphone_outlined,
                    titulo: l10n.themeSystem,
                    seleccionado: controller.mode == ThemeMode.system,
                    onTap: () => controller.setMode(ThemeMode.system),
                  ),
                ],
              ),
            ),
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
