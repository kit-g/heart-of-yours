// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'heart_language.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appearance => 'Apariencia';

  @override
  String get units => 'Unidades';

  @override
  String get motto => 'Cada latido cuenta.';

  @override
  String get toLightMode => 'Claro';

  @override
  String get toDarkMode => 'Oscuro';

  @override
  String get toSystemMode => 'Sistema';

  @override
  String get email => 'Correo';

  @override
  String get yourEmail => 'Tu correo';

  @override
  String get cropAvatar => 'Recortar avatar';

  @override
  String get nameOptional => 'Nombre (opcional)';

  @override
  String get name => 'Nombre';

  @override
  String get saveName => 'Guardar nombre';

  @override
  String get changeName => 'Cambiar nombre';

  @override
  String get save => 'Guardar';

  @override
  String get settings => 'Ajustes';

  @override
  String get archive => 'Archivar';

  @override
  String get unarchive => 'Desarchivar';

  @override
  String get password => 'Contraseña';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get logInTitle => 'Hola de nuevo';

  @override
  String get logInBody => 'Ya empezaste algo importante. \nSigamos adelante.';

  @override
  String get signUpTitle => 'Empieza con Heart';

  @override
  String get signUpBody => 'Todo camino empieza con una decisión. \nEsta es tuya.';

  @override
  String get recoverTitle => 'Seguimos contigo';

  @override
  String get recoverBody => 'Tu camino no está perdido. \nSolo es una pausa — lo restableceremos juntos.';

  @override
  String get logInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signUpWithGoogle => 'Registrarse con Google';

  @override
  String get logInWithApple => 'Iniciar sesión con Apple';

  @override
  String get signUpWithApple => 'Registrarse con Apple';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get profile => 'Perfil';

  @override
  String get workout => 'Entrenamiento';

  @override
  String get history => 'Historial';

  @override
  String get exercises => 'Ejercicios';

  @override
  String get search => 'Buscar';

  @override
  String get startNewWorkout => 'Empezar un nuevo entrenamiento';

  @override
  String get cancelCurrentWorkoutTitle => '¿Cancelar el entrenamiento actual?';

  @override
  String get cancelCurrentWorkoutBody => 'Tienes un entrenamiento en curso. ¿Quieres cancelarlo y empezar uno nuevo?';

  @override
  String get startNewWorkoutFromTemplate => '¿Empezar un nuevo entrenamiento con esta plantilla?';

  @override
  String get startWorkout => 'Empezar entrenamiento';

  @override
  String get cancelWorkout => 'Cancelar entrenamiento';

  @override
  String get addExercises => 'Agregar ejercicios';

  @override
  String get addSet => 'Agregar serie';

  @override
  String get newExercise => 'Nuevo ejercicio';

  @override
  String get createNewExercise => 'Crear nuevo ejercicio';

  @override
  String get exerciseOptions => 'Opciones del ejercicio';

  @override
  String get showArchived => 'Mostrar archivados';

  @override
  String get archivedExercises => 'Ejercicios archivados';

  @override
  String archiveConfirmTitle(Object exerciseName) {
    return '¿Archivar $exerciseName?';
  }

  @override
  String get archiveConfirmBody =>
      'Este ejercicio se moverá a Ejercicios archivados (encuéntralo en Ejercicios → Más → Mostrar archivados).\n Archivarlo no afectará ninguno de tus entrenamientos pasados — tu historial queda intacto.';

  @override
  String get exerciseArchived => 'Este ejercicio está archivado \ny ya no aparecerá en tu biblioteca principal.';

  @override
  String get deleteSet => 'Eliminar serie';

  @override
  String get set => 'Serie';

  @override
  String get sets => 'Series';

  @override
  String get previous => 'Anterior';

  @override
  String get reps => 'Reps';

  @override
  String get time => 'Tiempo';

  @override
  String get kg => 'kg';

  @override
  String get mile => 'milla';

  @override
  String get km => 'km';

  @override
  String get milesPlural => 'millas';

  @override
  String miles(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany millas',
      one: '$howMany milla',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get repeat => 'Repetir';

  @override
  String get add => 'Agregar';

  @override
  String get share => 'Compartir';

  @override
  String get okBang => '¡Ok!';

  @override
  String get cancel => 'Cancelar';

  @override
  String get finish => 'Terminar';

  @override
  String get reset => 'Restablecer';

  @override
  String get h => 'h';

  @override
  String get min => 'min';

  @override
  String get sec => 'seg';

  @override
  String get lbs => 'lbs';

  @override
  String get skip => 'Omitir';

  @override
  String lb(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany lbs',
      one: '$howMany lb',
    );
    return '$_temp0';
  }

  @override
  String get saveAsTemplate => 'Guardar como plantilla';

  @override
  String get addNote => 'Agregar una nota';

  @override
  String get replaceExercise => 'Reemplazar ejercicio';

  @override
  String get weightUnit => 'Peso';

  @override
  String get distanceUnit => 'Distancia';

  @override
  String get duration => 'Duración';

  @override
  String get imperial => 'Imperial';

  @override
  String get metric => 'Métrico';

  @override
  String get restTimer => 'Temporizador de descanso';

  @override
  String get cancelTimer => 'Cancelar temporizador';

  @override
  String get removeExercise => 'Quitar ejercicio';

  @override
  String morningWorkout(String when) {
    return '$when, por la mañana';
  }

  @override
  String eveningWorkout(String when) {
    return '$when, por la noche';
  }

  @override
  String nightWorkout(String when) {
    return '$when, de madrugada';
  }

  @override
  String afternoonWorkout(String when) {
    return '$when, por la tarde';
  }

  @override
  String get emptyHistoryTitle => 'Tus entrenamientos completados aparecerán aquí';

  @override
  String get emptyHistoryBody => '¡Ve por ellos!';

  @override
  String get historyEndReached => 'Llegaste al final';

  @override
  String get historyLoadMoreError => 'No se pudieron cargar más entrenamientos';

  @override
  String get retry => 'Reintentar';

  @override
  String get workoutTimeoutTitle => '¿Sigues entrenando?';

  @override
  String get workoutTimeoutBody => 'Tu entrenamiento lleva un rato en pausa — retómalo o dale cierre.';

  @override
  String get notificationsDisabledReminder =>
      'Las notificaciones están desactivadas, así que no recibirás avisos del temporizador de descanso.';

  @override
  String get themePresetSetting => 'Tema';

  @override
  String get themePresetSettingSubtitle => 'Estilos afinados para claro y oscuro';

  @override
  String get themePresetForge => 'Forja';

  @override
  String get themePresetInk => 'Tinta';

  @override
  String get themePresetUtility => 'Utilitario';

  @override
  String get themePresetEmber => 'Brasa';

  @override
  String get aboutApp => 'Acerca de la app';

  @override
  String get congratulations => '¡Felicidades!';

  @override
  String get congratulationsBody => '¡Completaste tu entrenamiento!';

  @override
  String goalsAchievedHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Metas alcanzadas',
      one: 'Meta alcanzada',
    );
    return '$_temp0';
  }

  @override
  String goalAchievedTarget(String goal, String target) {
    return '$goal · $target';
  }

  @override
  String get finishWorkoutTitle => '¿Terminar el entrenamiento?';

  @override
  String get finishWorkoutWarningTitle => '¿Completar tu entrenamiento?';

  @override
  String get finishWorkoutWarningBody =>
      'Las series vacías o inválidas se descartarán, y todas las series válidas se marcarán como completadas.';

  @override
  String get finishWorkoutBody => '¿Todo listo para terminar este entrenamiento?';

  @override
  String get cancelWorkoutBody => 'Se perderá todo el progreso realizado hasta ahora.';

  @override
  String get cancelWorkoutTitle => '¿Quieres cancelar este entrenamiento?';

  @override
  String get readyToFinish => '¡Sí, ya terminé!';

  @override
  String get keepCurrentAccount => 'No, mantener el entrenamiento actual';

  @override
  String get cancelAndStartNewWorkout => 'Sí, cancelarlo y empezar uno nuevo';

  @override
  String get resumeWorkout => 'No, reanudar entrenamiento';

  @override
  String get deleteThis => 'Sí, eliminarlo';

  @override
  String get deleted => 'Eliminado';

  @override
  String get notReadyToFinish => '¡No, una serie más!';

  @override
  String get deleteTemplateTitle => '¿Quieres eliminar esta plantilla de entrenamiento?';

  @override
  String get deleteTemplateBody => 'Esto no se puede deshacer';

  @override
  String get quitEditing => '¿Salir de la edición?';

  @override
  String get changesWillBeLost => 'Se perderán todos los cambios';

  @override
  String get quitPage => 'Salir de esta página';

  @override
  String get stayHere => 'Quedarme aquí';

  @override
  String get notificationSettings => 'Ajustes de notificaciones';

  @override
  String selected(Object count) {
    return '$count seleccionados';
  }

  @override
  String forExercise(String exercise) {
    return 'para $exercise';
  }

  @override
  String get restTimerSubtitle => 'Ajusta la duración con los botones +/-.';

  @override
  String get addSeconds => '+10s';

  @override
  String get subtractSeconds => '-10s';

  @override
  String get restComplete => '¡Descanso terminado!';

  @override
  String get workoutsPerWeek => 'Entrenamientos por semana';

  @override
  String get workoutsPerWeekTitle => 'Tus entrenamientos se mostrarán aquí';

  @override
  String get workoutsPerWeekBody => '¡Ve por ellos!';

  @override
  String get goals => 'Metas';

  @override
  String get addGoal => 'Agregar meta';

  @override
  String get noGoalsYet => 'Aún no hay metas';

  @override
  String get workouts => 'Entrenamientos';

  @override
  String get newGoal => 'Nueva meta';

  @override
  String get goalTarget => 'Objetivo';

  @override
  String get goalPerWeek => 'por semana';

  @override
  String get goalPerMonth => 'por mes';

  @override
  String goalDue(String date) {
    return 'Vence $date';
  }

  @override
  String get goalComplete => 'Completada';

  @override
  String get goalMilestone => 'Hito';

  @override
  String get goalWeekly => 'Semanal';

  @override
  String get goalMonthly => 'Mensual';

  @override
  String get goalLadder => 'Hitos';

  @override
  String get goalAddRung => 'Agregar hito';

  @override
  String goalAchievedOn(String date) {
    return 'Alcanzado el $date';
  }

  @override
  String get goalNoDeadline => 'Sin fecha límite';

  @override
  String get goalSetDeadline => 'Fijar una fecha límite';

  @override
  String get goalClearDeadline => 'Quitar fecha límite';

  @override
  String get goalsViewAchieved => 'Logradas';

  @override
  String get goalsAchievedTitle => 'Logradas';

  @override
  String get goalsViewActive => 'Volver';

  @override
  String get goalOpenWorkout => 'Ver la sesión';

  @override
  String get goalWorkoutGone => 'Esa sesión ya no está en este dispositivo';

  @override
  String get goalsAtCapacity => 'Ya tienes todas las metas que Heart guarda. Elimina una para hacerle espacio a otra.';

  @override
  String get category => 'Categoría';

  @override
  String get target => 'Músculo';

  @override
  String get removeFilter => 'Quitar filtro';

  @override
  String restCompleteBody(Object exercise) {
    return 'Siguiente: $exercise';
  }

  @override
  String weightedSetRepresentation(Object weight, Object reps) {
    return '$weight x $reps';
  }

  @override
  String get templates => 'Plantillas';

  @override
  String get exampleTemplates => 'Plantillas de ejemplo';

  @override
  String get template => 'Plantilla';

  @override
  String get newTemplate => 'Nueva plantilla';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String get renameFolder => 'Renombrar carpeta';

  @override
  String get deleteFolder => 'Eliminar carpeta';

  @override
  String get deleteFolderBody => 'Las plantillas que contiene se conservarán';

  @override
  String get moveToFolder => 'Mover a carpeta';

  @override
  String get noFolder => 'Sin carpeta';

  @override
  String get folderNameTaken => 'Ya tienes una carpeta con este nombre';

  @override
  String get editTemplate => 'Editar plantilla';

  @override
  String get editWorkout => 'Editar entrenamiento';

  @override
  String get templateName => 'Nombre de la plantilla';

  @override
  String get workoutName => 'Nombre del entrenamiento';

  @override
  String get cannotBeEmpty => 'No puede estar vacío';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get yourPassword => 'Tu contraseña';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get resetPasswordBody =>
      'Te enviaremos un enlace de restablecimiento a tu correo más rápido de lo que tardas en decir “olvidé mi contraseña”. Después de esto no hay vuelta atrás… a menos que canceles, claro. 😌';

  @override
  String get orConnector => '- o -';

  @override
  String get invalidCredentials => '¡Vaya, eso no funcionó! Revisa tus datos, ¿sí?';

  @override
  String get weakPassword => '¡Ya casi! Prueba una contraseña más fuerte para mantener tu cuenta segura.';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get noConnectivity =>
      '¡Uy! El internet se tropezó con una mancuerna. 🏋️‍♂️ ¡Inténtalo de nuevo en un momento!';

  @override
  String get signUp => 'Registrarse';

  @override
  String get sendResetLink => 'Enviar enlace';

  @override
  String get recoveryLinkMessage =>
      'Si existe una cuenta con este correo, recibirás un enlace de restablecimiento en breve. Revisa tu bandeja de entrada y la carpeta de spam.';

  @override
  String get recoveryLinkMessageSent =>
      '💌¡Tu correo para configurar la contraseña va en camino! Revisa tu bandeja de entrada (o quizá la carpeta de spam — le gusta esconderse).';

  @override
  String get emailExistsTitle => 'El correo ya existe';

  @override
  String get emailExistsOkButton => '¡Sí, iniciar sesión!';

  @override
  String get emailExistsCancelButton => 'No, yo me encargo';

  @override
  String emailExistsBody(Object address) {
    return 'Ya existe una cuenta con $address. ¿Quieres iniciar sesión en su lugar?';
  }

  @override
  String get sendResetLinkBody => 'Escribe tu correo y te ayudaremos a restablecer tu contraseña';

  @override
  String get userDisabled => 'Esta cuenta está deshabilitada';

  @override
  String get unknownError => 'Ocurrió un error desconocido';

  @override
  String get accountControl => 'Control de la cuenta';

  @override
  String get leaveFeedback => 'Enviar comentarios';

  @override
  String leaveFeedbackBody(Object emoji) {
    return 'Toma una captura, garabatea lo que sientes y déjanos una nota. Puedes recorrer la app mientras tanto.\n\nNos encantan los comentarios. Cada garabato y nota nos ayuda a mejorar la app — para ti y para todos los demás. Así que gracias. En serio. $emoji';
  }

  @override
  String get feedbackReceived => '¡Recibimos tus comentarios, gracias!';

  @override
  String get toFeedback => '¡A comentar!';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountTitle => '¿Seguro que quieres eliminar tu cuenta?';

  @override
  String deleteAccountBody(Object deadline) {
    return 'Tu cuenta quedará programada para eliminarse en $deadline días. Durante ese tiempo, aún puedes iniciar sesión y revertir esta decisión. Una vez pasado el plazo, tu cuenta y tus datos personales se eliminarán de forma permanente.';
  }

  @override
  String get deleteAccountCancelMessage => '¡Ay no, me gusta estar aquí!';

  @override
  String get deleteAccountConfirmMessage => '¡Sí, sigan sin mí!';

  @override
  String get confirmDeleteAccountTitle => 'Confirma la eliminación de tu cuenta';

  @override
  String get confirmDeleteAccountCancelMessage => 'Cambié de opinión, cancelar';

  @override
  String get confirmDeleteAccountOkMessage => '¡Adiós!';

  @override
  String get accountDeleted => 'Cuenta eliminada';

  @override
  String accountDeletedBody(Object date) {
    return 'Tu cuenta quedó programada para eliminarse el $date.\n\nSi cambias de opinión, puedes restaurarla en cualquier momento antes de esa fecha.\n\nSolo toca el botón de abajo para cancelar la eliminación y conservar tu cuenta.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Deshacer la despedida 🥇🔥';

  @override
  String get movement => 'Movimiento';

  @override
  String get pattern => 'Patrón';

  @override
  String get stability => 'Estabilidad';

  @override
  String get skillAtMost => 'Técnica máxima';

  @override
  String get patternHelp =>
      'El movimiento en sí — más general que el equipo, más específico que la parte del cuerpo. Los ejercicios que comparten un patrón pueden sustituirse entre sí.';

  @override
  String get stabilityHelp =>
      'Cuánto sostiene el equipo la trayectoria por ti. Libre significa que tú equilibras el peso; máquina, que la trayectoria es fija.';

  @override
  String get skillAtMostHelp =>
      'Cuánta técnica exige un ejercicio antes de poder cargarlo con seguridad. Elegir Moderada también incluye Baja.';

  @override
  String get clearFilters => 'Limpiar';

  @override
  String get alsoTry => 'Prueba también';

  @override
  String get about => 'Descripción';

  @override
  String get records => 'Récords';

  @override
  String get chartWeeklyAverage => 'Promedio semanal';

  @override
  String get chartMonthlyAverage => 'Promedio mensual';

  @override
  String get chartYearlyAverage => 'Promedio anual';

  @override
  String get chartRangeMonth => '1M';

  @override
  String get chartRangeQuarter => '3M';

  @override
  String get chartRangeYear => '1A';

  @override
  String get chartRangeAll => 'Todo';

  @override
  String get chartGenericLabel => 'Gráfico';

  @override
  String exerciseChartSummary(Object metric, Object start, Object end, Object latest, Object trend) {
    return '$metric de $start a $end. Último valor: $latest. Tendencia: $trend.';
  }

  @override
  String get exerciseChartTrendUp => 'En aumento';

  @override
  String get exerciseChartTrendDown => 'En descenso';

  @override
  String get exerciseChartTrendFlat => 'Estable';

  @override
  String healthCardSummary(String metric, String value, String when) {
    return '$metric, $value, $when';
  }

  @override
  String get charts => 'Gráficos';

  @override
  String get emptyExerciseHistoryTitle => 'Reps fantasma detectadas 👻';

  @override
  String get emptyExerciseHistoryBody =>
      'Tu historial de este ejercicio está más vacío que un gimnasio un lunes por la mañana. ¡Hora de llenarlo con unos PR gloriosos!';

  @override
  String get errorExerciseHistoryTitle => '¡Ups! Alguien se saltó el día de datos 🤷‍♀️';

  @override
  String get errorExerciseHistoryBody =>
      'Parece que la app se tropezó con sus propios cordones. Inténtalo de nuevo, ¡y prometemos atarlos más fuerte la próxima vez!';

  @override
  String get personalRecords => 'Récords personales';

  @override
  String get maxDuration => 'Duración máxima';

  @override
  String get maxDistance => 'Distancia máxima';

  @override
  String get maxWeight => 'Peso máximo';

  @override
  String get maxReps => 'Reps máximas';

  @override
  String get capturePhoto => 'Tomar una foto nueva';

  @override
  String get chooseFromGallery => 'Elegir de la galería';

  @override
  String get removeCurrentPhoto => 'Quitar foto actual';

  @override
  String get mine => 'Míos';

  @override
  String get goToWorkout => 'Ir al entrenamiento';

  @override
  String get setTimer => 'Poner temporizador';

  @override
  String get updateRequiredTitle => 'Ups. Esta es culpa nuestra';

  @override
  String get updateRequiredBody =>
      'Hay una actualización importante esperando — una que mantiene la app funcionando como debe.\n\nNecesitas instalarla antes de continuar.\nGracias por tu paciencia — y perdón por la interrupción.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Actualizar en $storeName';
  }

  @override
  String get addPhoto => 'Agregar foto';

  @override
  String get editWorkoutName => 'Editar nombre del entrenamiento';

  @override
  String get editWorkoutTimes => 'Editar horas';

  @override
  String get adjustTimes => 'Ajustar hora de inicio/fin';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get endTime => 'Hora de fin';

  @override
  String get endBeforeStart => 'La hora de fin no puede ser anterior a la de inicio.';

  @override
  String get cropImage => 'Recortar imagen';

  @override
  String get removePhoto => 'Quitar foto';

  @override
  String get aboutExercise => 'Acerca del ejercicio';

  @override
  String get myDashboard => 'Mi panel';

  @override
  String get newChart => 'Nuevo gráfico';

  @override
  String get emptyChartStateTitle => 'Esto se ve un poco vacío';

  @override
  String get emptyChartStateBody => 'Agrega tu primera serie para empezar a ver progreso real';

  @override
  String get topSetWeight => 'Peso de la mejor serie';

  @override
  String get estimatedOneRepMax => '1RM estimado';

  @override
  String get totalVolume => 'Volumen total';

  @override
  String get averageWorkingWeight => 'Peso promedio de trabajo';

  @override
  String get assistanceWeight => 'Peso de asistencia';

  @override
  String get maxRepsInSet => 'Máx. de reps en una serie';

  @override
  String get totalReps => 'Reps totales';

  @override
  String get cardioDistance => 'Distancia';

  @override
  String get cardioDuration => 'Duración';

  @override
  String get averagePace => 'Ritmo promedio';

  @override
  String get totalTimeUnderTension => 'Tiempo total bajo tensión';

  @override
  String get passwordPolicyTitle => 'Hagamos una contraseña que levante pesado:';

  @override
  String passwordPolicyMinLength(int minLength) {
    return 'al menos $minLength caracteres';
  }

  @override
  String passwordPolicyMaxLength(int maxLength) {
    return 'no más de $maxLength (creemos en los límites)';
  }

  @override
  String get passwordPolicyUpperCase => 'una letra mayúscula';

  @override
  String get passwordPolicyLowerCase => 'una letra minúscula';

  @override
  String get passwordPolicyDigit => 'un número por ahí';

  @override
  String get deleteImageDialogTitle => '¿Quitar esta imagen?';

  @override
  String get deleteImageDialogBody => 'No afectará el entrenamiento — solo quita la imagen';

  @override
  String get myProgression => 'Mi progreso';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get weightUnitLabel => 'Unidad de peso';

  @override
  String get distanceUnitLabel => 'Unidad de distancia';

  @override
  String get close => 'Cerrar';

  @override
  String get noWorkoutSelectedTitle => 'Nada seleccionado';

  @override
  String get noWorkoutSelectedBody => 'Elige un entrenamiento para ver lo que hiciste y hacer cambios.';

  @override
  String get noExerciseSelectedTitle => 'Nada seleccionado';

  @override
  String get noExerciseSelectedBody =>
      'Elige un ejercicio para ver cómo se hace, junto con tu historial y tus récords.';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get viewProgressPhotos => 'Ver fotos de progreso';

  @override
  String get confirmEdit => 'Confirmar';

  @override
  String get clearSearchTooltip => 'Borrar búsqueda';

  @override
  String get changeProfilePhoto => 'Cambiar foto de perfil';

  @override
  String get viewAccountDetails => 'Detalles de la cuenta';

  @override
  String get viewProfilePhoto => 'Ver foto de perfil';

  @override
  String durationPickerSetTo(Object duration) {
    return 'Poner el temporizador de descanso en $duration';
  }

  @override
  String get emptyWorkoutLabel => 'Entrenamiento vacío';

  @override
  String progressPhotoLabel(Object date) {
    return 'Foto de progreso del $date';
  }

  @override
  String exerciseThumbnailLabel(Object exerciseName) {
    return 'Miniatura de $exerciseName';
  }

  @override
  String goalLadderSummary(Object achieved, Object total, Object current) {
    return '$achieved de $total objetivos alcanzados. Actual: $current.';
  }

  @override
  String restTimerRemaining(Object remaining) {
    return 'Temporizador de descanso: quedan $remaining';
  }

  @override
  String get health => 'Salud';

  @override
  String get healthActiveEnergy => 'Energía activa';

  @override
  String get healthBodyMass => 'Masa corporal';

  @override
  String get healthBpm => 'lpm';

  @override
  String get healthChecking => 'Buscando lecturas nuevas…';

  @override
  String healthLatestReading(String when) {
    return 'Última lectura · $when';
  }

  @override
  String get healthDelete => 'Eliminar datos de salud';

  @override
  String get healthDeleteBody =>
      'Esto borra lo que Heart ha leído en este dispositivo. Nada cambia en el almacén de salud de tu teléfono, y Heart volverá a leerlo la próxima vez que sincronice.';

  @override
  String get healthDeleteTitle => '¿Eliminar la copia de Heart de tus datos de salud?';

  @override
  String get healthHeartRateVariability => 'Variabilidad de la frecuencia cardiaca';

  @override
  String get healthHoursShort => 'h';

  @override
  String get healthInviteAction => 'Mostrar mis datos de salud';

  @override
  String get healthInviteBody =>
      'Heart puede mostrar tu frecuencia cardiaca en reposo, sueño, pasos y masa corporal junto a tus entrenamientos. Los lee del almacén de salud de tu teléfono y los guarda en este dispositivo.';

  @override
  String get healthInviteDismiss => 'Ahora no';

  @override
  String get healthInviteTitle => 'Datos de salud';

  @override
  String get healthKilocalories => 'kcal';

  @override
  String get healthMilliseconds => 'ms';

  @override
  String get healthMinutesShort => 'm';

  @override
  String get healthOffInHealthApp =>
      'En la app Salud, toca tu foto de perfil, luego Apps, y permite que Heart lea tus datos.';

  @override
  String get healthOffInSettings =>
      'Permite que Heart lea tus datos de salud en los ajustes de salud de tu dispositivo. Permite también el acceso a datos anteriores, o los gráficos se quedarán en los últimos 30 días.';

  @override
  String get healthOffTitle => 'Heart no está leyendo ningún dato de salud';

  @override
  String get healthOnThisDevice => 'En este dispositivo';

  @override
  String get healthOpenHealthApp => 'Abrir la app Salud';

  @override
  String get healthOpenHealthAppHint => 'Toca tu foto de perfil, luego Apps';

  @override
  String get healthOpenSettingsHint => 'Permite también el acceso a datos anteriores';

  @override
  String get healthOpenSettings => 'Abrir ajustes';

  @override
  String get healthRestingHeartRate => 'Frecuencia cardiaca en reposo';

  @override
  String get healthSettingsBody =>
      'Heart lee la frecuencia cardiaca en reposo, la variabilidad de la frecuencia cardiaca, el sueño, los pasos, la energía activa y la masa corporal del almacén de salud de tu teléfono. Se quedan en este dispositivo.';

  @override
  String get healthWriteWorkouts => 'Guardar entrenamientos en Salud';

  @override
  String get healthWriteWorkoutsOn => 'Se guarda cuánto tiempo entrenas, y nada más';

  @override
  String get healthWriteWorkoutsOff => 'Desactivado · Heart no está guardando tus entrenamientos';

  @override
  String get healthSleep => 'Sueño';

  @override
  String get healthSteps => 'Pasos';

  @override
  String get deleteWorkoutTitle => '¿Quieres eliminar este entrenamiento?';

  @override
  String get deleteWorkoutBody => 'Esto no se puede deshacer';

  @override
  String get importData => 'Importar historial de entrenamientos';

  @override
  String get importPreviewTitle => 'Todo listo para importar';

  @override
  String importPreviewSummary(num workouts, num sets) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts entrenamientos',
      one: '1 entrenamiento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets series',
      one: '1 serie',
    );
    return '$_temp0 y $_temp1 listos para importar';
  }

  @override
  String importPreviewSummaryPartial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrenamientos son nuevos',
      one: '1 entrenamiento es nuevo',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNothingNew(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los $count entrenamientos de este archivo ya están',
      one: 'el entrenamiento de este archivo ya está',
    );
    return 'Nada nuevo — $_temp0 aquí';
  }

  @override
  String importPreviewMatched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ejercicios ya coinciden con la biblioteca',
      one: '1 ejercicio ya coincide con la biblioteca',
    );
    return '$_temp0';
  }

  @override
  String importPreviewAlreadyHere(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrenamientos ya están aquí — se omitirán',
      one: '1 entrenamiento ya está aquí — se omitirá',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String get importConsentTitle => 'Nuevos ejercicios encontrados';

  @override
  String get importConsentBody =>
      'Estos no coincidieron con nada en la biblioteca. Marca los que quieras traer como tus ejercicios personalizados — lo que quede sin marcar se queda fuera, junto con sus series.';

  @override
  String get importAction => 'Importar';

  @override
  String importSetsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String importSkippedSets(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series se quedaron fuera',
      one: '1 serie se quedó fuera',
    );
    return '$_temp0 con los ejercicios que descartaste';
  }

  @override
  String get yourData => 'Tus datos';

  @override
  String get account => 'Cuenta';

  @override
  String get app => 'App';

  @override
  String get importExplainerStrong =>
      '¿Entrenabas con Strong? Trae tu historial contigo.\n\nEn la app Strong, ve a Perfil → Ajustes → Exportar datos de Strong. Te llegará un archivo CSV por correo — guárdalo y luego elígelo aquí.';

  @override
  String get importSafeToRetry =>
      'Todo se importa — entrenamientos, series, ejercicios. Importar el mismo archivo dos veces es seguro: lo que ya está aquí se omite, nunca se duplica.';

  @override
  String get chooseFile => 'Elegir archivo';

  @override
  String get csvFiles => 'Archivos CSV';

  @override
  String get importInFlight => 'Importando — un momento…';

  @override
  String get importFailedHeadline => 'Ese archivo no funcionó';

  @override
  String get importFailedBody =>
      'No se pudo leer como una exportación de Strong. Elige el archivo CSV del correo de exportación de Strong e inténtalo de nuevo.';

  @override
  String get importReportTitle => '¡Importado!';

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrenamientos importados',
      one: '1 entrenamiento importado',
      zero: 'Ningún entrenamiento nuevo',
    );
    return '$_temp0';
  }

  @override
  String importSkippedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrenamientos ya estaban aquí — omitidos',
      one: '1 entrenamiento ya estaba aquí — omitido',
    );
    return '$_temp0';
  }

  @override
  String importedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0 en total';
  }

  @override
  String importSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filas no se pudieron leer',
      one: '1 fila no se pudo leer',
    );
    return '$_temp0';
  }

  @override
  String get importNewExercisesHeader => 'Nuevos ejercicios personalizados';

  @override
  String get importNewExercisesBody =>
      'Estos no coincidieron con nada en la biblioteca, así que llegaron como tus ejercicios personalizados:';

  @override
  String get machineTranslatedCopy => 'Traducción automática';
}
