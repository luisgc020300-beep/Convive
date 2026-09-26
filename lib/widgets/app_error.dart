// lib/widgets/app_error.dart
import 'package:flutter/material.dart';

/// Feedback de error compartido para acciones de escritura (enviar mensaje,
/// clavar nota, crear tarea, añadir gasto...) que antes fallaban en
/// silencio: sin esto, un fallo de red dejaba al usuario sin saber si su
/// acción se perdió o no.
class AppError {
  AppError._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
