// test/l10n/l10n_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:convive/l10n/l10n.dart';
import 'package:convive/l10n/app_localizations_en.dart';
import 'package:convive/l10n/app_localizations_es.dart';

void main() {
  group('joinNames', () {
    test('lista vacía es cadena vacía', () {
      expect(joinNames(AppLocalizationsEs(), []), '');
    });

    test('un solo nombre se devuelve tal cual', () {
      expect(joinNames(AppLocalizationsEs(), ['Ana']), 'Ana');
    });

    test('dos nombres en español usan " y "', () {
      expect(joinNames(AppLocalizationsEs(), ['Ana', 'Luis']), 'Ana y Luis');
    });

    test('dos nombres en inglés usan " and "', () {
      expect(joinNames(AppLocalizationsEn(), ['Ana', 'Luis']), 'Ana and Luis');
    });

    test('tres o más nombres separan con comas antes del último', () {
      expect(joinNames(AppLocalizationsEs(), ['Ana', 'Luis', 'Marta']), 'Ana, Luis y Marta');
      expect(joinNames(AppLocalizationsEn(), ['Ana', 'Luis', 'Marta']), 'Ana, Luis and Marta');
    });
  });
}
