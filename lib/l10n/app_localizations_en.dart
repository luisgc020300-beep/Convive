// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Convive';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get continueLabel => 'Continue';

  @override
  String get leave => 'Leave';

  @override
  String get loginSubtitle => 'Flat life without the drama';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailInvalid => 'Invalid email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordTooShort => '6 characters minimum';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get loginEnter => 'Sign in';

  @override
  String get loginHaveAccount => 'Already have an account? Sign in';

  @override
  String get loginNoAccount => 'No account yet? Sign up';

  @override
  String get onboardingNoHousehold => 'You don\'t have a flat yet';

  @override
  String get onboardingCreate => 'Create a flat';

  @override
  String get onboardingJoin => 'Join with a code';

  @override
  String get createHouseholdTitle => 'Create flat';

  @override
  String get createHouseholdNameLabel => 'Flat name';

  @override
  String get createHouseholdNameHint => 'E.g. Downtown flat';

  @override
  String get createHouseholdNameRequired => 'Give your flat a name';

  @override
  String createHouseholdError(String error) {
    return 'Couldn\'t create the flat: $error';
  }

  @override
  String get createHouseholdSuccessTitle => 'Flat created!';

  @override
  String get createHouseholdSuccessBody =>
      'Share this code with your flatmates so they can join:';

  @override
  String get createHouseholdButton => 'Create flat';

  @override
  String get joinHouseholdTitle => 'Join a flat';

  @override
  String get joinHouseholdCodeLabel => 'Flat code';

  @override
  String get joinHouseholdCodeHint => 'E.g. A3B7K9';

  @override
  String get joinHouseholdCodeRequired => 'Enter the code you were given';

  @override
  String get joinHouseholdNotFound => 'No flat exists with that code.';

  @override
  String get joinHouseholdFull =>
      'That flat already has the maximum number of members.';

  @override
  String joinHouseholdError(String error) {
    return 'Couldn\'t join the flat: $error';
  }

  @override
  String get joinHouseholdButton => 'Join';

  @override
  String get tabTasks => 'Tasks';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabPayments => 'Payments';

  @override
  String get tabHousehold => 'Flat';

  @override
  String get memberUnknown => 'Someone';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksToday => 'Today';

  @override
  String get tasksNothingToday => 'Nothing of yours today.';

  @override
  String get tasksNotesTitle => 'Flat notes';

  @override
  String tasksAssignedTo(String name) {
    return 'It\'s $name\'s turn';
  }

  @override
  String get tasksDoneToday => 'Done today';

  @override
  String get tasksDone => 'Done';

  @override
  String get tasksMarkDone => 'Mark done';

  @override
  String tasksNewTaskFor(String day) {
    return 'New task — $day';
  }

  @override
  String get tasksTitleHint => 'E.g. Clean the kitchen';

  @override
  String get tasksDayOfWeek => 'Day of the week';

  @override
  String get tasksIntervalHint => 'Every how many days';

  @override
  String get tasksDeleteTitle => 'Delete this task?';

  @override
  String tasksDeleteBody(String title) {
    return '\"$title\" will stop being assigned. Its history stays recorded.';
  }

  @override
  String get tasksPinNote => 'Pin note';

  @override
  String get tasksBoardEmpty => 'The board is empty. Pin the first note.';

  @override
  String get tasksNewNoteTitle => 'Pin a note';

  @override
  String get tasksNoteHint => 'E.g. The landlord came by...';

  @override
  String get tasksPin => 'Pin';

  @override
  String tasksAddTaskFor(String day) {
    return 'Add a task for $day';
  }

  @override
  String get tasksThisWeek => 'This week';

  @override
  String get tasksNothingScheduled => 'Nothing scheduled that day.';

  @override
  String get tasksWeekView => 'Week';

  @override
  String get tasksMonthView => 'Month';

  @override
  String get recurrenceDaily => 'Every day';

  @override
  String get recurrenceWeekly => 'Every week';

  @override
  String get recurrenceEveryNDays => 'Every X days';

  @override
  String get chatEmpty => 'No messages yet. Say hi.';

  @override
  String get chatHint => 'Type a message...';

  @override
  String get paymentsExpensesTitle => 'Shared expenses';

  @override
  String get paymentsNew => 'New';

  @override
  String get paymentsNewExpenseTitle => 'New expense';

  @override
  String get paymentsDescriptionHint => 'E.g. Bathroom supplies';

  @override
  String get paymentsAmountHint => 'Total amount (€)';

  @override
  String get paymentsWhoPaid => 'Who paid?';

  @override
  String get paymentsSplitBetween => 'Split between:';

  @override
  String get paymentsRemindersTitle => 'Payment reminders';

  @override
  String get paymentsNewReminderTitle => 'New reminder';

  @override
  String get paymentsReminderHint => 'E.g. Pay the water bill';

  @override
  String get paymentsRecurringMonthly => 'Repeats every month';

  @override
  String get paymentsDayOfMonth => 'Day of the month';

  @override
  String paymentsDayN(int n) {
    return 'Day $n';
  }

  @override
  String paymentsDateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String get paymentsNoExpenses => 'No shared expenses recorded yet.';

  @override
  String paymentsOwes(String from, String to) {
    return '$from owes $to';
  }

  @override
  String get paymentsYourBalance => 'YOUR BALANCE';

  @override
  String get paymentsSettledUp => 'All settled up';

  @override
  String get paymentsTheyOweYou => 'you\'re owed';

  @override
  String get paymentsYouOwe => 'you owe';

  @override
  String paymentsPaidBy(String name) {
    return 'paid by $name';
  }

  @override
  String get paymentsNoReminders => 'No payment reminders.';

  @override
  String get paymentsEveryMonth => 'every month';

  @override
  String get paymentsOneTime => 'one-off payment';

  @override
  String get paymentsSummaryTooltip => 'Expense summary';

  @override
  String get paymentsSummaryTitle => 'Expense summary';

  @override
  String get paymentsNoExpensesMonth => 'No expenses that month.';

  @override
  String get paymentsHouseholdTotal => 'FLAT TOTAL';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryElectricity => 'Electricity';

  @override
  String get categoryWater => 'Water';

  @override
  String get categoryGas => 'Gas';

  @override
  String get categoryInternet => 'Internet';

  @override
  String get categoryCleaning => 'Cleaning';

  @override
  String get categoryHome => 'Household';

  @override
  String get categoryLeisure => 'Leisure';

  @override
  String get categoryOther => 'Other';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAccount => 'ACCOUNT';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirm => 'Sign out?';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountBody =>
      'This action is permanent and irreversible:';

  @override
  String get settingsDeleteBullet1 => 'Your profile is deleted from the app.';

  @override
  String get settingsDeleteBullet2 =>
      'You\'ll still appear by name in notes, tasks and messages already posted in your flats -- these aren\'t deleted retroactively.';

  @override
  String get settingsDeleteBullet3 =>
      'You won\'t be able to recover access to your flats.';

  @override
  String get settingsDeleteConfirm => 'DELETE';

  @override
  String get settingsRequiresRecentLogin =>
      'For security, sign out, sign back in, and try this again.';

  @override
  String get settingsDeleteError =>
      'Couldn\'t delete the account. Please try again.';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'System';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifGroupTasks => 'TASKS';

  @override
  String get notifGroupPayments => 'PAYMENTS';

  @override
  String get notifGroupHousehold => 'FLAT';

  @override
  String get notifTaskTodayTitle => 'Task due today';

  @override
  String get notifTaskTodaySubtitle =>
      'A morning alert if something\'s due today';

  @override
  String get notifTaskMissedTitle => 'Missed task';

  @override
  String get notifTaskMissedSubtitle =>
      'Notify if one of your tasks went undone yesterday';

  @override
  String get notifPaymentDueTitle => 'Payment reminder';

  @override
  String get notifPaymentDueSubtitle => 'The evening before a reminder is due';

  @override
  String get notifNewExpenseTitle => 'New expense';

  @override
  String get notifNewExpenseSubtitle =>
      'When someone adds an expense that affects you';

  @override
  String get notifWeeklyDebtTitle => 'Weekly debt summary';

  @override
  String get notifWeeklyDebtSubtitle =>
      'A weekly alert if you have an outstanding balance';

  @override
  String get notifNewNoteTitle => 'New note';

  @override
  String get notifNewNoteSubtitle => 'When someone pins a note to the board';

  @override
  String get notifNewMessageTitle => 'Chat message';

  @override
  String get notifNewMessageSubtitle => 'When a new message arrives';

  @override
  String get householdYourName => 'Your name in this flat';

  @override
  String get householdNameHint => 'How your flatmates see you';

  @override
  String get householdYourHouseholds => 'Your flats';

  @override
  String householdJoinCode(String code) {
    return 'Invite code: $code';
  }

  @override
  String householdMembers(int count) {
    return 'Flatmates ($count)';
  }

  @override
  String get householdOwner => 'Owner';

  @override
  String get householdActive => 'Active';

  @override
  String get householdLeave => 'Leave this flat';

  @override
  String get householdLeaveConfirmTitle => 'Leave this flat?';

  @override
  String householdLeaveConfirmBody(String name) {
    return 'You\'ll stop seeing \"$name\". You can rejoin later with the code if you need to.';
  }

  @override
  String get householdAddAnother => 'Create or join another flat';

  @override
  String get householdCreateNew => 'Create a new flat';

  @override
  String get householdJoinWithCode => 'Join with a code';

  @override
  String householdPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }
}
