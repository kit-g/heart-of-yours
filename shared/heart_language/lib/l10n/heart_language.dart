import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'heart_language_en.dart';
import 'heart_language_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/heart_language.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
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
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('en', 'CA'), Locale('ru')];

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// App's motto
  ///
  /// In en, this message translates to:
  /// **'Every beat counts.'**
  String get motto;

  /// tooltip
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get toLightMode;

  /// tooltip
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get toDarkMode;

  /// tooltip
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get toSystemMode;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get yourEmail;

  /// Label in the image cropper
  ///
  /// In en, this message translates to:
  /// **'Crop avatar'**
  String get cropAvatar;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Hint
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get saveName;

  /// Hint
  ///
  /// In en, this message translates to:
  /// **'Change name'**
  String get changeName;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// CTA, verb
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// CTA, verb
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// Login page copy
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get logInTitle;

  /// Login page copy
  ///
  /// In en, this message translates to:
  /// **'You\'ve already started something important. \nLet\'s keep going.'**
  String get logInBody;

  /// Sign up page copy
  ///
  /// In en, this message translates to:
  /// **'Begin with Heart'**
  String get signUpTitle;

  /// Sign up page copy
  ///
  /// In en, this message translates to:
  /// **'Every journey starts with one decision. \nThis one\'s yours.'**
  String get signUpBody;

  /// Recover page copy
  ///
  /// In en, this message translates to:
  /// **'Still with You'**
  String get recoverTitle;

  /// Recover page copy
  ///
  /// In en, this message translates to:
  /// **'Your journey isn\'t lost. \nJust a moment of pause — we\'ll reset together.'**
  String get recoverBody;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Log in with Google'**
  String get logInWithGoogle;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogle;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Log in with Apple'**
  String get logInWithApple;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Sign up with Apple'**
  String get signUpWithApple;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// Generic label, e.g. bottom nav bar
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Generic label, e.g. bottom nav bar
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// Generic label, e.g. bottom nav bar
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Generic label, e.g. bottom nav bar
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// Generic label, e.g. bin the search bar
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Start a new workout'**
  String get startNewWorkout;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Cancel current workout?'**
  String get cancelCurrentWorkoutTitle;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'You have a workout in progress. Do you want to cancel it and start a new one?'**
  String get cancelCurrentWorkoutBody;

  /// Alert dialog
  ///
  /// In en, this message translates to:
  /// **'Start a new workout from this template?'**
  String get startNewWorkoutFromTemplate;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Cancel workout'**
  String get cancelWorkout;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Add exercises'**
  String get addExercises;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get addSet;

  /// Button tooltip
  ///
  /// In en, this message translates to:
  /// **'New exercise'**
  String get newExercise;

  /// Dialog header
  ///
  /// In en, this message translates to:
  /// **'Create new exercise'**
  String get createNewExercise;

  /// Button tooltip
  ///
  /// In en, this message translates to:
  /// **'Exercise options'**
  String get exerciseOptions;

  /// Menu button, as in "Show archived exercises
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get showArchived;

  /// App bar
  ///
  /// In en, this message translates to:
  /// **'Archived exercises'**
  String get archivedExercises;

  /// Dialog title, e.g., "Archive Push ups?"
  ///
  /// In en, this message translates to:
  /// **'Archive {exerciseName}?'**
  String archiveConfirmTitle(Object exerciseName);

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\n Archiving won\'t affect any of your past workouts — your history stays intact.'**
  String get archiveConfirmBody;

  /// Tooltip over archived icon
  ///
  /// In en, this message translates to:
  /// **'This exercise is archived \nand won\'t appear in your main library anymore.'**
  String get exerciseArchived;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get deleteSet;

  /// Workout table, column header
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// Card header
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// Workout table, column header, as in "previous exercise"
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Workout table, column header
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// Workout table, column header
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Generic label, kilograms
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// Generic label, miles
  ///
  /// In en, this message translates to:
  /// **'mile'**
  String get mile;

  /// Generic label, km
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// Generic label, miles
  ///
  /// In en, this message translates to:
  /// **'miles'**
  String get milesPlural;

  /// Generic label, miles
  ///
  /// In en, this message translates to:
  /// **'{howMany,plural, =1{{howMany} mile}other{{howMany} miles}}'**
  String miles(num howMany);

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Ok!'**
  String get okBang;

  /// Generic label, "cancel" button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic label, "finish workout" button
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// Generic label, "Reset" button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Abbreviation for hours
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get h;

  /// Abbreviation for minutes
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// Generic label, pounds
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// Generic label, verb
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Generic label, pounds
  ///
  /// In en, this message translates to:
  /// **'{howMany,plural, =1{{howMany} lb}other{{howMany} lbs}}'**
  String lb(num howMany);

  /// Workout set option, "save this workout as a template"
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get saveAsTemplate;

  /// Exercise set option, "add a note to this set"
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addNote;

  /// Exercise set option
  ///
  /// In en, this message translates to:
  /// **'Replace exercise'**
  String get replaceExercise;

  /// Exercise set option, "choose weight unit for this set"
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightUnit;

  /// Exercise set option, "choose distance unit for this set"
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceUnit;

  /// Duration label
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Measurement unit setting
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// Measurement unit setting
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// Exercise set option, "Set the rest timer for this exercise"
  ///
  /// In en, this message translates to:
  /// **'Rest timer'**
  String get restTimer;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get cancelTimer;

  /// Exercise set option, "Remove this exercise from workout"
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExercise;

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'Morning Workout'**
  String get morningWorkout;

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'Evening Workout'**
  String get eveningWorkout;

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'Night Workout'**
  String get nightWorkout;

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'Afternoon Workout'**
  String get afternoonWorkout;

  /// emptyHistoryTitle
  ///
  /// In en, this message translates to:
  /// **'Your completed workouts will be here'**
  String get emptyHistoryTitle;

  /// emptyHistoryBody
  ///
  /// In en, this message translates to:
  /// **'Go get them done!'**
  String get emptyHistoryBody;

  /// Setting item name
  ///
  /// In en, this message translates to:
  /// **'Custom theme color'**
  String get customThemeColorSetting;

  /// Setting item subtitle
  ///
  /// In en, this message translates to:
  /// **'Used to generate a new theme'**
  String get customThemeColorSettingSubtitle;

  /// Setting item title
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get aboutApp;

  /// Workout complete screen, title
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// Workout complete screen, body
  ///
  /// In en, this message translates to:
  /// **'Your workout is complete!'**
  String get congratulationsBody;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Finish Workout?'**
  String get finishWorkoutTitle;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Complete Your Workout?'**
  String get finishWorkoutWarningTitle;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Any empty or invalid sets will be discarded, and all valid sets will be marked as completed.'**
  String get finishWorkoutWarningBody;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Ready to finish this workout?'**
  String get finishWorkoutBody;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'All progress made so far will be lost.'**
  String get cancelWorkoutBody;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Do you want to cancel this workout?'**
  String get cancelWorkoutTitle;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m done!'**
  String get readyToFinish;

  /// Workout start confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'No, keep current workout'**
  String get keepCurrentAccount;

  /// Workout start confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel that one and start a new workout'**
  String get cancelAndStartNewWorkout;

  /// Workout cancellation confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'No, resume workout'**
  String get resumeWorkout;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Yes, delete this'**
  String get deleteThis;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// Workout completion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'No, one more set!'**
  String get notReadyToFinish;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this workout template?'**
  String get deleteTemplateTitle;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get deleteTemplateBody;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Quit editing?'**
  String get quitEditing;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'All changes will be lost'**
  String get changesWillBeLost;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Quit this page'**
  String get quitPage;

  /// Template deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get stayHere;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// Selected 4 exercises
  ///
  /// In en, this message translates to:
  /// **'Selected {count}'**
  String selected(Object count);

  /// As in Rest timer for bicep curl
  ///
  /// In en, this message translates to:
  /// **'for {exercise}'**
  String forExercise(String exercise);

  /// Rest timer
  ///
  /// In en, this message translates to:
  /// **'Adjust duration via the +/- buttons.'**
  String get restTimerSubtitle;

  /// Rest timer
  ///
  /// In en, this message translates to:
  /// **'+10s'**
  String get addSeconds;

  /// Rest timer
  ///
  /// In en, this message translates to:
  /// **'-10s'**
  String get subtractSeconds;

  /// Rest notification banner
  ///
  /// In en, this message translates to:
  /// **'Rest complete!'**
  String get restComplete;

  /// Chart label
  ///
  /// In en, this message translates to:
  /// **'Workouts per week'**
  String get workoutsPerWeek;

  /// Chart label
  ///
  /// In en, this message translates to:
  /// **'Your workouts will be presented here'**
  String get workoutsPerWeekTitle;

  /// Chart label
  ///
  /// In en, this message translates to:
  /// **'Go get them done!'**
  String get workoutsPerWeekBody;

  /// Label button that allows to choose Exercise category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Label button that allows to choose Exercise target muscle group
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// Tooltip on the button that removes exercise filter
  ///
  /// In en, this message translates to:
  /// **'Remove filter'**
  String get removeFilter;

  /// Rest notification banner
  ///
  /// In en, this message translates to:
  /// **'Next: {exercise}'**
  String restCompleteBody(Object exercise);

  /// Rest notification banner
  ///
  /// In en, this message translates to:
  /// **'{weight} x {reps}'**
  String weightedSetRepresentation(Object weight, Object reps);

  /// Workout templates section header
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// Workout templates section header
  ///
  /// In en, this message translates to:
  /// **'Example templates'**
  String get exampleTemplates;

  /// A single workout template
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get template;

  /// New template form header
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get newTemplate;

  /// Edit template form header
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get editTemplate;

  /// Edit workout form header
  ///
  /// In en, this message translates to:
  /// **'Edit Workout'**
  String get editWorkout;

  /// Edit template text field hint
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// Edit workout text field hint
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get workoutName;

  /// Form validation message
  ///
  /// In en, this message translates to:
  /// **'Cannot be empty'**
  String get cannotBeEmpty;

  /// Tooltip message
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip message
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Tooltip message
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get yourPassword;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌'**
  String get resetPasswordBody;

  /// Connects two widgets, this OR that
  ///
  /// In en, this message translates to:
  /// **'- or -'**
  String get orConnector;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'Well, that didn\'t work! Double-check your details, eh?'**
  String get invalidCredentials;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'Almost there! Try a stronger password to keep your account safe.'**
  String get weakPassword;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Uh-oh! The internet tripped over a dumbbell. 🏋️‍♂️ Try again in a sec!'**
  String get noConnectivity;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// Password recovery flow
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Password recovery flow
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, you\'ll receive a reset link shortly. Check your inbox and spam folder.'**
  String get recoveryLinkMessage;

  /// Password recovery flow
  ///
  /// In en, this message translates to:
  /// **'💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide).'**
  String get recoveryLinkMessageSent;

  /// Email exists dialog
  ///
  /// In en, this message translates to:
  /// **'Email already exists'**
  String get emailExistsTitle;

  /// Email exists dialog
  ///
  /// In en, this message translates to:
  /// **'Yes, sign me in!'**
  String get emailExistsOkButton;

  /// Email exists dialog
  ///
  /// In en, this message translates to:
  /// **'No, I got this'**
  String get emailExistsCancelButton;

  /// Email exists dialog
  ///
  /// In en, this message translates to:
  /// **'An account with {address} already exists. Would you like to log in instead?'**
  String emailExistsBody(Object address);

  /// Password recovery flow
  ///
  /// In en, this message translates to:
  /// **'Enter you email and we\'ll help you reset your password'**
  String get sendResetLinkBody;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'This account is disabled'**
  String get userDisabled;

  /// Login error message
  ///
  /// In en, this message translates to:
  /// **'Unknown error occurred'**
  String get unknownError;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Account control'**
  String get accountControl;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Leave feedback'**
  String get leaveFeedback;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\n\nWe love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. {emoji}'**
  String leaveFeedbackBody(Object emoji);

  /// Confirmation snack message
  ///
  /// In en, this message translates to:
  /// **'Your feedback was received, thank you!'**
  String get feedbackReceived;

  /// Action button on a dialog
  ///
  /// In en, this message translates to:
  /// **'To feedback!'**
  String get toFeedback;

  /// Settings header
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountTitle;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion in {deadline} days. During this time, you can still sign in and reverse this decision. Once the deadline has passed, your account and personal data will be permanently deleted.'**
  String deleteAccountBody(Object deadline);

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Oh no, I like it here!'**
  String get deleteAccountCancelMessage;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Yep, go on without me!'**
  String get deleteAccountConfirmMessage;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm your account deletion'**
  String get confirmDeleteAccountTitle;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Changed my mind, cancel'**
  String get confirmDeleteAccountCancelMessage;

  /// Delete account dialog
  ///
  /// In en, this message translates to:
  /// **'Farewell!'**
  String get confirmDeleteAccountOkMessage;

  /// Delete account page
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// Delete account page
  ///
  /// In en, this message translates to:
  /// **'Your account has been scheduled for deletion on {date}.\n\nIf you change your mind, you can restore your account anytime before this date.\n\nSimply click the button below to cancel the deletion and keep your account safe.'**
  String accountDeletedBody(Object date);

  /// Delete account page
  ///
  /// In en, this message translates to:
  /// **'🔥🏆 Undo the Goodbye 🥇🔥'**
  String get accountDeletedAction;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// Generic label
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get charts;

  /// Exercise history empty state
  ///
  /// In en, this message translates to:
  /// **'Ghost Reps Detected 👻'**
  String get emptyExerciseHistoryTitle;

  /// Exercise history empty state
  ///
  /// In en, this message translates to:
  /// **'Your exercise history is emptier than a gym on a Monday morning. Time to fill it up with some glorious PRs!'**
  String get emptyExerciseHistoryBody;

  /// Exercise history empty state
  ///
  /// In en, this message translates to:
  /// **'Oops! Someone Skipped the Data Day 🤷‍♀️'**
  String get errorExerciseHistoryTitle;

  /// Exercise history empty state
  ///
  /// In en, this message translates to:
  /// **'Looks like the app tripped over its own shoelaces. Try again, and we promise to tie them tighter next time!'**
  String get errorExerciseHistoryBody;

  /// Records screen, title
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get personalRecords;

  /// Records screen, metric name
  ///
  /// In en, this message translates to:
  /// **'Max duration'**
  String get maxDuration;

  /// Records screen, metric name
  ///
  /// In en, this message translates to:
  /// **'Max distance'**
  String get maxDistance;

  /// Records screen, metric name
  ///
  /// In en, this message translates to:
  /// **'Max weight'**
  String get maxWeight;

  /// Records screen, metric name
  ///
  /// In en, this message translates to:
  /// **'Max reps'**
  String get maxReps;

  /// Image picker menu
  ///
  /// In en, this message translates to:
  /// **'Take a new photo'**
  String get capturePhoto;

  /// Image picker menu
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get chooseFromGallery;

  /// Image picker menu
  ///
  /// In en, this message translates to:
  /// **'Remove current photo'**
  String get removeCurrentPhoto;

  /// Possessive pronoun, as in "My exercises"
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get mine;

  /// Label for button that pulls up active workout UI
  ///
  /// In en, this message translates to:
  /// **'Go to Workout'**
  String get goToWorkout;

  /// Label for button that adds a rest timer to an exercise
  ///
  /// In en, this message translates to:
  /// **'Set timer'**
  String get setTimer;

  /// Force update screen, title
  ///
  /// In en, this message translates to:
  /// **'Oops. That one’s on us'**
  String get updateRequiredTitle;

  /// Force update screen, body
  ///
  /// In en, this message translates to:
  /// **'There’s an important update waiting — one that keeps your app working as it should.\n\nYou’ll need to install it before continuing.\nThanks for your patience — and sorry for the interruption.'**
  String get updateRequiredBody;

  /// Force update screen, CTA
  ///
  /// In en, this message translates to:
  /// **'Update on the {storeName}'**
  String updateRequiredCta(String storeName);

  /// Menu item that allows to add photo to a workout
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// Menu item that allows to edit workout name
  ///
  /// In en, this message translates to:
  /// **'Edit workout name'**
  String get editWorkoutName;

  /// Label in the image cropper
  ///
  /// In en, this message translates to:
  /// **'Crop image'**
  String get cropImage;

  /// Menu item that allows to remove photo from a workout
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Menu item that opens exercise details
  ///
  /// In en, this message translates to:
  /// **'About exercise'**
  String get aboutExercise;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'CA':
            return LEnCa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'ru':
      return LRu();
  }

  throw FlutterError('L.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
