// lib/screens/notification_prefs_screen.dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/notification_prefs.dart';
import '../services/notification_prefs_service.dart';
import '../theme/design_tokens.dart';

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifTitle)),
      body: StreamBuilder<NotificationPrefs>(
        stream: NotificationPrefsService.streamPrefs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Grupo(titulo: l10n.notifGroupTasks, children: [
                _Interruptor(
                  titulo: l10n.notifTaskTodayTitle,
                  subtitulo: l10n.notifTaskTodaySubtitle,
                  valor: prefs.tareaHoy,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(tareaHoy: v)),
                ),
                _Interruptor(
                  titulo: l10n.notifTaskMissedTitle,
                  subtitulo: l10n.notifTaskMissedSubtitle,
                  valor: prefs.tareaFallada,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(tareaFallada: v)),
                ),
              ]),
              const SizedBox(height: 20),
              _Grupo(titulo: l10n.notifGroupPayments, children: [
                _Interruptor(
                  titulo: l10n.notifPaymentDueTitle,
                  subtitulo: l10n.notifPaymentDueSubtitle,
                  valor: prefs.pagoManana,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(pagoManana: v)),
                ),
                _Interruptor(
                  titulo: l10n.notifNewExpenseTitle,
                  subtitulo: l10n.notifNewExpenseSubtitle,
                  valor: prefs.nuevoGasto,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(nuevoGasto: v)),
                ),
                _Interruptor(
                  titulo: l10n.notifWeeklyDebtTitle,
                  subtitulo: l10n.notifWeeklyDebtSubtitle,
                  valor: prefs.resumenSemanalDeudas,
                  onChanged: (v) =>
                      NotificationPrefsService.savePrefs(prefs.copyWith(resumenSemanalDeudas: v)),
                ),
              ]),
              const SizedBox(height: 20),
              _Grupo(titulo: l10n.notifGroupHousehold, children: [
                _Interruptor(
                  titulo: l10n.notifNewNoteTitle,
                  subtitulo: l10n.notifNewNoteSubtitle,
                  valor: prefs.nuevaNota,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(nuevaNota: v)),
                ),
                _Interruptor(
                  titulo: l10n.notifNewMessageTitle,
                  subtitulo: l10n.notifNewMessageSubtitle,
                  valor: prefs.nuevoMensaje,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(nuevoMensaje: v)),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(titulo.toUpperCase(),
              style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: context.colors.paperMuted)),
        ),
        Container(
          decoration: BoxDecoration(color: context.colors.cork, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      activeThumbColor: context.colors.amber,
      title: Text(titulo),
      subtitle: Text(subtitulo, style: TextStyle(fontSize: 12, color: context.colors.paperMuted)),
      value: valor,
      onChanged: onChanged,
    );
  }
}
