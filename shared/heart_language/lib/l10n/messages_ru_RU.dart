// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru_RU locale. All the
// messages from the main program should be duplicated here with the same
// function name.
// @dart=2.12
// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = MessageLookup();

typedef String? MessageIfAbsent(
    String? messageStr, List<Object>? args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'ru_RU';

  static m0(date) => "Ваш аккаунт запланирован на удаление ${date}.\n\nЕсли вы передумаете, вы можете восстановить свой аккаунт в любое время до этой даты.\n\nПросто нажмите кнопку ниже, чтобы отменить удаление и сохранить ваш аккаунт.";

  static m1(exerciseName) => "Архивировать ${exerciseName}?";

  static m2(deadline) => "Ваш аккаунт запланирован на удаление через ${deadline} дней. В течение этого времени вы все еще можете войти и отменить это решение. После истечения срока ваш аккаунт и личные данные будут удалены навсегда.";

  static m3(address) => "Аккаунт с ${address} уже существует. Хотите войти?";

  static m4(exercise) => "для ${exercise}";

  static m5(howMany) => "${Intl.plural(howMany, one: '${howMany} фнт', other: '${howMany} фнт')}";

  static m6(emoji) => "Сделайте скриншот, нарисуйте свои впечатления и оставьте нам заметку. Вы можете продолжать пользоваться приложением.\n\nМы любим обратную связь. Каждый рисунок и комментарий помогает нам сделать приложение лучше — для вас и всех остальных. Так что спасибо. Серьезно. ${emoji}";

  static m7(howMany) => "${Intl.plural(howMany, one: '${howMany} миля', other: '${howMany} мили')}";

  static m8(exercise) => "Следующее: ${exercise}";

  static m9(count) => "Выбрано ${count}";

  static m10(weight, reps) => "${weight} x ${reps}";

  @override
  final Map<String, dynamic> messages = _notInlinedMessages(_notInlinedMessages);

  static Map<String, dynamic> _notInlinedMessages(Object? _) => {
      'about': MessageLookupByLibrary.simpleMessage('О приложении'),
    'aboutApp': MessageLookupByLibrary.simpleMessage('О приложении'),
    'accountControl': MessageLookupByLibrary.simpleMessage('Управление аккаунтом'),
    'accountDeleted': MessageLookupByLibrary.simpleMessage('Аккаунт удален'),
    'accountDeletedAction': MessageLookupByLibrary.simpleMessage('🔥🏆 Отменить удаление 🥇🔥'),
    'accountDeletedBody': m0,
    'add': MessageLookupByLibrary.simpleMessage('Добавить'),
    'addExercises': MessageLookupByLibrary.simpleMessage('Добавить упражнения'),
    'addNote': MessageLookupByLibrary.simpleMessage('Добавить заметку'),
    'addSeconds': MessageLookupByLibrary.simpleMessage('+10с'),
    'addSet': MessageLookupByLibrary.simpleMessage('Добавить подход'),
    'afternoonWorkout': MessageLookupByLibrary.simpleMessage('Дневная тренировка'),
    'appearance': MessageLookupByLibrary.simpleMessage('Внешний вид'),
    'archive': MessageLookupByLibrary.simpleMessage('Архивировать'),
    'archiveConfirmBody': MessageLookupByLibrary.simpleMessage('Это упражнение будет перемещено в Архивные упражнения (найти в Упражнения → Ещё → Показать архивные).\n Архивирование не повлияет на ваши прошлые тренировки — история останется без изменений.'),
    'archiveConfirmTitle': m1,
    'archivedExercises': MessageLookupByLibrary.simpleMessage('Архивные упражнения'),
    'cancel': MessageLookupByLibrary.simpleMessage('Отмена'),
    'cancelAndStartNewWorkout': MessageLookupByLibrary.simpleMessage('Да, отменить ту и начать новую тренировку'),
    'cancelCurrentWorkoutBody': MessageLookupByLibrary.simpleMessage('У вас есть незавершенная тренировка. Хотите отменить её и начать новую?'),
    'cancelCurrentWorkoutTitle': MessageLookupByLibrary.simpleMessage('Отменить текущую тренировку?'),
    'cancelTimer': MessageLookupByLibrary.simpleMessage('Отменить таймер'),
    'cancelWorkout': MessageLookupByLibrary.simpleMessage('Отменить тренировку'),
    'cancelWorkoutBody': MessageLookupByLibrary.simpleMessage('Весь достигнутый прогресс будет потерян.'),
    'cancelWorkoutTitle': MessageLookupByLibrary.simpleMessage('Хотите отменить эту тренировку?'),
    'cannotBeEmpty': MessageLookupByLibrary.simpleMessage('Не может быть пустым'),
    'capturePhoto': MessageLookupByLibrary.simpleMessage('Сделать новое фото'),
    'category': MessageLookupByLibrary.simpleMessage('Категория'),
    'changeName': MessageLookupByLibrary.simpleMessage('Изменить имя '),
    'changesWillBeLost': MessageLookupByLibrary.simpleMessage('Все изменения будут потеряны'),
    'charts': MessageLookupByLibrary.simpleMessage('Графики'),
    'chooseFromGallery': MessageLookupByLibrary.simpleMessage('Выбрать из галереи'),
    'confirmDeleteAccountCancelMessage': MessageLookupByLibrary.simpleMessage('Передумал, отмена'),
    'confirmDeleteAccountOkMessage': MessageLookupByLibrary.simpleMessage('Прощайте!'),
    'confirmDeleteAccountTitle': MessageLookupByLibrary.simpleMessage('Подтвердите удаление аккаунта'),
    'congratulations': MessageLookupByLibrary.simpleMessage('Поздравляем!'),
    'congratulationsBody': MessageLookupByLibrary.simpleMessage('Ваша тренировка завершена!'),
    'createNewExercise': MessageLookupByLibrary.simpleMessage('Создать новое упражнение'),
    'cropAvatar': MessageLookupByLibrary.simpleMessage('Обрезать аватар'),
    'customThemeColorSetting': MessageLookupByLibrary.simpleMessage('Пользовательский цвет темы'),
    'customThemeColorSettingSubtitle': MessageLookupByLibrary.simpleMessage('Используется для создания новой темы'),
    'dangerZone': MessageLookupByLibrary.simpleMessage('Опасная зона'),
    'delete': MessageLookupByLibrary.simpleMessage('Удалить'),
    'deleteAccount': MessageLookupByLibrary.simpleMessage('Удалить аккаунт'),
    'deleteAccountBody': m2,
    'deleteAccountCancelMessage': MessageLookupByLibrary.simpleMessage('О нет, мне здесь нравится!'),
    'deleteAccountConfirmMessage': MessageLookupByLibrary.simpleMessage('Да, продолжайте без меня!'),
    'deleteAccountTitle': MessageLookupByLibrary.simpleMessage('Вы уверены, что хотите удалить свой аккаунт?'),
    'deleteSet': MessageLookupByLibrary.simpleMessage('Удалить подход'),
    'deleteTemplateBody': MessageLookupByLibrary.simpleMessage('Это действие нельзя отменить'),
    'deleteTemplateTitle': MessageLookupByLibrary.simpleMessage('Хотите удалить этот шаблон тренировки?'),
    'deleteThis': MessageLookupByLibrary.simpleMessage('Да, удалить'),
    'deleted': MessageLookupByLibrary.simpleMessage('Удалено'),
    'distanceUnit': MessageLookupByLibrary.simpleMessage('Расстояние'),
    'duration': MessageLookupByLibrary.simpleMessage('Длительность'),
    'edit': MessageLookupByLibrary.simpleMessage('Изменить'),
    'editTemplate': MessageLookupByLibrary.simpleMessage('Редактировать шаблон'),
    'editWorkout': MessageLookupByLibrary.simpleMessage('Редактировать тренировку'),
    'email': MessageLookupByLibrary.simpleMessage('Эл. почта'),
    'emailExistsBody': m3,
    'emailExistsCancelButton': MessageLookupByLibrary.simpleMessage('Нет, я разберусь'),
    'emailExistsOkButton': MessageLookupByLibrary.simpleMessage('Да, войти!'),
    'emailExistsTitle': MessageLookupByLibrary.simpleMessage('Email уже существует'),
    'emptyExerciseHistoryBody': MessageLookupByLibrary.simpleMessage('Ваша история тренировок пуста как спортзал в понедельник утром. Пора заполнить ее личными рекордами!'),
    'emptyExerciseHistoryTitle': MessageLookupByLibrary.simpleMessage('Обнаружены призрачные повторения 👻'),
    'emptyHistoryBody': MessageLookupByLibrary.simpleMessage('Вперед за тренировками!'),
    'emptyHistoryTitle': MessageLookupByLibrary.simpleMessage('Здесь будут ваши завершенные тренировки'),
    'errorExerciseHistoryBody': MessageLookupByLibrary.simpleMessage('Похоже, приложение споткнулось о свои шнурки. Попробуйте снова, и мы обещаем завязать их крепче в следующий раз!'),
    'errorExerciseHistoryTitle': MessageLookupByLibrary.simpleMessage('Упс! Кто-то пропустил день данных 🤷‍♀️'),
    'eveningWorkout': MessageLookupByLibrary.simpleMessage('Вечерняя тренировка'),
    'exampleTemplates': MessageLookupByLibrary.simpleMessage('Примеры шаблонов'),
    'exerciseArchived': MessageLookupByLibrary.simpleMessage('Это упражнение находится в архиве\nи больше не будет отображаться в основной библиотеке.'),
    'exerciseOptions': MessageLookupByLibrary.simpleMessage('Настройки упражнения'),
    'exercises': MessageLookupByLibrary.simpleMessage('Упражнения'),
    'feedbackReceived': MessageLookupByLibrary.simpleMessage('Ваш отзыв получен, спасибо!'),
    'finish': MessageLookupByLibrary.simpleMessage('Завершить'),
    'finishWorkoutBody': MessageLookupByLibrary.simpleMessage('Готовы завершить эту тренировку?'),
    'finishWorkoutTitle': MessageLookupByLibrary.simpleMessage('Завершить тренировку?'),
    'finishWorkoutWarningBody': MessageLookupByLibrary.simpleMessage('Пустые и некорректные подходы будут удалены, а все правильные будут отмечены как выполненные.'),
    'finishWorkoutWarningTitle': MessageLookupByLibrary.simpleMessage('Завершить тренировку?'),
    'forExercise': m4,
    'forgotPassword': MessageLookupByLibrary.simpleMessage('Забыли пароль?'),
    'h': MessageLookupByLibrary.simpleMessage('ч'),
    'hidePassword': MessageLookupByLibrary.simpleMessage('Скрыть пароль'),
    'history': MessageLookupByLibrary.simpleMessage('История'),
    'imperial': MessageLookupByLibrary.simpleMessage('Имперская'),
    'invalidCredentials': MessageLookupByLibrary.simpleMessage('Что-то пошло не так! Проверьте ваши данные еще раз!'),
    'keepCurrentAccount': MessageLookupByLibrary.simpleMessage('Нет, продолжить текущую тренировку'),
    'kg': MessageLookupByLibrary.simpleMessage('кг'),
    'km': MessageLookupByLibrary.simpleMessage('км '),
    'lb': m5,
    'lbs': MessageLookupByLibrary.simpleMessage('фнт'),
    'leaveFeedback': MessageLookupByLibrary.simpleMessage('Оставить отзыв'),
    'leaveFeedbackBody': m6,
    'logIn': MessageLookupByLibrary.simpleMessage('Войти'),
    'logInBody': MessageLookupByLibrary.simpleMessage('Вы уже начали что-то важное.\nДавайте продолжим!'),
    'logInTitle': MessageLookupByLibrary.simpleMessage('С возвращением!'),
    'logInWithApple': MessageLookupByLibrary.simpleMessage('Войти через Apple'),
    'logInWithGoogle': MessageLookupByLibrary.simpleMessage('Войти через Google'),
    'logOut': MessageLookupByLibrary.simpleMessage('Выйти'),
    'maxDistance': MessageLookupByLibrary.simpleMessage('Макс. дистанция'),
    'maxDuration': MessageLookupByLibrary.simpleMessage('Макс. длительность'),
    'maxReps': MessageLookupByLibrary.simpleMessage('Макс. повторений'),
    'maxWeight': MessageLookupByLibrary.simpleMessage('Макс. вес'),
    'metric': MessageLookupByLibrary.simpleMessage('Метрическая'),
    'mile': MessageLookupByLibrary.simpleMessage('миля'),
    'miles': m7,
    'milesPlural': MessageLookupByLibrary.simpleMessage('мили'),
    'min': MessageLookupByLibrary.simpleMessage('мин'),
    'morningWorkout': MessageLookupByLibrary.simpleMessage('Утренняя тренировка'),
    'motto': MessageLookupByLibrary.simpleMessage('Every beat counts.'),
    'name': MessageLookupByLibrary.simpleMessage('Имя'),
    'nameOptional': MessageLookupByLibrary.simpleMessage('Имя (необязательно)'),
    'newExercise': MessageLookupByLibrary.simpleMessage('Новое упражнение'),
    'newTemplate': MessageLookupByLibrary.simpleMessage('Новый шаблон'),
    'nightWorkout': MessageLookupByLibrary.simpleMessage('Ночная тренировка'),
    'noConnectivity': MessageLookupByLibrary.simpleMessage('Ой! Интернет споткнулся о гантелю. 🏋️‍♂️ Попробуйте снова через секунду!'),
    'notReadyToFinish': MessageLookupByLibrary.simpleMessage('Нет, ещё один подход!'),
    'notificationSettings': MessageLookupByLibrary.simpleMessage('Настройки уведомлений'),
    'ok': MessageLookupByLibrary.simpleMessage('OK'),
    'okBang': MessageLookupByLibrary.simpleMessage('Ок!'),
    'orConnector': MessageLookupByLibrary.simpleMessage('- или -'),
    'password': MessageLookupByLibrary.simpleMessage('Пароль'),
    'personalRecords': MessageLookupByLibrary.simpleMessage('Личные рекорды'),
    'previous': MessageLookupByLibrary.simpleMessage('Предыдущий'),
    'profile': MessageLookupByLibrary.simpleMessage('Профиль'),
    'quitEditing': MessageLookupByLibrary.simpleMessage('Выйти из редактирования?'),
    'quitPage': MessageLookupByLibrary.simpleMessage('Покинуть страницу'),
    'readyToFinish': MessageLookupByLibrary.simpleMessage('Да, я закончил!'),
    'records': MessageLookupByLibrary.simpleMessage('Рекорды'),
    'recoverBody': MessageLookupByLibrary.simpleMessage('Ваш путь не потерян.\nПросто небольшая пауза — давайте начнем заново.'),
    'recoverTitle': MessageLookupByLibrary.simpleMessage('Все еще с вами'),
    'recoveryLinkMessage': MessageLookupByLibrary.simpleMessage('Если аккаунт с этим email существует, вы получите ссылку для сброса. Проверьте папку входящих и спам.'),
    'recoveryLinkMessageSent': MessageLookupByLibrary.simpleMessage('💌Письмо для настройки пароля уже в пути! Проверьте входящие (или папку спам — оно любит там прятаться).'),
    'removeCurrentPhoto': MessageLookupByLibrary.simpleMessage('Удалить текущее фото'),
    'removeExercise': MessageLookupByLibrary.simpleMessage('Удалить упражнение'),
    'removeFilter': MessageLookupByLibrary.simpleMessage('Удалить фильтр'),
    'repeat': MessageLookupByLibrary.simpleMessage('Повторить'),
    'replaceExercise': MessageLookupByLibrary.simpleMessage('Заменить упражнение'),
    'reps': MessageLookupByLibrary.simpleMessage('Повторения'),
    'reset': MessageLookupByLibrary.simpleMessage('Сбросить'),
    'resetPassword': MessageLookupByLibrary.simpleMessage('Сбросить пароль'),
    'resetPasswordBody': MessageLookupByLibrary.simpleMessage('Мы отправим ссылку для сброса пароля на ваш email быстрее, чем вы успеете сказать \"забыл пароль\". Назад пути нет — если только вы не отмените, конечно. 😌'),
    'restComplete': MessageLookupByLibrary.simpleMessage('Отдых завершен!'),
    'restCompleteBody': m8,
    'restTimer': MessageLookupByLibrary.simpleMessage('Таймер отдыха'),
    'restTimerSubtitle': MessageLookupByLibrary.simpleMessage('Настройте длительность с помощью кнопок +/-.'),
    'resumeWorkout': MessageLookupByLibrary.simpleMessage('Нет, продолжить тренировку'),
    'save': MessageLookupByLibrary.simpleMessage('Сохранить'),
    'saveAsTemplate': MessageLookupByLibrary.simpleMessage('Сохранить как шаблон'),
    'saveName': MessageLookupByLibrary.simpleMessage('Сохранить имя'),
    'search': MessageLookupByLibrary.simpleMessage('Поиск'),
    'selected': m9,
    'sendResetLink': MessageLookupByLibrary.simpleMessage('Отправить ссылку для сброса'),
    'sendResetLinkBody': MessageLookupByLibrary.simpleMessage('Введите ваш email и мы поможем сбросить пароль'),
    'set': MessageLookupByLibrary.simpleMessage('Подход'),
    'sets': MessageLookupByLibrary.simpleMessage('Подходы'),
    'settings': MessageLookupByLibrary.simpleMessage('Настройки'),
    'share': MessageLookupByLibrary.simpleMessage('Поделиться'),
    'showArchived': MessageLookupByLibrary.simpleMessage('Показать архивные'),
    'showPassword': MessageLookupByLibrary.simpleMessage('Показать пароль'),
    'signUp': MessageLookupByLibrary.simpleMessage('Регистрация'),
    'signUpBody': MessageLookupByLibrary.simpleMessage('Каждое путешествие начинается с одного решения.\nЭто — ваше.'),
    'signUpTitle': MessageLookupByLibrary.simpleMessage('Начните с Heart'),
    'signUpWithApple': MessageLookupByLibrary.simpleMessage('Зарегистрироваться через Apple '),
    'signUpWithGoogle': MessageLookupByLibrary.simpleMessage('Зарегистрироваться через Google'),
    'skip': MessageLookupByLibrary.simpleMessage('Пропустить'),
    'startNewWorkout': MessageLookupByLibrary.simpleMessage('Начать новую тренировку'),
    'startNewWorkoutFromTemplate': MessageLookupByLibrary.simpleMessage('Начать новую тренировку по этому шаблону?'),
    'startWorkout': MessageLookupByLibrary.simpleMessage('Начать тренировку'),
    'stayHere': MessageLookupByLibrary.simpleMessage('Остаться здесь'),
    'subtractSeconds': MessageLookupByLibrary.simpleMessage('-10с'),
    'target': MessageLookupByLibrary.simpleMessage('Цель'),
    'template': MessageLookupByLibrary.simpleMessage('Шаблон'),
    'templateName': MessageLookupByLibrary.simpleMessage('Название шаблона'),
    'templates': MessageLookupByLibrary.simpleMessage('Шаблоны'),
    'time': MessageLookupByLibrary.simpleMessage('Время'),
    'toDarkMode': MessageLookupByLibrary.simpleMessage('Темная'),
    'toFeedback': MessageLookupByLibrary.simpleMessage('К отзыву!'),
    'toLightMode': MessageLookupByLibrary.simpleMessage('Светлая'),
    'toSystemMode': MessageLookupByLibrary.simpleMessage('Системная'),
    'unarchive': MessageLookupByLibrary.simpleMessage('Разархивировать'),
    'units': MessageLookupByLibrary.simpleMessage('Единицы измерения'),
    'unknownError': MessageLookupByLibrary.simpleMessage('Произошла неизвестная ошибка'),
    'userDisabled': MessageLookupByLibrary.simpleMessage('Этот аккаунт отключен'),
    'weakPassword': MessageLookupByLibrary.simpleMessage('Почти готово! Попробуйте более надежный пароль для безопасности вашего аккаунта.'),
    'weightUnit': MessageLookupByLibrary.simpleMessage('Вес'),
    'weightedSetRepresentation': m10,
    'workout': MessageLookupByLibrary.simpleMessage('Тренировка'),
    'workoutName': MessageLookupByLibrary.simpleMessage('Название тренировки'),
    'workoutsPerWeek': MessageLookupByLibrary.simpleMessage('Workouts per week'),
    'workoutsPerWeekBody': MessageLookupByLibrary.simpleMessage('Вперед за тренировками!'),
    'workoutsPerWeekTitle': MessageLookupByLibrary.simpleMessage('Ваши тренировки будут отображаться здесь'),
    'yourEmail': MessageLookupByLibrary.simpleMessage('Ваш email'),
    'yourPassword': MessageLookupByLibrary.simpleMessage('Ваш пароль')
  };
}
