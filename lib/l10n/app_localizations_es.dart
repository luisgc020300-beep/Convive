// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Convive';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get create => 'Crear';

  @override
  String get add => 'Añadir';

  @override
  String get delete => 'Borrar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get leave => 'Salir';

  @override
  String get loginSubtitle => 'Convivencia de piso sin dramas';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailInvalid => 'Email no válido';

  @override
  String get loginPassword => 'Contraseña';

  @override
  String get loginPasswordTooShort => 'Mínimo 6 caracteres';

  @override
  String get loginCreateAccount => 'Crear cuenta';

  @override
  String get loginEnter => 'Entrar';

  @override
  String get loginHaveAccount => '¿Ya tienes cuenta? Entrar';

  @override
  String get loginNoAccount => '¿No tienes cuenta? Regístrate';

  @override
  String get onboardingNoHousehold => 'Todavía no tienes un piso';

  @override
  String get onboardingCreate => 'Crear un piso';

  @override
  String get onboardingJoin => 'Unirme con un código';

  @override
  String get createHouseholdTitle => 'Crear piso';

  @override
  String get createHouseholdNameLabel => 'Nombre del piso';

  @override
  String get createHouseholdNameHint => 'Ej: Piso de Cájar';

  @override
  String get createHouseholdNameRequired => 'Ponle un nombre a tu piso';

  @override
  String createHouseholdError(String error) {
    return 'No se pudo crear el piso: $error';
  }

  @override
  String get createHouseholdSuccessTitle => '¡Piso creado!';

  @override
  String get createHouseholdSuccessBody =>
      'Comparte este código con tus compañeros para que se unan:';

  @override
  String get createHouseholdButton => 'Crear piso';

  @override
  String get joinHouseholdTitle => 'Unirse a un piso';

  @override
  String get joinHouseholdCodeLabel => 'Código del piso';

  @override
  String get joinHouseholdCodeHint => 'Ej: A3B7K9';

  @override
  String get joinHouseholdCodeRequired =>
      'Introduce el código que te han pasado';

  @override
  String get joinHouseholdNotFound => 'No existe ningún piso con ese código.';

  @override
  String get joinHouseholdFull => 'Ese piso ya tiene el máximo de miembros.';

  @override
  String joinHouseholdError(String error) {
    return 'No se pudo unir al piso: $error';
  }

  @override
  String get joinHouseholdButton => 'Unirme';

  @override
  String get tabTasks => 'Tareas';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabPayments => 'Pagos';

  @override
  String get tabHousehold => 'Piso';

  @override
  String get memberUnknown => 'Alguien';

  @override
  String get tasksTitle => 'Tareas';

  @override
  String get tasksToday => 'Hoy';

  @override
  String get tasksNothingToday => 'Nada tuyo para hoy.';

  @override
  String get tasksNotesTitle => 'Notas del piso';

  @override
  String tasksAssignedTo(String name) {
    return 'Le toca a $name';
  }

  @override
  String get tasksDoneToday => 'Hecha hoy';

  @override
  String get tasksDone => 'Hecho';

  @override
  String get tasksMarkDone => 'Marcar hecho';

  @override
  String tasksNewTaskFor(String day) {
    return 'Nueva tarea — $day';
  }

  @override
  String get tasksTitleHint => 'Ej: Fregar la cocina';

  @override
  String get tasksDayOfWeek => 'Día de la semana';

  @override
  String get tasksIntervalHint => 'Cada cuántos días';

  @override
  String get tasksDeleteTitle => '¿Borrar esta tarea?';

  @override
  String tasksDeleteBody(String title) {
    return 'Se dejará de repartir \"$title\". El historial ya registrado no se borra.';
  }

  @override
  String get tasksPinNote => 'Clavar nota';

  @override
  String get tasksBoardEmpty => 'El corcho está vacío. Clava la primera nota.';

  @override
  String get tasksNewNoteTitle => 'Clavar una nota';

  @override
  String get tasksNoteHint => 'Ej: Ha venido el casero...';

  @override
  String get tasksPin => 'Clavar';

  @override
  String tasksAddTaskFor(String day) {
    return 'Añadir tarea para el $day';
  }

  @override
  String get tasksThisWeek => 'Esta semana';

  @override
  String get tasksNothingScheduled => 'Nada programado ese día.';

  @override
  String get tasksWeekView => 'Semana';

  @override
  String get tasksMonthView => 'Mes';

  @override
  String get recurrenceDaily => 'Cada día';

  @override
  String get recurrenceWeekly => 'Cada semana';

  @override
  String get recurrenceEveryNDays => 'Cada X días';

  @override
  String get chatEmpty => 'Todavía no hay mensajes. Saluda.';

  @override
  String get chatHint => 'Escribe un mensaje...';

  @override
  String get paymentsExpensesTitle => 'Gastos comunes';

  @override
  String get paymentsNew => 'Nuevo';

  @override
  String get paymentsNewExpenseTitle => 'Nuevo gasto';

  @override
  String get paymentsDescriptionHint => 'Ej: Productos del baño';

  @override
  String get paymentsAmountHint => 'Importe total (€)';

  @override
  String get paymentsWhoPaid => '¿Quién pagó?';

  @override
  String get paymentsSplitBetween => 'Repartir entre:';

  @override
  String get paymentsRemindersTitle => 'Recordatorios de pago';

  @override
  String get paymentsNewReminderTitle => 'Nuevo recordatorio';

  @override
  String get paymentsReminderHint => 'Ej: Pagar el agua';

  @override
  String get paymentsRecurringMonthly => 'Se repite cada mes';

  @override
  String get paymentsDayOfMonth => 'Día del mes';

  @override
  String paymentsDayN(int n) {
    return 'Día $n';
  }

  @override
  String paymentsDateLabel(String date) {
    return 'Fecha: $date';
  }

  @override
  String get paymentsNoExpenses => 'Todavía no hay gastos comunes registrados.';

  @override
  String paymentsOwes(String from, String to) {
    return '$from le debe a $to';
  }

  @override
  String get paymentsYourBalance => 'TU BALANCE';

  @override
  String get paymentsSettledUp => 'Estás en paz';

  @override
  String get paymentsTheyOweYou => 'te deben';

  @override
  String get paymentsYouOwe => 'debes';

  @override
  String paymentsPaidBy(String name) {
    return 'pagó $name';
  }

  @override
  String get paymentsNoReminders => 'Sin recordatorios de pago.';

  @override
  String get paymentsEveryMonth => 'cada mes';

  @override
  String get paymentsOneTime => 'pago puntual';

  @override
  String get paymentsSummaryTooltip => 'Resumen de gastos';

  @override
  String get paymentsSummaryTitle => 'Resumen de gastos';

  @override
  String get paymentsNoExpensesMonth => 'Sin gastos ese mes.';

  @override
  String get paymentsHouseholdTotal => 'TOTAL DEL PISO';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryElectricity => 'Luz';

  @override
  String get categoryWater => 'Agua';

  @override
  String get categoryGas => 'Gas';

  @override
  String get categoryInternet => 'Internet';

  @override
  String get categoryCleaning => 'Limpieza';

  @override
  String get categoryHome => 'Casa';

  @override
  String get categoryLeisure => 'Ocio';

  @override
  String get categoryOther => 'Otros';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsAccount => 'CUENTA';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsSubtitle => 'Tareas, pagos y mensajes';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutConfirm => '¿Cerrar sesión?';

  @override
  String get settingsDeleteAccount => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountBody =>
      'Esta acción es permanente e irreversible:';

  @override
  String get settingsDeleteBullet1 => 'Tu perfil se elimina de la app.';

  @override
  String get settingsDeleteBullet2 =>
      'Sigues apareciendo por tu nombre en notas, tareas y mensajes ya publicados en tus pisos -- no se borran retroactivamente.';

  @override
  String get settingsDeleteBullet3 =>
      'No podrás recuperar el acceso a tus pisos.';

  @override
  String get settingsDeleteConfirm => 'ELIMINAR';

  @override
  String get settingsRequiresRecentLogin =>
      'Por seguridad, cierra sesión, vuelve a iniciarla y repite esta acción.';

  @override
  String get settingsDeleteError =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Según el sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Según el sistema';

  @override
  String get notifTitle => 'Notificaciones';

  @override
  String get notifGroupTasks => 'TAREAS';

  @override
  String get notifGroupPayments => 'PAGOS';

  @override
  String get notifGroupHousehold => 'PISO';

  @override
  String get notifTaskTodayTitle => 'Tarea de hoy';

  @override
  String get notifTaskTodaySubtitle =>
      'Un aviso por la mañana si hoy te toca algo';

  @override
  String get notifTaskMissedTitle => 'Tarea fallada';

  @override
  String get notifTaskMissedSubtitle =>
      'Avisar si ayer se quedó sin hacer una tarea tuya';

  @override
  String get notifPaymentDueTitle => 'Recordatorio de pago';

  @override
  String get notifPaymentDueSubtitle =>
      'La tarde antes de que venza un recordatorio';

  @override
  String get notifNewExpenseTitle => 'Gasto nuevo';

  @override
  String get notifNewExpenseSubtitle =>
      'Cuando alguien añade un gasto que te afecta';

  @override
  String get notifWeeklyDebtTitle => 'Resumen semanal de deudas';

  @override
  String get notifWeeklyDebtSubtitle =>
      'Un aviso a la semana si tienes saldo pendiente';

  @override
  String get notifNewNoteTitle => 'Nota nueva';

  @override
  String get notifNewNoteSubtitle =>
      'Cuando alguien clava una nota en el corcho';

  @override
  String get notifNewMessageTitle => 'Mensaje de chat';

  @override
  String get notifNewMessageSubtitle => 'Cuando llega un mensaje nuevo';

  @override
  String get householdYourName => 'Tu nombre en el piso';

  @override
  String get householdNameHint => 'Cómo te ven tus compañeros';

  @override
  String get householdYourHouseholds => 'Tus pisos';

  @override
  String householdJoinCode(String code) {
    return 'Código de invitación: $code';
  }

  @override
  String householdMembers(int count) {
    return 'Compañeros ($count)';
  }

  @override
  String get householdOwner => 'Dueño';

  @override
  String get householdActive => 'Activo';

  @override
  String get householdLeave => 'Salir de este piso';

  @override
  String get householdLeaveConfirmTitle => '¿Salir de este piso?';

  @override
  String householdLeaveConfirmBody(String name) {
    return 'Dejarás de ver \"$name\". Podrás volver a unirte con el código si lo necesitas.';
  }

  @override
  String get householdAddAnother => 'Crear o unirme a otro piso';

  @override
  String get householdCreateNew => 'Crear un piso nuevo';

  @override
  String get householdJoinWithCode => 'Unirme con un código';

  @override
  String householdPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }
}
