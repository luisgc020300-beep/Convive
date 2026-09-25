// lib/l10n/date_names.dart
//
// Nombres de días/meses según el idioma activo -- no van por ARB (serían
// 7+12 claves más por idioma para algo que cambia igual en todas las
// pantallas que lo usan), un helper compartido es más simple de mantener.
import 'package:flutter/material.dart';

const _diasCortosEs = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _diasCortosEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _diasLargosEs = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _diasLargosEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _mesesCortosEs = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _mesesCortosEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _mesesLargosEs = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesLargosEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

bool _esIngles(BuildContext context) => Localizations.localeOf(context).languageCode == 'en';

List<String> diasCortos(BuildContext context) => _esIngles(context) ? _diasCortosEn : _diasCortosEs;
List<String> diasLargos(BuildContext context) => _esIngles(context) ? _diasLargosEn : _diasLargosEs;
List<String> mesesCortos(BuildContext context) => _esIngles(context) ? _mesesCortosEn : _mesesCortosEs;
List<String> mesesLargos(BuildContext context) => _esIngles(context) ? _mesesLargosEn : _mesesLargosEs;
