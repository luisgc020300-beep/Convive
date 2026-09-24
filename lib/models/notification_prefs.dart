// lib/models/notification_prefs.dart
//
// Preferencias de notificaciones por categoría. Los que van ON por defecto
// son puntuales y accionables ("hazlo hoy", "paga mañana"); los que van OFF
// son o bien "regañina" (tarea fallada) o un estado ambiente que no se
// resuelve con el tiempo (deuda pendiente) -- justo el patrón de exceso de
// notificaciones que investigamos en Flatastic/Nipto y que decidimos evitar.
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPrefs {
  final bool tareaHoy;
  final bool tareaFallada;
  final bool pagoManana;
  final bool nuevoGasto;
  final bool nuevaNota;
  final bool nuevoMensaje;
  final bool resumenSemanalDeudas;

  const NotificationPrefs({
    this.tareaHoy = true,
    this.tareaFallada = false,
    this.pagoManana = true,
    this.nuevoGasto = true,
    this.nuevaNota = true,
    this.nuevoMensaje = true,
    this.resumenSemanalDeudas = false,
  });

  factory NotificationPrefs.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = (doc.data() ?? {})['notificationPrefs'] as Map<String, dynamic>?;
    if (d == null) return const NotificationPrefs();
    return NotificationPrefs(
      tareaHoy: d['tareaHoy'] as bool? ?? true,
      tareaFallada: d['tareaFallada'] as bool? ?? false,
      pagoManana: d['pagoManana'] as bool? ?? true,
      nuevoGasto: d['nuevoGasto'] as bool? ?? true,
      nuevaNota: d['nuevaNota'] as bool? ?? true,
      nuevoMensaje: d['nuevoMensaje'] as bool? ?? true,
      resumenSemanalDeudas: d['resumenSemanalDeudas'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'tareaHoy': tareaHoy,
        'tareaFallada': tareaFallada,
        'pagoManana': pagoManana,
        'nuevoGasto': nuevoGasto,
        'nuevaNota': nuevaNota,
        'nuevoMensaje': nuevoMensaje,
        'resumenSemanalDeudas': resumenSemanalDeudas,
      };

  NotificationPrefs copyWith({
    bool? tareaHoy,
    bool? tareaFallada,
    bool? pagoManana,
    bool? nuevoGasto,
    bool? nuevaNota,
    bool? nuevoMensaje,
    bool? resumenSemanalDeudas,
  }) =>
      NotificationPrefs(
        tareaHoy: tareaHoy ?? this.tareaHoy,
        tareaFallada: tareaFallada ?? this.tareaFallada,
        pagoManana: pagoManana ?? this.pagoManana,
        nuevoGasto: nuevoGasto ?? this.nuevoGasto,
        nuevaNota: nuevaNota ?? this.nuevaNota,
        nuevoMensaje: nuevoMensaje ?? this.nuevoMensaje,
        resumenSemanalDeudas: resumenSemanalDeudas ?? this.resumenSemanalDeudas,
      );
}
