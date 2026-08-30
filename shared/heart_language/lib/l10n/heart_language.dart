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

  /// Abbreviation for seconds
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get sec;

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
  /// **'{when}, Morning'**
  String morningWorkout(String when);

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'{when}, Evening'**
  String eveningWorkout(String when);

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'{when}, Night'**
  String nightWorkout(String when);

  /// Default workout name
  ///
  /// In en, this message translates to:
  /// **'{when}, Afternoon'**
  String afternoonWorkout(String when);

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

  /// Footer at the bottom of the workout history list once every workout has loaded
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end'**
  String get historyEndReached;

  /// Footer shown when loading the next page of workout history fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more workouts'**
  String get historyLoadMoreError;

  /// Button to retry a failed action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Title of the notification sent when an active workout has been idle for a while
  ///
  /// In en, this message translates to:
  /// **'Still working out?'**
  String get workoutTimeoutTitle;

  /// Body of the notification sent when an active workout has been idle for a while
  ///
  /// In en, this message translates to:
  /// **'Your workout\'s been idle for a while — jump back in or wrap it up.'**
  String get workoutTimeoutBody;

  /// Snackbar reminding the user that notifications are disabled while rest timers are set
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so you won\'t get rest-timer alerts.'**
  String get notificationsDisabledReminder;

  /// Setting item name for picking the app's visual theme preset
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themePresetSetting;

  /// Setting item subtitle explaining that each theme preset covers light and dark mode
  ///
  /// In en, this message translates to:
  /// **'Presets tuned for both light and dark'**
  String get themePresetSettingSubtitle;

  /// Name of the dark-first theme preset with a volt-green accent; named after a blacksmith's forge
  ///
  /// In en, this message translates to:
  /// **'Forge'**
  String get themePresetForge;

  /// Name of the light-first, paper-and-ink theme preset with a cobalt accent
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get themePresetInk;

  /// Name of the quiet, cool-neutral theme preset with a forest-green accent; a calm everyday tool
  ///
  /// In en, this message translates to:
  /// **'Utility'**
  String get themePresetUtility;

  /// Name of the warm theme preset with a true-orange accent; a glowing coal
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get themePresetEmber;

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

  /// Workout complete screen, heading above the goal rungs this session earned
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Goal reached} other{Goals reached}}'**
  String goalsAchievedHeading(int count);

  /// Workout complete screen, one earned rung: the goal's name and the target that was met
  ///
  /// In en, this message translates to:
  /// **'{goal} · {target}'**
  String goalAchievedTarget(String goal, String target);

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

  /// Title of the goals card on the profile screen
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// Button that starts creating a goal
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get addGoal;

  /// Empty state of the goals card
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoalsYet;

  /// The whole-workout goal metric, as opposed to a per-exercise one
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// Title of the dialog that creates a goal
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get newGoal;

  /// Title of the dialog where the user types a goal's target number
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalTarget;

  /// Suffix on a goal that repeats weekly, as in '3 / 4 per week'
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get goalPerWeek;

  /// Suffix on a goal that repeats monthly, as in '12 / 16 per month'
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get goalPerMonth;

  /// The deadline of a goal milestone
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String goalDue(String date);

  /// Shown on a goal whose every milestone has been achieved
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get goalComplete;

  /// Goal shape: a one-off target rather than a repeating one
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get goalMilestone;

  /// Goal shape: a target that repeats every week
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get goalWeekly;

  /// Goal shape: a target that repeats every month
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get goalMonthly;

  /// Heading over the list of a goal's staged targets
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get goalLadder;

  /// Button that adds another staged target to a goal
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get goalAddRung;

  /// When a milestone's target was first met
  ///
  /// In en, this message translates to:
  /// **'Achieved {date}'**
  String goalAchievedOn(String date);

  /// Shown on a milestone the user has not given a date to
  ///
  /// In en, this message translates to:
  /// **'No deadline'**
  String get goalNoDeadline;

  /// Button that opens the date picker for a milestone
  ///
  /// In en, this message translates to:
  /// **'Set a deadline'**
  String get goalSetDeadline;

  /// Button that removes a milestone's date
  ///
  /// In en, this message translates to:
  /// **'Clear deadline'**
  String get goalClearDeadline;

  /// Button on the goals card that flips it over to show goals already achieved
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get goalsViewAchieved;

  /// Heading on the back of the goals card, above the goals already achieved
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get goalsAchievedTitle;

  /// Button on the back of the goals card that flips it to the goals still being worked on
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get goalsViewActive;

  /// Tooltip on the achieved date of a goal rung, opening the workout credited with meeting it
  ///
  /// In en, this message translates to:
  /// **'View the session'**
  String get goalOpenWorkout;

  /// Shown when the workout credited with a goal rung can no longer be found
  ///
  /// In en, this message translates to:
  /// **'That session is no longer on this device'**
  String get goalWorkoutGone;

  /// Tooltip explaining why the add-goal button is missing
  ///
  /// In en, this message translates to:
  /// **'You have as many goals as Heart keeps. Delete one to make room for another.'**
  String get goalsAtCapacity;

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

  /// Button and dialog title for creating a template folder
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// Label of the folder name text field
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// Menu item and dialog title for renaming a template folder
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// Menu item and dialog title for deleting a template folder
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// Reassurance in the delete-folder dialog: deleting a folder never deletes its templates
  ///
  /// In en, this message translates to:
  /// **'The templates inside will be kept'**
  String get deleteFolderBody;

  /// Template menu item and dialog title for filing a template into a folder
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// Option in the move-to-folder dialog that unfiles the template
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// Error shown when creating or renaming a folder to a name already in use
  ///
  /// In en, this message translates to:
  /// **'You already have a folder with this name'**
  String get folderNameTaken;

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

  /// Title of the movement filter sheet in the exercise library
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get movement;

  /// Movement filter section listing movement patterns, e.g. Horizontal Press
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get pattern;

  /// Movement filter section for how constrained the movement path is
  ///
  /// In en, this message translates to:
  /// **'Stability'**
  String get stability;

  /// Movement filter section capping how technical an exercise may be
  ///
  /// In en, this message translates to:
  /// **'Skill at most'**
  String get skillAtMost;

  /// Help tooltip on the Pattern section of the movement filter sheet
  ///
  /// In en, this message translates to:
  /// **'The movement itself — coarser than equipment, finer than body part. Exercises that share a pattern can stand in for one another.'**
  String get patternHelp;

  /// Help tooltip on the Stability section of the movement filter sheet
  ///
  /// In en, this message translates to:
  /// **'How much the equipment holds the path for you. Free means you balance the weight yourself; machine means the path is fixed.'**
  String get stabilityHelp;

  /// Help tooltip on the Skill section of the movement filter sheet, explaining that the choice is a ceiling
  ///
  /// In en, this message translates to:
  /// **'How much technique an exercise demands before it can be loaded safely. Choosing Moderate also includes Low.'**
  String get skillAtMostHelp;

  /// Button that removes every active movement filter
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// Substitution section on the exercise About tab
  ///
  /// In en, this message translates to:
  /// **'Also try'**
  String get alsoTry;

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

  /// Caption under a chart that is plotting one point per week rather than one per reading. Says what the line is, so a reader does not take a smoothed point for a single reading
  ///
  /// In en, this message translates to:
  /// **'Weekly average'**
  String get chartWeeklyAverage;

  /// As chartWeeklyAverage, one point per calendar month
  ///
  /// In en, this message translates to:
  /// **'Monthly average'**
  String get chartMonthlyAverage;

  /// As chartWeeklyAverage, one point per calendar year
  ///
  /// In en, this message translates to:
  /// **'Yearly average'**
  String get chartYearlyAverage;

  /// Chip that sets a chart's window to the last month. Abbreviated because four of these sit in a row on a phone; use whatever short form is conventional for a finance or fitness chart in this locale
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get chartRangeMonth;

  /// Chip that sets a chart's window to the last three months. Abbreviated, as chartRangeMonth
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get chartRangeQuarter;

  /// Chip that sets a chart's window to the last year. Abbreviated, as chartRangeMonth
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get chartRangeYear;

  /// Chip that sets a chart's window to everything recorded, however far back that goes. Keep it short — it sits beside 1M/3M/1Y
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chartRangeAll;

  /// Fallback metric name in the history chart accessibility summary, when the chart has no visible title
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get chartGenericLabel;

  /// Accessibility summary of a history chart, replacing the plotted line with a sentence
  ///
  /// In en, this message translates to:
  /// **'{metric} from {start} to {end}. Latest: {latest}. Trend: {trend}.'**
  String exerciseChartSummary(Object metric, Object start, Object end, Object latest, Object trend);

  /// Trend word in the history chart accessibility summary, when the latest value is higher than the earliest shown
  ///
  /// In en, this message translates to:
  /// **'Increasing'**
  String get exerciseChartTrendUp;

  /// Trend word in the history chart accessibility summary, when the latest value is lower than the earliest shown
  ///
  /// In en, this message translates to:
  /// **'Decreasing'**
  String get exerciseChartTrendDown;

  /// Trend word in the history chart accessibility summary, when the latest value equals the earliest shown
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get exerciseChartTrendFlat;

  /// Accessibility label for a tappable health card on the dashboard. The card is an InkWell around a label, a number and a sparkline, none of which announce themselves as a control — this is what a screen reader reads instead, so it has to carry the whole card
  ///
  /// In en, this message translates to:
  /// **'{metric}, {value}, {when}'**
  String healthCardSummary(String metric, String value, String when);

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

  /// Menu item that allows editing a workout's start and end times
  ///
  /// In en, this message translates to:
  /// **'Edit times'**
  String get editWorkoutTimes;

  /// Title of the dialog for editing a workout's start and end times
  ///
  /// In en, this message translates to:
  /// **'Adjust Start/End Time'**
  String get adjustTimes;

  /// Label for a workout's start time
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// Label for a workout's end time
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// Validation shown when a workout's chosen end time precedes its start time
  ///
  /// In en, this message translates to:
  /// **'End time can\'t be before the start time.'**
  String get endBeforeStart;

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

  /// Title of the dashboard screen with performance charts
  ///
  /// In en, this message translates to:
  /// **'My Dashboard'**
  String get myDashboard;

  /// Button that allows to create a new chart
  ///
  /// In en, this message translates to:
  /// **'New chart'**
  String get newChart;

  /// Tooltip on a chart in the exercise detail, adds the chart to the profile dashboard
  ///
  /// In en, this message translates to:
  /// **'Add to profile'**
  String get addChartToProfile;

  /// Tooltip on the exercise detail page; adds the exercise to the workout in progress
  ///
  /// In en, this message translates to:
  /// **'Add to workout'**
  String get addToActiveWorkout;

  /// Snackbar confirmation after adding the exercise to the workout in progress
  ///
  /// In en, this message translates to:
  /// **'Added to workout'**
  String get exerciseAddedToWorkout;

  /// Snackbar confirmation after adding a chart to the profile dashboard
  ///
  /// In en, this message translates to:
  /// **'Added to profile'**
  String get chartAddedToProfile;

  /// Tooltip on a chart in the exercise detail, removes the chart from the profile dashboard
  ///
  /// In en, this message translates to:
  /// **'Remove from profile'**
  String get removeChartFromProfile;

  /// Empty state for chart widget
  ///
  /// In en, this message translates to:
  /// **'Looks a little empty here'**
  String get emptyChartStateTitle;

  /// Empty state for chart widget
  ///
  /// In en, this message translates to:
  /// **'Add your first set to start tracking real progress'**
  String get emptyChartStateBody;

  /// For a given exercise session, the heaviest weight used in any single working set (ignoring warmups if you tag them). Used as a simple strength-progression chart over time.
  ///
  /// In en, this message translates to:
  /// **'Top set weight'**
  String get topSetWeight;

  /// An estimated one-repetition maximum calculated from the best set in a workout (weight + reps) using a standard 1RM formula. Displayed as a trend line, not a guaranteed true max.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM'**
  String get estimatedOneRepMax;

  /// Total work performed for an exercise in a session or time window, computed as the sum of (weight × reps) across all sets. Useful for tracking training load over time.
  ///
  /// In en, this message translates to:
  /// **'Total volume'**
  String get totalVolume;

  /// Average weight used across working sets for an exercise, typically weighted by reps or sets. Helps smooth out noise from a single heavy or light set when charting progress.
  ///
  /// In en, this message translates to:
  /// **'Average working weight'**
  String get averageWorkingWeight;

  /// For assisted bodyweight exercises, the amount of assistance provided (e.g., machine counterweight or band assistance). Lower values typically indicate progression toward unassisted reps.
  ///
  /// In en, this message translates to:
  /// **'Assistance weight'**
  String get assistanceWeight;

  /// Highest number of repetitions completed in any single set for the selected exercise within a workout or time window. Used to track capacity improvements on reps-only movements.
  ///
  /// In en, this message translates to:
  /// **'Max reps in a set'**
  String get maxRepsInSet;

  /// Total repetitions completed for an exercise within a workout or time window, summed across all sets. Useful for reps-only exercises and high-rep accessory work.
  ///
  /// In en, this message translates to:
  /// **'Total reps'**
  String get totalReps;

  /// For cardio exercises, total distance completed in a session (e.g., kilometers or miles depending on user units). Often charted per workout to show endurance progression.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get cardioDistance;

  /// For cardio exercises, total time spent in the session. Can be charted alone or paired with distance to derive pace when both are available.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get cardioDuration;

  /// For cardio exercises, average pace computed from distance and duration (time per unit distance, e.g., min/km). Only valid when both distance and duration are present and reliable.
  ///
  /// In en, this message translates to:
  /// **'Average pace'**
  String get averagePace;

  /// For duration-based exercises, total accumulated time across all sets in a session or time window. Used to chart consistency and gradual increases for holds or mobility work.
  ///
  /// In en, this message translates to:
  /// **'Total time under tension'**
  String get totalTimeUnderTension;

  /// Title for password requirements section shown during sign-up. Sets a friendly, motivational tone for the password creation rules that follow.
  ///
  /// In en, this message translates to:
  /// **'Let\'s make a password that lifts:'**
  String get passwordPolicyTitle;

  /// Password requirement: minimum character count. Displayed as a bullet point in the password policy list to inform users of the minimum length constraint.
  ///
  /// In en, this message translates to:
  /// **'at least {minLength} characters'**
  String passwordPolicyMinLength(int minLength);

  /// Password requirement: maximum character count. Displayed as a bullet point in the password policy list with a playful note about reasonable boundaries.
  ///
  /// In en, this message translates to:
  /// **'no more than {maxLength} (we believe in limits)'**
  String passwordPolicyMaxLength(int maxLength);

  /// Password requirement: must contain at least one uppercase letter (A-Z). Shown as a validation rule in the password policy checklist.
  ///
  /// In en, this message translates to:
  /// **'one uppercase letter'**
  String get passwordPolicyUpperCase;

  /// Password requirement: must contain at least one lowercase letter (a-z). Shown as a validation rule in the password policy checklist.
  ///
  /// In en, this message translates to:
  /// **'one lowercase letter'**
  String get passwordPolicyLowerCase;

  /// Password requirement: must contain at least one numeric digit (0-9). Displayed as a validation rule in the password policy checklist with casual phrasing.
  ///
  /// In en, this message translates to:
  /// **'one number somewhere in there'**
  String get passwordPolicyDigit;

  /// Confirmation dialog title when user attempts to delete an image from a workout
  ///
  /// In en, this message translates to:
  /// **'Remove this image?'**
  String get deleteImageDialogTitle;

  /// Confirmation dialog body explaining that removing the image won't delete workout data
  ///
  /// In en, this message translates to:
  /// **'It won\'t affect the workout — just clears the picture'**
  String get deleteImageDialogBody;

  /// Photo gallery title
  ///
  /// In en, this message translates to:
  /// **'My progression'**
  String get myProgression;

  /// Snack message when user copies text to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Weight unit label
  ///
  /// In en, this message translates to:
  /// **'Weight unit'**
  String get weightUnitLabel;

  /// Distance unit label
  ///
  /// In en, this message translates to:
  /// **'Distance unit'**
  String get distanceUnitLabel;

  /// Tooltip on a button that dismisses a dialog or a detail pane
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Placeholder shown in the detail pane on a tablet when no workout is selected yet
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get noWorkoutSelectedTitle;

  /// Placeholder shown in the detail pane on a tablet when no workout is selected yet
  ///
  /// In en, this message translates to:
  /// **'Pick a workout to see what you did and make changes.'**
  String get noWorkoutSelectedBody;

  /// Placeholder shown in the detail pane on a tablet when no exercise is selected yet
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get noExerciseSelectedTitle;

  /// Placeholder shown in the detail pane on a tablet when no exercise is selected yet
  ///
  /// In en, this message translates to:
  /// **'Pick an exercise to see how it\'s done, plus your history and records.'**
  String get noExerciseSelectedBody;

  /// Tooltip on an icon-only overflow menu button
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// Tooltip on the icon button that opens a workout's attached progress photos
  ///
  /// In en, this message translates to:
  /// **'View progress photos'**
  String get viewProgressPhotos;

  /// Tooltip on the checkmark button that dismisses the keyboard after editing a name field
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmEdit;

  /// Accessibility label on the button that clears a search field's text
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// Accessibility label on the editable avatar shown while editing an account
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changeProfilePhoto;

  /// Accessibility label on the profile page header, which opens account management
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get viewAccountDetails;

  /// Accessibility label on the avatar shown in the profile page header
  ///
  /// In en, this message translates to:
  /// **'View profile photo'**
  String get viewProfilePhoto;

  /// Accessibility label on a single row of the rest-timer duration picker, tapped to select that duration directly
  ///
  /// In en, this message translates to:
  /// **'Set rest timer to {duration}'**
  String durationPickerSetTo(Object duration);

  /// Accessibility label on the illustration shown when a workout has no exercises
  ///
  /// In en, this message translates to:
  /// **'Empty workout'**
  String get emptyWorkoutLabel;

  /// Accessibility label on a progress photo in the gallery
  ///
  /// In en, this message translates to:
  /// **'Progress photo from {date}'**
  String progressPhotoLabel(Object date);

  /// Accessibility label on an exercise's thumbnail image
  ///
  /// In en, this message translates to:
  /// **'{exerciseName} thumbnail'**
  String exerciseThumbnailLabel(Object exerciseName);

  /// Accessibility summary of a goal's ladder progress bar, replacing the painted rungs with a sentence
  ///
  /// In en, this message translates to:
  /// **'{achieved} of {total} targets reached. Current: {current}.'**
  String goalLadderSummary(Object achieved, Object total, Object current);

  /// Accessibility label on the rest-timer countdown ring, stating the remaining time as a sentence
  ///
  /// In en, this message translates to:
  /// **'Rest timer: {remaining} remaining'**
  String restTimerRemaining(Object remaining);

  /// Header of the health section on the profile dashboard
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// Name of a health metric: calories burned through activity
  ///
  /// In en, this message translates to:
  /// **'Active energy'**
  String get healthActiveEnergy;

  /// Name of a health metric: bodyweight
  ///
  /// In en, this message translates to:
  /// **'Body mass'**
  String get healthBodyMass;

  /// Unit abbreviation, beats per minute. Shown next to a heart rate
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get healthBpm;

  /// Shown on the health card while the app is reading the phone's health store, in place of the empty-state message. Mostly seen in the seconds after the user comes back from granting permission, so it must not sound like a result — it is what is happening, not what was found
  ///
  /// In en, this message translates to:
  /// **'Looking for new readings…'**
  String get healthChecking;

  /// Under the big number in the health detail dialog. The date on its own was cryptic — a bare "08-13" beside a heart rate reads as part of the measurement rather than as when it was taken. Says what the date is, and formats it with a month name so it cannot be mistaken for a number
  ///
  /// In en, this message translates to:
  /// **'Latest reading · {when}'**
  String healthLatestReading(String when);

  /// Settings row that deletes Heart's local copy of health data
  ///
  /// In en, this message translates to:
  /// **'Delete health data'**
  String get healthDelete;

  /// Confirmation body. Reassures that the operating system health store is untouched and the data comes back on the next sync
  ///
  /// In en, this message translates to:
  /// **'This clears what Heart has read onto this device. Nothing in your phone\'s health store changes, and Heart will read it again the next time it syncs.'**
  String get healthDeleteBody;

  /// Confirmation title. Must say it is Heart's copy — a title reading like 'erase my heart rate history' would suggest years of data are about to be lost
  ///
  /// In en, this message translates to:
  /// **'Delete Heart\'s copy of your health data?'**
  String get healthDeleteTitle;

  /// Name of a health metric
  ///
  /// In en, this message translates to:
  /// **'Heart rate variability'**
  String get healthHeartRateVariability;

  /// Single-letter abbreviation for hours, as in '7h 15m'. No space before it
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get healthHoursShort;

  /// Button that opens the operating system's health permission sheet
  ///
  /// In en, this message translates to:
  /// **'Show my health data'**
  String get healthInviteAction;

  /// Body of the card offering to read health data. The last clause is a genuine selling point, not fine print — keep it plain and avoid words like private or secure
  ///
  /// In en, this message translates to:
  /// **'Heart can show your resting heart rate, sleep, steps and body mass next to your workouts. It reads them from your phone\'s health store, and keeps them on this device.'**
  String get healthInviteBody;

  /// Tooltip on the button that dismisses the health invitation card
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get healthInviteDismiss;

  /// Title of the card offering to read health data from the phone
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get healthInviteTitle;

  /// Unit abbreviation, kilocalories. Shown next to active energy
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get healthKilocalories;

  /// Unit abbreviation, milliseconds. Shown next to heart rate variability
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get healthMilliseconds;

  /// Single-letter abbreviation for minutes, as in '7h 15m'. No space before it
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get healthMinutesShort;

  /// iOS only. Body of the dialog behind the info button on the greyed-out Health header, shown once the user has been asked and nothing is being read. The dialog's button opens the Health app; this is what to do on arrival, since Apple gives no way to link straight to Heart's row. An instruction, not an explanation — do not add why the permission is there rather than in Heart. Match the wording Apple's Health app uses in this locale
  ///
  /// In en, this message translates to:
  /// **'In the Health app, tap your profile picture, then Apps, and let Heart read.'**
  String get healthOffInHealthApp;

  /// Non-iOS fallback for healthOffInHealthApp. An instruction, never an explanation, and neutral about why there is nothing to show. The second sentence is Android-specific and load-bearing: Health Connect keeps past-data access as a separate switch away from the main permission list, and without it every read is capped at 30 days however far back the app asks. Say 'past data' — that is the platform's own wording for it
  ///
  /// In en, this message translates to:
  /// **'Let Heart read your health data in your device’s health settings. Allow past data too, or charts stop at the last 30 days.'**
  String get healthOffInSettings;

  /// Title of that dialog, and the tooltip on the button that opens it. States the fact and nothing else — the app cannot tell whether the user declined or simply has no readings, so it must not sound like a fault on either side
  ///
  /// In en, this message translates to:
  /// **'Heart isn’t reading any health data'**
  String get healthOffTitle;

  /// Subtitle under the Health header. States where health data is kept. Must not be softened into 'private' or 'secure' — workouts do sync to a server and only health data does not
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get healthOnThisDevice;

  /// iOS only. Button that opens Apple's Health app, which is where read permissions live — the app's own page in iOS Settings has no health toggle at all. 'Health' here is the name of Apple's app and should keep whatever name it has in this locale
  ///
  /// In en, this message translates to:
  /// **'Open the Health app'**
  String get healthOpenHealthApp;

  /// iOS only. Sits under the row that opens the Health app and says what to do once there, since Apple gives no way to link straight to Heart's row. An instruction only — it is not the place to explain why the permission lives outside Heart. Match the wording Apple's Health app uses in this locale
  ///
  /// In en, this message translates to:
  /// **'Tap your profile picture, then Apps'**
  String get healthOpenHealthAppHint;

  /// Non-iOS. Sits under the row that opens the device's health settings. Health Connect keeps past-data access apart from the main permission list, so a user who grants everything they can see is still capped at 30 days. An instruction, not an explanation of why. Deliberately echoes Health Connect's own prompt — "Allow Heart to access past data?" — so the words the user reads here are the words they then look for; match that prompt's wording in this locale rather than translating literally
  ///
  /// In en, this message translates to:
  /// **'Also allow access to past data'**
  String get healthOpenSettingsHint;

  /// Button that opens the operating system's settings app. Non-iOS fallback for healthOpenHealthApp
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get healthOpenSettings;

  /// Name of a health metric
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get healthRestingHeartRate;

  /// Settings section body. Names exactly what Heart reads and restates where it is kept. Say 'on this device', never 'private' or 'secure' — workouts do sync to a server and only health data does not
  ///
  /// In en, this message translates to:
  /// **'Heart reads resting heart rate, heart rate variability, sleep, steps, active energy and body mass from your phone\'s health store. They stay on this device.'**
  String get healthSettingsBody;

  /// Settings row title. Heart writing a finished workout back to the phone's health store, so the user's activity rings credit their lifting
  ///
  /// In en, this message translates to:
  /// **'Save workouts to Health'**
  String get healthWriteWorkouts;

  /// Settings row subtitle when Heart may write. States the limit as the reassurance: duration and activity type only. Never claim Heart records calories — it deliberately does not, because without a watch there is no measurement, only a guess
  ///
  /// In en, this message translates to:
  /// **'Saving how long you train, and nothing else'**
  String get healthWriteWorkoutsOn;

  /// Settings row subtitle when write access was declined. Neutral — declining is a normal choice, not an error to scold
  ///
  /// In en, this message translates to:
  /// **'Off · Heart is not saving your workouts'**
  String get healthWriteWorkoutsOff;

  /// Name of a health metric: time asleep
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get healthSleep;

  /// Name of a health metric
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get healthSteps;

  /// Workout deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this workout?'**
  String get deleteWorkoutTitle;

  /// Workout deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get deleteWorkoutBody;

  /// Settings item and title of the import page
  ///
  /// In en, this message translates to:
  /// **'Import workout history'**
  String get importData;

  /// Import page, heading of the preview/consent step
  ///
  /// In en, this message translates to:
  /// **'Ready to import'**
  String get importPreviewTitle;

  /// Import preview line, what the file holds
  ///
  /// In en, this message translates to:
  /// **'{workouts, plural, =1{1 workout} other{{workouts} workouts}} and {sets, plural, =1{1 set} other{{sets} sets}} ready to come over'**
  String importPreviewSummary(num workouts, num sets);

  /// Import preview line when part of the file was imported before — only the new workouts are announced
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout is new} other{{count} workouts are new}}'**
  String importPreviewSummaryPartial(num count);

  /// Import preview line when every workout in the file was imported before
  ///
  /// In en, this message translates to:
  /// **'Nothing new — {count, plural, =1{the 1 workout in this file is} other{all {count} workouts in this file are}} already here'**
  String importPreviewNothingNew(num count);

  /// Import preview line, exercises that resolved against the stock catalog or existing customs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise already matches the library} other{{count} exercises already match the library}}'**
  String importPreviewMatched(num count);

  /// Import preview line, workouts a commit would skip as previously imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout is already here — it will be skipped} other{{count} workouts are already here — they will be skipped}}'**
  String importPreviewAlreadyHere(num count);

  /// Button over a checkbox list, checks every item
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// Button over a checkbox list, unchecks every item
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// Import page, heading of the consent step over unmatched exercises
  ///
  /// In en, this message translates to:
  /// **'New exercises found'**
  String get importConsentTitle;

  /// Import page, explains the consent checkboxes over unmatched exercises
  ///
  /// In en, this message translates to:
  /// **'These didn\'t match anything in the library. Check the ones to bring over as your own custom exercises — anything unchecked stays behind, along with its sets.'**
  String get importConsentBody;

  /// Import page, the button that commits the import after the consent step
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// Import consent step, how many sets ride on an unmatched exercise
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String importSetsCount(num count);

  /// Import report line, sets not imported because their exercise was declined
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set stayed behind} other{{count} sets stayed behind}} with the exercises you declined'**
  String importSkippedSets(num count);

  /// Settings section header over data import (and, later, export)
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// Settings section header over account management
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Settings section header over notifications, about, and feedback
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// Import page, explains where the Strong export file comes from
  ///
  /// In en, this message translates to:
  /// **'Lifted with Strong before? Bring your history along.\n\nIn the Strong app, go to Profile → Settings → Export Strong Data. It emails you a CSV file — save it, then pick it here.'**
  String get importExplainerStrong;

  /// Import page, reassurance below the explainer
  ///
  /// In en, this message translates to:
  /// **'Everything comes over — workouts, sets, exercises. Importing the same file twice is safe: anything already here is skipped, never duplicated.'**
  String get importSafeToRetry;

  /// Import page, the button that opens the file picker
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// File-type label shown in the platform file picker
  ///
  /// In en, this message translates to:
  /// **'CSV files'**
  String get csvFiles;

  /// Import page, progress label while the file is uploading
  ///
  /// In en, this message translates to:
  /// **'Importing — hang tight…'**
  String get importInFlight;

  /// Import page, friendly headline when the server rejects the file
  ///
  /// In en, this message translates to:
  /// **'That file didn\'t work'**
  String get importFailedHeadline;

  /// Import page, body of the rejected-file error state
  ///
  /// In en, this message translates to:
  /// **'It couldn\'t be read as a Strong export. Pick the CSV file from Strong\'s export email and try again.'**
  String get importFailedBody;

  /// Import page, heading of the success report
  ///
  /// In en, this message translates to:
  /// **'Imported!'**
  String get importReportTitle;

  /// Import report line, how many workouts were created
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new workouts} =1{1 workout imported} other{{count} workouts imported}}'**
  String importedWorkouts(int count);

  /// Import report line, workouts skipped as previously imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workout was already here — skipped} other{{count} workouts were already here — skipped}}'**
  String importSkippedWorkouts(int count);

  /// Import report line, total sets created
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}} in all'**
  String importedSets(int count);

  /// Import report line, malformed rows the server could not repair
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}} couldn\'t be read'**
  String importSkippedRows(int count);

  /// Import report, heading above the list of exercises created as the user's customs
  ///
  /// In en, this message translates to:
  /// **'New custom exercises'**
  String get importNewExercisesHeader;

  /// Import report, explains the list of created custom exercises
  ///
  /// In en, this message translates to:
  /// **'These didn\'t match anything in the library, so they came over as your custom exercises:'**
  String get importNewExercisesBody;
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

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
