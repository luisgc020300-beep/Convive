// lib/l10n/l10n.dart
//
// Atajo para no escribir AppLocalizations.of(context)! en cada sitio --
// mismo patrón que context.colors para el tema.
import 'package:flutter/material.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// "Ana, Luis y Marta" / "Ana, Luis and Marta" -- para tareas compartidas
/// entre varias personas a la vez (ver ConviveTask.asignadosEnDia).
String joinNames(AppLocalizations l10n, List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')}${l10n.namesJoinerLast}${names.last}';
}
