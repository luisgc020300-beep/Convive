// lib/screens/language_screen.dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/design_tokens.dart';
import '../theme/locale_controller.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final controller = LocaleController.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguage)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Column(
                children: [
                  _OpcionIdioma(
                    titulo: l10n.languageSpanish,
                    seleccionado: controller.locale?.languageCode == 'es',
                    onTap: () => controller.setLocale(const Locale('es')),
                  ),
                  const Divider(height: 1),
                  _OpcionIdioma(
                    titulo: l10n.languageEnglish,
                    seleccionado: controller.locale?.languageCode == 'en',
                    onTap: () => controller.setLocale(const Locale('en')),
                  ),
                  const Divider(height: 1),
                  _OpcionIdioma(
                    titulo: l10n.languageSystem,
                    seleccionado: controller.locale == null,
                    onTap: () => controller.setLocale(null),
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

class _OpcionIdioma extends StatelessWidget {
  const _OpcionIdioma({
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
  });

  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(Icons.language_outlined, color: seleccionado ? colors.amber : colors.paperMuted),
      title: Text(titulo, style: TextStyle(color: seleccionado ? colors.amber : colors.paper)),
      trailing: seleccionado ? Icon(Icons.check, color: colors.amber, size: 20) : null,
      onTap: onTap,
    );
  }
}
