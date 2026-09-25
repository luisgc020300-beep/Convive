import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Convive'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @create.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get create;

  /// No description provided for @add.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get delete;

  /// No description provided for @continueLabel.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueLabel;

  /// No description provided for @leave.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get leave;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Convivencia de piso sin dramas'**
  String get loginSubtitle;

  /// No description provided for @loginEmail.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Email no válido'**
  String get loginEmailInvalid;

  /// No description provided for @loginPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPassword;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get loginPasswordTooShort;

  /// No description provided for @loginCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get loginCreateAccount;

  /// No description provided for @loginEnter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get loginEnter;

  /// No description provided for @loginHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Entrar'**
  String get loginHaveAccount;

  /// No description provided for @loginNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate'**
  String get loginNoAccount;

  /// No description provided for @onboardingNoHousehold.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes un piso'**
  String get onboardingNoHousehold;

  /// No description provided for @onboardingCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear un piso'**
  String get onboardingCreate;

  /// No description provided for @onboardingJoin.
  ///
  /// In es, this message translates to:
  /// **'Unirme con un código'**
  String get onboardingJoin;

  /// No description provided for @createHouseholdTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear piso'**
  String get createHouseholdTitle;

  /// No description provided for @createHouseholdNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del piso'**
  String get createHouseholdNameLabel;

  /// No description provided for @createHouseholdNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Piso de Cájar'**
  String get createHouseholdNameHint;

  /// No description provided for @createHouseholdNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre a tu piso'**
  String get createHouseholdNameRequired;

  /// No description provided for @createHouseholdError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el piso: {error}'**
  String createHouseholdError(String error);

  /// No description provided for @createHouseholdSuccessTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Piso creado!'**
  String get createHouseholdSuccessTitle;

  /// No description provided for @createHouseholdSuccessBody.
  ///
  /// In es, this message translates to:
  /// **'Comparte este código con tus compañeros para que se unan:'**
  String get createHouseholdSuccessBody;

  /// No description provided for @createHouseholdButton.
  ///
  /// In es, this message translates to:
  /// **'Crear piso'**
  String get createHouseholdButton;

  /// No description provided for @joinHouseholdTitle.
  ///
  /// In es, this message translates to:
  /// **'Unirse a un piso'**
  String get joinHouseholdTitle;

  /// No description provided for @joinHouseholdCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código del piso'**
  String get joinHouseholdCodeLabel;

  /// No description provided for @joinHouseholdCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: A3B7K9'**
  String get joinHouseholdCodeHint;

  /// No description provided for @joinHouseholdCodeRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código que te han pasado'**
  String get joinHouseholdCodeRequired;

  /// No description provided for @joinHouseholdNotFound.
  ///
  /// In es, this message translates to:
  /// **'No existe ningún piso con ese código.'**
  String get joinHouseholdNotFound;

  /// No description provided for @joinHouseholdFull.
  ///
  /// In es, this message translates to:
  /// **'Ese piso ya tiene el máximo de miembros.'**
  String get joinHouseholdFull;

  /// No description provided for @joinHouseholdError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo unir al piso: {error}'**
  String joinHouseholdError(String error);

  /// No description provided for @joinHouseholdButton.
  ///
  /// In es, this message translates to:
  /// **'Unirme'**
  String get joinHouseholdButton;

  /// No description provided for @tabTasks.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get tabTasks;

  /// No description provided for @tabChat.
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos'**
  String get tabPayments;

  /// No description provided for @tabHousehold.
  ///
  /// In es, this message translates to:
  /// **'Piso'**
  String get tabHousehold;

  /// No description provided for @memberUnknown.
  ///
  /// In es, this message translates to:
  /// **'Alguien'**
  String get memberUnknown;

  /// No description provided for @tasksTitle.
  ///
  /// In es, this message translates to:
  /// **'Tareas'**
  String get tasksTitle;

  /// No description provided for @tasksToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get tasksToday;

  /// No description provided for @tasksNothingToday.
  ///
  /// In es, this message translates to:
  /// **'Nada tuyo para hoy.'**
  String get tasksNothingToday;

  /// No description provided for @tasksNotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Notas del piso'**
  String get tasksNotesTitle;

  /// No description provided for @tasksAssignedTo.
  ///
  /// In es, this message translates to:
  /// **'Le toca a {name}'**
  String tasksAssignedTo(String name);

  /// No description provided for @tasksDoneToday.
  ///
  /// In es, this message translates to:
  /// **'Hecha hoy'**
  String get tasksDoneToday;

  /// No description provided for @tasksDone.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get tasksDone;

  /// No description provided for @tasksMarkDone.
  ///
  /// In es, this message translates to:
  /// **'Marcar hecho'**
  String get tasksMarkDone;

  /// No description provided for @tasksNewTaskFor.
  ///
  /// In es, this message translates to:
  /// **'Nueva tarea — {day}'**
  String tasksNewTaskFor(String day);

  /// No description provided for @tasksTitleHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Fregar la cocina'**
  String get tasksTitleHint;

  /// No description provided for @tasksDayOfWeek.
  ///
  /// In es, this message translates to:
  /// **'Día de la semana'**
  String get tasksDayOfWeek;

  /// No description provided for @tasksIntervalHint.
  ///
  /// In es, this message translates to:
  /// **'Cada cuántos días'**
  String get tasksIntervalHint;

  /// No description provided for @tasksDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar esta tarea?'**
  String get tasksDeleteTitle;

  /// No description provided for @tasksDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se dejará de repartir \"{title}\". El historial ya registrado no se borra.'**
  String tasksDeleteBody(String title);

  /// No description provided for @tasksPinNote.
  ///
  /// In es, this message translates to:
  /// **'Clavar nota'**
  String get tasksPinNote;

  /// No description provided for @tasksBoardEmpty.
  ///
  /// In es, this message translates to:
  /// **'El corcho está vacío. Clava la primera nota.'**
  String get tasksBoardEmpty;

  /// No description provided for @tasksNewNoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Clavar una nota'**
  String get tasksNewNoteTitle;

  /// No description provided for @tasksNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Ha venido el casero...'**
  String get tasksNoteHint;

  /// No description provided for @tasksPin.
  ///
  /// In es, this message translates to:
  /// **'Clavar'**
  String get tasksPin;

  /// No description provided for @tasksAddTaskFor.
  ///
  /// In es, this message translates to:
  /// **'Añadir tarea para el {day}'**
  String tasksAddTaskFor(String day);

  /// No description provided for @tasksThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get tasksThisWeek;

  /// No description provided for @tasksNothingScheduled.
  ///
  /// In es, this message translates to:
  /// **'Nada programado ese día.'**
  String get tasksNothingScheduled;

  /// No description provided for @tasksWeekView.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get tasksWeekView;

  /// No description provided for @tasksMonthView.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get tasksMonthView;

  /// No description provided for @recurrenceDaily.
  ///
  /// In es, this message translates to:
  /// **'Cada día'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In es, this message translates to:
  /// **'Cada semana'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceEveryNDays.
  ///
  /// In es, this message translates to:
  /// **'Cada X días'**
  String get recurrenceEveryNDays;

  /// No description provided for @chatEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay mensajes. Saluda.'**
  String get chatEmpty;

  /// No description provided for @chatHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje...'**
  String get chatHint;

  /// No description provided for @paymentsExpensesTitle.
  ///
  /// In es, this message translates to:
  /// **'Gastos comunes'**
  String get paymentsExpensesTitle;

  /// No description provided for @paymentsNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo'**
  String get paymentsNew;

  /// No description provided for @paymentsNewExpenseTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo gasto'**
  String get paymentsNewExpenseTitle;

  /// No description provided for @paymentsDescriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Productos del baño'**
  String get paymentsDescriptionHint;

  /// No description provided for @paymentsAmountHint.
  ///
  /// In es, this message translates to:
  /// **'Importe total (€)'**
  String get paymentsAmountHint;

  /// No description provided for @paymentsWhoPaid.
  ///
  /// In es, this message translates to:
  /// **'¿Quién pagó?'**
  String get paymentsWhoPaid;

  /// No description provided for @paymentsSplitBetween.
  ///
  /// In es, this message translates to:
  /// **'Repartir entre:'**
  String get paymentsSplitBetween;

  /// No description provided for @paymentsRemindersTitle.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios de pago'**
  String get paymentsRemindersTitle;

  /// No description provided for @paymentsNewReminderTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo recordatorio'**
  String get paymentsNewReminderTitle;

  /// No description provided for @paymentsReminderHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Pagar el agua'**
  String get paymentsReminderHint;

  /// No description provided for @paymentsRecurringMonthly.
  ///
  /// In es, this message translates to:
  /// **'Se repite cada mes'**
  String get paymentsRecurringMonthly;

  /// No description provided for @paymentsDayOfMonth.
  ///
  /// In es, this message translates to:
  /// **'Día del mes'**
  String get paymentsDayOfMonth;

  /// No description provided for @paymentsDayN.
  ///
  /// In es, this message translates to:
  /// **'Día {n}'**
  String paymentsDayN(int n);

  /// No description provided for @paymentsDateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha: {date}'**
  String paymentsDateLabel(String date);

  /// No description provided for @paymentsNoExpenses.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay gastos comunes registrados.'**
  String get paymentsNoExpenses;

  /// No description provided for @paymentsOwes.
  ///
  /// In es, this message translates to:
  /// **'{from} le debe a {to}'**
  String paymentsOwes(String from, String to);

  /// No description provided for @paymentsYourBalance.
  ///
  /// In es, this message translates to:
  /// **'TU BALANCE'**
  String get paymentsYourBalance;

  /// No description provided for @paymentsSettledUp.
  ///
  /// In es, this message translates to:
  /// **'Estás en paz'**
  String get paymentsSettledUp;

  /// No description provided for @paymentsTheyOweYou.
  ///
  /// In es, this message translates to:
  /// **'te deben'**
  String get paymentsTheyOweYou;

  /// No description provided for @paymentsYouOwe.
  ///
  /// In es, this message translates to:
  /// **'debes'**
  String get paymentsYouOwe;

  /// No description provided for @paymentsPaidBy.
  ///
  /// In es, this message translates to:
  /// **'pagó {name}'**
  String paymentsPaidBy(String name);

  /// No description provided for @paymentsNoReminders.
  ///
  /// In es, this message translates to:
  /// **'Sin recordatorios de pago.'**
  String get paymentsNoReminders;

  /// No description provided for @paymentsEveryMonth.
  ///
  /// In es, this message translates to:
  /// **'cada mes'**
  String get paymentsEveryMonth;

  /// No description provided for @paymentsOneTime.
  ///
  /// In es, this message translates to:
  /// **'pago puntual'**
  String get paymentsOneTime;

  /// No description provided for @paymentsSummaryTooltip.
  ///
  /// In es, this message translates to:
  /// **'Resumen de gastos'**
  String get paymentsSummaryTooltip;

  /// No description provided for @paymentsSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen de gastos'**
  String get paymentsSummaryTitle;

  /// No description provided for @paymentsNoExpensesMonth.
  ///
  /// In es, this message translates to:
  /// **'Sin gastos ese mes.'**
  String get paymentsNoExpensesMonth;

  /// No description provided for @paymentsHouseholdTotal.
  ///
  /// In es, this message translates to:
  /// **'TOTAL DEL PISO'**
  String get paymentsHouseholdTotal;

  /// No description provided for @categoryFood.
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get categoryFood;

  /// No description provided for @categoryElectricity.
  ///
  /// In es, this message translates to:
  /// **'Luz'**
  String get categoryElectricity;

  /// No description provided for @categoryWater.
  ///
  /// In es, this message translates to:
  /// **'Agua'**
  String get categoryWater;

  /// No description provided for @categoryGas.
  ///
  /// In es, this message translates to:
  /// **'Gas'**
  String get categoryGas;

  /// No description provided for @categoryInternet.
  ///
  /// In es, this message translates to:
  /// **'Internet'**
  String get categoryInternet;

  /// No description provided for @categoryCleaning.
  ///
  /// In es, this message translates to:
  /// **'Limpieza'**
  String get categoryCleaning;

  /// No description provided for @categoryHome.
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get categoryHome;

  /// No description provided for @categoryLeisure.
  ///
  /// In es, this message translates to:
  /// **'Ocio'**
  String get categoryLeisure;

  /// No description provided for @categoryOther.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get categoryOther;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsAccount.
  ///
  /// In es, this message translates to:
  /// **'CUENTA'**
  String get settingsAccount;

  /// No description provided for @settingsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tareas, pagos y mensajes'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountBody.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es permanente e irreversible:'**
  String get settingsDeleteAccountBody;

  /// No description provided for @settingsDeleteBullet1.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil se elimina de la app.'**
  String get settingsDeleteBullet1;

  /// No description provided for @settingsDeleteBullet2.
  ///
  /// In es, this message translates to:
  /// **'Sigues apareciendo por tu nombre en notas, tareas y mensajes ya publicados en tus pisos -- no se borran retroactivamente.'**
  String get settingsDeleteBullet2;

  /// No description provided for @settingsDeleteBullet3.
  ///
  /// In es, this message translates to:
  /// **'No podrás recuperar el acceso a tus pisos.'**
  String get settingsDeleteBullet3;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get settingsDeleteConfirm;

  /// No description provided for @settingsRequiresRecentLogin.
  ///
  /// In es, this message translates to:
  /// **'Por seguridad, cierra sesión, vuelve a iniciarla y repite esta acción.'**
  String get settingsRequiresRecentLogin;

  /// No description provided for @settingsDeleteError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta. Inténtalo de nuevo.'**
  String get settingsDeleteError;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Según el sistema'**
  String get themeSystem;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Según el sistema'**
  String get languageSystem;

  /// No description provided for @notifTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifTitle;

  /// No description provided for @notifGroupTasks.
  ///
  /// In es, this message translates to:
  /// **'TAREAS'**
  String get notifGroupTasks;

  /// No description provided for @notifGroupPayments.
  ///
  /// In es, this message translates to:
  /// **'PAGOS'**
  String get notifGroupPayments;

  /// No description provided for @notifGroupHousehold.
  ///
  /// In es, this message translates to:
  /// **'PISO'**
  String get notifGroupHousehold;

  /// No description provided for @notifTaskTodayTitle.
  ///
  /// In es, this message translates to:
  /// **'Tarea de hoy'**
  String get notifTaskTodayTitle;

  /// No description provided for @notifTaskTodaySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un aviso por la mañana si hoy te toca algo'**
  String get notifTaskTodaySubtitle;

  /// No description provided for @notifTaskMissedTitle.
  ///
  /// In es, this message translates to:
  /// **'Tarea fallada'**
  String get notifTaskMissedTitle;

  /// No description provided for @notifTaskMissedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Avisar si ayer se quedó sin hacer una tarea tuya'**
  String get notifTaskMissedSubtitle;

  /// No description provided for @notifPaymentDueTitle.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio de pago'**
  String get notifPaymentDueTitle;

  /// No description provided for @notifPaymentDueSubtitle.
  ///
  /// In es, this message translates to:
  /// **'La tarde antes de que venza un recordatorio'**
  String get notifPaymentDueSubtitle;

  /// No description provided for @notifNewExpenseTitle.
  ///
  /// In es, this message translates to:
  /// **'Gasto nuevo'**
  String get notifNewExpenseTitle;

  /// No description provided for @notifNewExpenseSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuando alguien añade un gasto que te afecta'**
  String get notifNewExpenseSubtitle;

  /// No description provided for @notifWeeklyDebtTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen semanal de deudas'**
  String get notifWeeklyDebtTitle;

  /// No description provided for @notifWeeklyDebtSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un aviso a la semana si tienes saldo pendiente'**
  String get notifWeeklyDebtSubtitle;

  /// No description provided for @notifNewNoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Nota nueva'**
  String get notifNewNoteTitle;

  /// No description provided for @notifNewNoteSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuando alguien clava una nota en el corcho'**
  String get notifNewNoteSubtitle;

  /// No description provided for @notifNewMessageTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensaje de chat'**
  String get notifNewMessageTitle;

  /// No description provided for @notifNewMessageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cuando llega un mensaje nuevo'**
  String get notifNewMessageSubtitle;

  /// No description provided for @householdYourName.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre en el piso'**
  String get householdYourName;

  /// No description provided for @householdNameHint.
  ///
  /// In es, this message translates to:
  /// **'Cómo te ven tus compañeros'**
  String get householdNameHint;

  /// No description provided for @householdYourHouseholds.
  ///
  /// In es, this message translates to:
  /// **'Tus pisos'**
  String get householdYourHouseholds;

  /// No description provided for @householdJoinCode.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación: {code}'**
  String householdJoinCode(String code);

  /// No description provided for @householdMembers.
  ///
  /// In es, this message translates to:
  /// **'Compañeros ({count})'**
  String householdMembers(int count);

  /// No description provided for @householdOwner.
  ///
  /// In es, this message translates to:
  /// **'Dueño'**
  String get householdOwner;

  /// No description provided for @householdActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get householdActive;

  /// No description provided for @householdLeave.
  ///
  /// In es, this message translates to:
  /// **'Salir de este piso'**
  String get householdLeave;

  /// No description provided for @householdLeaveConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir de este piso?'**
  String get householdLeaveConfirmTitle;

  /// No description provided for @householdLeaveConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Dejarás de ver \"{name}\". Podrás volver a unirte con el código si lo necesitas.'**
  String householdLeaveConfirmBody(String name);

  /// No description provided for @householdAddAnother.
  ///
  /// In es, this message translates to:
  /// **'Crear o unirme a otro piso'**
  String get householdAddAnother;

  /// No description provided for @householdCreateNew.
  ///
  /// In es, this message translates to:
  /// **'Crear un piso nuevo'**
  String get householdCreateNew;

  /// No description provided for @householdJoinWithCode.
  ///
  /// In es, this message translates to:
  /// **'Unirme con un código'**
  String get householdJoinWithCode;

  /// No description provided for @householdPeopleCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 persona} other{{count} personas}}'**
  String householdPeopleCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
