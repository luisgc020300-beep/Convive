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
