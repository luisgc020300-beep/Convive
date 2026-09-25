// lib/screens/notification_prefs_screen.dart
import 'package:flutter/material.dart';

import '../models/notification_prefs.dart';
import '../services/notification_prefs_service.dart';
import '../theme/design_tokens.dart';

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
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
              _Grupo(titulo: 'Tareas', children: [
                _Interruptor(
                  titulo: 'Tarea de hoy',
                  subtitulo: 'Un aviso por la mañana si hoy te toca algo',
                  valor: prefs.tareaHoy,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(tareaHoy: v)),
                ),
                _Interruptor(
                  titulo: 'Tarea fallada',
                  subtitulo: 'Avisar si ayer se quedó sin hacer una tarea tuya',
                  valor: prefs.tareaFallada,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(tareaFallada: v)),
                ),
              ]),
              const SizedBox(height: 20),
              _Grupo(titulo: 'Pagos', children: [
                _Interruptor(
                  titulo: 'Recordatorio de pago',
                  subtitulo: 'La tarde antes de que venza un recordatorio',
                  valor: prefs.pagoManana,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(pagoManana: v)),
                ),
                _Interruptor(
                  titulo: 'Gasto nuevo',
                  subtitulo: 'Cuando alguien añade un gasto que te afecta',
                  valor: prefs.nuevoGasto,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(nuevoGasto: v)),
                ),
                _Interruptor(
                  titulo: 'Resumen semanal de deudas',
                  subtitulo: 'Un aviso a la semana si tienes saldo pendiente',
                  valor: prefs.resumenSemanalDeudas,
                  onChanged: (v) =>
                      NotificationPrefsService.savePrefs(prefs.copyWith(resumenSemanalDeudas: v)),
                ),
              ]),
              const SizedBox(height: 20),
              _Grupo(titulo: 'Piso', children: [
                _Interruptor(
                  titulo: 'Nota nueva',
                  subtitulo: 'Cuando alguien clava una nota en el corcho',
                  valor: prefs.nuevaNota,
                  onChanged: (v) => NotificationPrefsService.savePrefs(prefs.copyWith(nuevaNota: v)),
                ),
                _Interruptor(
                  titulo: 'Mensaje de chat',
                  subtitulo: 'Cuando llega un mensaje nuevo',
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
