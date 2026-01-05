// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'heart_language.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appearance => 'Внешний вид';

  @override
  String get units => 'Единицы измерения';

  @override
  String get motto => 'Every beat counts.';

  @override
  String get toLightMode => 'Светлая';

  @override
  String get toDarkMode => 'Темная';

  @override
  String get toSystemMode => 'Системная';

  @override
  String get email => 'Эл. почта';

  @override
  String get yourEmail => 'Ваш email';

  @override
  String get cropAvatar => 'Обрезать аватар';

  @override
  String get nameOptional => 'Имя (необязательно)';

  @override
  String get name => 'Имя';

  @override
  String get saveName => 'Сохранить имя';

  @override
  String get changeName => 'Изменить имя';

  @override
  String get save => 'Сохранить';

  @override
  String get settings => 'Настройки';

  @override
  String get archive => 'Архивировать';

  @override
  String get unarchive => 'Разархивировать';

  @override
  String get password => 'Пароль';

  @override
  String get logIn => 'Войти';

  @override
  String get logInTitle => 'С возвращением!';

  @override
  String get logInBody => 'Вы уже начали что-то важное.\r\nДавайте продолжим!';

  @override
  String get signUpTitle => 'Начните с Heart';

  @override
  String get signUpBody => 'Каждое путешествие начинается с одного решения.\r\nЭто — ваше.';

  @override
  String get recoverTitle => 'Все еще с вами';

  @override
  String get recoverBody => 'Ваш путь не потерян.\r\nПросто небольшая пауза — давайте начнем заново.';

  @override
  String get logInWithGoogle => 'Войти через Google';

  @override
  String get signUpWithGoogle => 'Зарегистрироваться через Google';

  @override
  String get logInWithApple => 'Войти через Apple';

  @override
  String get signUpWithApple => 'Зарегистрироваться через Apple';

  @override
  String get logOut => 'Выйти';

  @override
  String get profile => 'Профиль';

  @override
  String get workout => 'Тренировка';

  @override
  String get history => 'История';

  @override
  String get exercises => 'Упражнения';

  @override
  String get search => 'Поиск';

  @override
  String get startNewWorkout => 'Начать новую тренировку';

  @override
  String get cancelCurrentWorkoutTitle => 'Отменить текущую тренировку?';

  @override
  String get cancelCurrentWorkoutBody => 'У вас есть незавершенная тренировка. Хотите отменить её и начать новую?';

  @override
  String get startNewWorkoutFromTemplate => 'Начать новую тренировку по этому шаблону?';

  @override
  String get startWorkout => 'Начать тренировку';

  @override
  String get cancelWorkout => 'Отменить тренировку';

  @override
  String get addExercises => 'Добавить упражнения';

  @override
  String get addSet => 'Добавить подход';

  @override
  String get newExercise => 'Новое упражнение';

  @override
  String get createNewExercise => 'Создать новое упражнение';

  @override
  String get exerciseOptions => 'Настройки упражнения';

  @override
  String get showArchived => 'Показать архивные';

  @override
  String get archivedExercises => 'Архивные упражнения';

  @override
  String archiveConfirmTitle(Object exerciseName) {
    return 'Архивировать $exerciseName?';
  }

  @override
  String get archiveConfirmBody =>
      'Это упражнение будет перемещено в Архивные упражнения (найти в Упражнения → Ещё → Показать архивные).\r\n Архивирование не повлияет на ваши прошлые тренировки — история останется без изменений.';

  @override
  String get exerciseArchived =>
      'Это упражнение находится в архиве\r\nи больше не будет отображаться в основной библиотеке.';

  @override
  String get deleteSet => 'Удалить подход';

  @override
  String get set => 'Подход';

  @override
  String get sets => 'Подходы';

  @override
  String get previous => 'Предыдущий';

  @override
  String get reps => 'Повторения';

  @override
  String get time => 'Время';

  @override
  String get kg => 'кг';

  @override
  String get mile => 'миля';

  @override
  String get km => 'км';

  @override
  String get milesPlural => 'мили';

  @override
  String miles(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany мили',
      one: '$howMany миля',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get repeat => 'Повторить';

  @override
  String get add => 'Добавить';

  @override
  String get share => 'Поделиться';

  @override
  String get okBang => 'Ок!';

  @override
  String get cancel => 'Отмена';

  @override
  String get finish => 'Завершить';

  @override
  String get reset => 'Сбросить';

  @override
  String get h => 'ч';

  @override
  String get min => 'мин';

  @override
  String get lbs => 'фнт';

  @override
  String get skip => 'Пропустить';

  @override
  String lb(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany фнт',
      one: '$howMany фнт',
    );
    return '$_temp0';
  }

  @override
  String get saveAsTemplate => 'Сохранить как шаблон';

  @override
  String get addNote => 'Добавить заметку';

  @override
  String get replaceExercise => 'Заменить упражнение';

  @override
  String get weightUnit => 'Вес';

  @override
  String get distanceUnit => 'Расстояние';

  @override
  String get duration => 'Длительность';

  @override
  String get imperial => 'Имперская';

  @override
  String get metric => 'Метрическая';

  @override
  String get restTimer => 'Таймер отдыха';

  @override
  String get cancelTimer => 'Отменить таймер';

  @override
  String get removeExercise => 'Удалить упражнение';

  @override
  String get morningWorkout => 'Утренняя тренировка';

  @override
  String get eveningWorkout => 'Вечерняя тренировка';

  @override
  String get nightWorkout => 'Ночная тренировка';

  @override
  String get afternoonWorkout => 'Дневная тренировка';

  @override
  String get emptyHistoryTitle => 'Здесь будут ваши завершенные тренировки';

  @override
  String get emptyHistoryBody => 'Вперед за тренировками!';

  @override
  String get customThemeColorSetting => 'Пользовательский цвет темы';

  @override
  String get customThemeColorSettingSubtitle => 'Используется для создания новой темы';

  @override
  String get aboutApp => 'О приложении';

  @override
  String get congratulations => 'Поздравляем!';

  @override
  String get congratulationsBody => 'Ваша тренировка завершена!';

  @override
  String get finishWorkoutTitle => 'Завершить тренировку?';

  @override
  String get finishWorkoutWarningTitle => 'Завершить тренировку?';

  @override
  String get finishWorkoutWarningBody =>
      'Пустые и некорректные подходы будут удалены, а все правильные будут отмечены как выполненные.';

  @override
  String get finishWorkoutBody => 'Готовы завершить эту тренировку?';

  @override
  String get cancelWorkoutBody => 'Весь достигнутый прогресс будет потерян.';

  @override
  String get cancelWorkoutTitle => 'Хотите отменить эту тренировку?';

  @override
  String get readyToFinish => 'Да, я закончил!';

  @override
  String get keepCurrentAccount => 'Нет, продолжить текущую тренировку';

  @override
  String get cancelAndStartNewWorkout => 'Да, отменить ту и начать новую тренировку';

  @override
  String get resumeWorkout => 'Нет, продолжить тренировку';

  @override
  String get deleteThis => 'Да, удалить';

  @override
  String get deleted => 'Удалено';

  @override
  String get notReadyToFinish => 'Нет, ещё один подход!';

  @override
  String get deleteTemplateTitle => 'Хотите удалить этот шаблон тренировки?';

  @override
  String get deleteTemplateBody => 'Это действие нельзя отменить';

  @override
  String get quitEditing => 'Выйти из редактирования?';

  @override
  String get changesWillBeLost => 'Все изменения будут потеряны';

  @override
  String get quitPage => 'Покинуть страницу';

  @override
  String get stayHere => 'Остаться здесь';

  @override
  String get notificationSettings => 'Настройки уведомлений';

  @override
  String selected(Object count) {
    return 'Выбрано $count';
  }

  @override
  String forExercise(String exercise) {
    return 'для $exercise';
  }

  @override
  String get restTimerSubtitle => 'Настройте длительность с помощью кнопок +/-.';

  @override
  String get addSeconds => '+10с';

  @override
  String get subtractSeconds => '-10с';

  @override
  String get restComplete => 'Отдых завершен!';

  @override
  String get workoutsPerWeek => 'Workouts per week';

  @override
  String get workoutsPerWeekTitle => 'Ваши тренировки будут отображаться здесь';

  @override
  String get workoutsPerWeekBody => 'Вперед за тренировками!';

  @override
  String get category => 'Категория';

  @override
  String get target => 'Цель';

  @override
  String get removeFilter => 'Удалить фильтр';

  @override
  String restCompleteBody(Object exercise) {
    return 'Следующее: $exercise';
  }

  @override
  String weightedSetRepresentation(Object weight, Object reps) {
    return '$weight x $reps';
  }

  @override
  String get templates => 'Шаблоны';

  @override
  String get exampleTemplates => 'Примеры шаблонов';

  @override
  String get template => 'Шаблон';

  @override
  String get newTemplate => 'Новый шаблон';

  @override
  String get editTemplate => 'Редактировать шаблон';

  @override
  String get editWorkout => 'Редактировать тренировку';

  @override
  String get templateName => 'Название шаблона';

  @override
  String get workoutName => 'Название тренировки';

  @override
  String get cannotBeEmpty => 'Не может быть пустым';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get yourPassword => 'Ваш пароль';

  @override
  String get resetPassword => 'Сбросить пароль';

  @override
  String get resetPasswordBody =>
      'Мы отправим ссылку для сброса пароля на ваш email быстрее, чем вы успеете сказать \"забыл пароль\". Назад пути нет — если только вы не отмените, конечно. 😌';

  @override
  String get orConnector => '- или -';

  @override
  String get invalidCredentials => 'Что-то пошло не так! Проверьте ваши данные еще раз!';

  @override
  String get weakPassword => 'Почти готово! Попробуйте более надежный пароль для безопасности вашего аккаунта.';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get noConnectivity => 'Ой! Интернет споткнулся о гантелю. 🏋️‍♂️ Попробуйте снова через секунду!';

  @override
  String get signUp => 'Регистрация';

  @override
  String get sendResetLink => 'Отправить ссылку для сброса';

  @override
  String get recoveryLinkMessage =>
      'Если аккаунт с этим email существует, вы получите ссылку для сброса. Проверьте папку входящих и спам.';

  @override
  String get recoveryLinkMessageSent =>
      '💌Письмо для настройки пароля уже в пути! Проверьте входящие (или папку спам — оно любит там прятаться).';

  @override
  String get emailExistsTitle => 'Email уже существует';

  @override
  String get emailExistsOkButton => 'Да, войти!';

  @override
  String get emailExistsCancelButton => 'Нет, я разберусь';

  @override
  String emailExistsBody(Object address) {
    return 'Аккаунт с $address уже существует. Хотите войти?';
  }

  @override
  String get sendResetLinkBody => 'Введите ваш email и мы поможем сбросить пароль';

  @override
  String get userDisabled => 'Этот аккаунт отключен';

  @override
  String get unknownError => 'Произошла неизвестная ошибка';

  @override
  String get accountControl => 'Управление аккаунтом';

  @override
  String get leaveFeedback => 'Оставить отзыв';

  @override
  String leaveFeedbackBody(Object emoji) {
    return 'Сделайте скриншот, нарисуйте свои впечатления и оставьте нам заметку. Вы можете продолжать пользоваться приложением.\r\n\r\nМы любим обратную связь. Каждый рисунок и комментарий помогает нам сделать приложение лучше — для вас и всех остальных. Так что спасибо. Серьезно. $emoji';
  }

  @override
  String get feedbackReceived => 'Ваш отзыв получен, спасибо!';

  @override
  String get toFeedback => 'К отзыву!';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountTitle => 'Вы уверены, что хотите удалить свой аккаунт?';

  @override
  String deleteAccountBody(Object deadline) {
    return 'Ваш аккаунт запланирован на удаление через $deadline дней. В течение этого времени вы все еще можете войти и отменить это решение. После истечения срока ваш аккаунт и личные данные будут удалены навсегда.';
  }

  @override
  String get deleteAccountCancelMessage => 'О нет, мне здесь нравится!';

  @override
  String get deleteAccountConfirmMessage => 'Да, продолжайте без меня!';

  @override
  String get confirmDeleteAccountTitle => 'Подтвердите удаление аккаунта';

  @override
  String get confirmDeleteAccountCancelMessage => 'Передумал, отмена';

  @override
  String get confirmDeleteAccountOkMessage => 'Прощайте!';

  @override
  String get accountDeleted => 'Аккаунт удален';

  @override
  String accountDeletedBody(Object date) {
    return 'Ваш аккаунт запланирован на удаление $date.\r\n\r\nЕсли вы передумаете, вы можете восстановить свой аккаунт в любое время до этой даты.\r\n\r\nПросто нажмите кнопку ниже, чтобы отменить удаление и сохранить ваш аккаунт.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Отменить удаление 🥇🔥';

  @override
  String get about => 'О приложении';

  @override
  String get records => 'Рекорды';

  @override
  String get charts => 'Графики';

  @override
  String get emptyExerciseHistoryTitle => 'Обнаружены призрачные повторения 👻';

  @override
  String get emptyExerciseHistoryBody =>
      'Ваша история тренировок пуста как спортзал в понедельник утром. Пора заполнить ее личными рекордами!';

  @override
  String get errorExerciseHistoryTitle => 'Упс! Кто-то пропустил день данных 🤷‍♀️';

  @override
  String get errorExerciseHistoryBody =>
      'Похоже, приложение споткнулось о свои шнурки. Попробуйте снова, и мы обещаем завязать их крепче в следующий раз!';

  @override
  String get personalRecords => 'Личные рекорды';

  @override
  String get maxDuration => 'Макс. длительность';

  @override
  String get maxDistance => 'Макс. дистанция';

  @override
  String get maxWeight => 'Макс. вес';

  @override
  String get maxReps => 'Макс. повторений';

  @override
  String get capturePhoto => 'Сделать новое фото';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get removeCurrentPhoto => 'Удалить текущее фото';

  @override
  String get mine => 'Мои';

  @override
  String get goToWorkout => 'К тренировке';

  @override
  String get setTimer => 'Установить таймер';

  @override
  String get updateRequiredTitle => 'Упс! Это наша вина';

  @override
  String get updateRequiredBody =>
      'Доступно важное обновление — оно необходимо для правильной работы приложения.\r\n\r\nВам нужно установить его, чтобы продолжить.\r\nСпасибо за терпение — и извините за прерывание.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Обновить в $storeName';
  }

  @override
  String get addPhoto => 'Добавить фото';

  @override
  String get editWorkoutName => 'Изменить название тренировки';

  @override
  String get cropImage => 'Обрезать изображение';

  @override
  String get removePhoto => 'Удалить фото';

  @override
  String get aboutExercise => 'Об упражнении';

  @override
  String get myDashboard => 'Моя панель';

  @override
  String get newChart => 'Новый график';

  @override
  String get emptyChartStateTitle => 'Тут немного пусто';

  @override
  String get emptyChartStateBody => 'Добавьте первый подход чтобы начать отслеживать реальный прогресс';

  @override
  String get topSetWeight => 'Вес топового подхода';

  @override
  String get estimatedOneRepMax => 'Расчетный 1ПМ';

  @override
  String get totalVolume => 'Общий объем';

  @override
  String get averageWorkingWeight => 'Средний рабочий вес';

  @override
  String get assistanceWeight => 'Вес помощи';

  @override
  String get maxRepsInSet => 'Макс. повторений в подходе';

  @override
  String get totalReps => 'Всего повторений';

  @override
  String get cardioDistance => 'Дистанция';

  @override
  String get cardioDuration => 'Длительность';

  @override
  String get averagePace => 'Средний темп';

  @override
  String get totalTimeUnderTension => 'Общее время под нагрузкой';

  @override
  String get passwordPolicyTitle => 'Давайте создадим пароль, который качает:';

  @override
  String passwordPolicyMinLength(int minLength) {
    return 'минимум $minLength символов';
  }

  @override
  String passwordPolicyMaxLength(int maxLength) {
    return 'не больше $maxLength (мы верим в границы)';
  }

  @override
  String get passwordPolicyUpperCase => 'одна заглавная буква';

  @override
  String get passwordPolicyLowerCase => 'одна строчная буква';

  @override
  String get passwordPolicyDigit => 'одна цифра где-нибудь там';
}
