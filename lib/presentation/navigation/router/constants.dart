part of 'router.dart';

const _profileName = 'profile';
const _profilePath = '/$_profileName';
const _loginName = 'login';
const _loginPath = '/$_loginName';
const _settingsName = 'settings';
const _settingsPath = _settingsName;
const _avatarPath = '/avatar';
const _avatarName = 'avatar';
const _workoutName = 'workout';
const _workoutPath = '/$_workoutName';
const _templateEditorName = 'templateEditor';
const _programName = 'program';
const _newProgramName = 'newProgram';
const _editProgramName = 'editProgram';
const _programLibraryName = 'programLibrary';
const _libraryProgramName = 'libraryProgram';
const _recoveryName = 'recovery';
const _signUpName = 'signUp';
const _historyName = 'history';
const _historyPath = '/$_historyName'; // a callback in bottom navigation bar in app_frame.dart relies on this
const _historyEditName = 'edit';
const _historySkipName = 'skip';
const _historyReviewName = 'entryReview';
const _historyLogName = 'logWorkout';
const _exercisesName = 'exercises';
const _exercisesPath = '/$_exercisesName';
const _exerciseDetailName = 'exerciseDetail';
const _exerciseWorkoutName = 'exerciseWorkout';
const _exerciseArchivedDetailName = 'exerciseArchivedDetail';
const _exerciseArchive = 'archive';
const _doneName = 'done';
const _donePath = '/$_doneName';
const _accountManagementPath = 'account';
const _accountManagementName = _accountManagementPath;
const _importDataPath = 'import';
const _importDataName = 'importData';
const _exportDataPath = 'export';
const _exportDataName = 'exportData';
const _whatsNewPath = 'whats-new';
const _whatsNewName = 'whatsNew';
const _restTimersPath = 'rest-timers';
const _restTimersName = 'restTimers';
const _pushSettingsPath = 'notifications';
const _pushSettingsName = 'pushSettings';
const _apiTokensPath = 'tokens';
const _apiTokensName = 'apiTokens';
const _newApiTokenPath = 'new';
const _newApiTokenName = 'newApiToken';
const _featuresPath = 'features';
const _featuresName = 'features';
const _recapsPath = 'recaps';
const _recapsName = 'recaps';
const _monthlyReportName = 'monthlyReport';
const _monthParam = 'month';
// the feature the Features page opens at (#239), by `Feature.value` — a
// universal link's as much as What's new's
const _featureQuery = 'feature';
const _restoreAccountName = 'restoreAccount';
const _restoreAccountPath = '/$_restoreAccountName';
const _applePath = '/apple';
const _activeWorkoutPath = '/activeWorkout'; // a notifications redirect in app.dart relies on this
// What the Live Activity's tap opens (`ios/OngoingWorkout`), and the only
// deep link that is an intent rather than a screen: see the `openWorkout`
// case in `_decide`. Never navigated to internally.
const _openWorkoutPath = '/openWorkout';
// The other intents (#284): `heart://app/start[?template=<id>]` and
// `heart://app/finish`, what Siri, the Shortcuts app and launcher shortcuts
// open the app on. Parsed by `ShortcutLink`, applied by `runShortcutLink`;
// never navigated to internally either.
const _upgradeAppName = 'upgradeApp';
const _upgradeAppPath = '/$_upgradeAppName';
const _galleryName = 'gallery';
const _galleryPath = '/$_galleryName';
// over whichever tab is open, so Back returns to it
const _programOverName = 'programOver';
const _programOverPath = '/program/:programId';
const _programEditOverName = 'programEditOver';
const _libraryProgramOverName = 'libraryProgramOver';
const _libraryProgramOverPath = '/library/:key';
const _exerciseOverName = 'exerciseOver';
const _exerciseOverPath = '/exercise/:exerciseId';
const _workoutOverName = 'workoutOver';
const _workoutOverPath = '/past-workout/:workoutId';
const _filteredExercisesName = 'filteredExercises';
const _filteredExercisesPath = '/filtered-exercises';
const _onboardingName = 'welcome';
const _onboardingPath = '/$_onboardingName';
// the Coaching space (#566): a shell of its own, beside the app's
const _coachingPath = '/coaching';
const _coachingClientsName = 'coachingClients';
const _coachingClientsPath = '$_coachingPath/clients';
const _coachingClientName = 'coachingClient';
const _coachingClientWorkoutName = 'coachingClientWorkout';
const _coachingMessagesName = 'coachingMessages';
const _coachingMessagesPath = '$_coachingPath/messages';
const _coachingProgramsName = 'coachingPrograms';
const _coachingProgramsPath = '$_coachingPath/programs';
// a coach's library (#557), under the Programs tab
const _coachingNewProgramName = 'coachingNewProgram';
const _coachingProgramName = 'coachingProgram';
const _coachingProgramEditName = 'coachingProgramEdit';
const _coachingProgramSessionName = 'coachingProgramSession';
const _coachingMeName = 'coachingMe';
const _coachingMePath = '$_coachingPath/me';
// what a coach's invitation link opens (#553): the site's own path, which iOS
// and Android both hand to the app
const _invitationPath = '/invite.html';
const _invitationToken = 't';
// what an invitation token looks like when the server made it: base64url
final _invitationTokenShape = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
