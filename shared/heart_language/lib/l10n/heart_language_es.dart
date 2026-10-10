// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'heart_language.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get calendar => 'Calendario';

  @override
  String get appearance => 'Apariencia';

  @override
  String get units => 'Unidades';

  @override
  String get motto => 'Every beat counts.';

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
  String get noAccount => 'Sin cuenta';

  @override
  String get noAccountTitle => 'Estás usando Heart sin cuenta';

  @override
  String get noAccountBodyLocal =>
      'Tus datos de salud nunca salen de tu teléfono. Sin cuenta, nada más sale tampoco: tus entrenamientos, plantillas y metas viven solo en este dispositivo.';

  @override
  String get noAccountBodySignIn =>
      'Iniciar sesión añade una copia de seguridad y sincronización entre tus dispositivos, y más adelante compartir con amigos y coaching.';

  @override
  String get noAccountBodyLose => 'Si pierdes este teléfono, pierdes tus datos.';

  @override
  String get notNow => 'Ahora no';

  @override
  String get onboardingWelcomeTitle => 'Te damos la bienvenida a Heart';

  @override
  String get onboardingWelcomeBody =>
      'Un tracker de entrenamiento que no se interpone en tu camino: planifica una sesión, registra cada serie y sigue tu progreso.';

  @override
  String get onboardingLocalTitle => 'Tus datos se quedan en este dispositivo';

  @override
  String get onboardingLocalBody =>
      'No necesitas una cuenta. Tus entrenamientos y los datos de salud que permitas que Heart lea se guardan en este dispositivo y en ningún otro lugar.';

  @override
  String get onboardingLocalTrade =>
      'La cuestión es sencilla: si pierdes el dispositivo, también pierdes los datos, a menos que hayas iniciado sesión.';

  @override
  String get onboardingAccountTitle => 'Inicia sesión cuando quieras';

  @override
  String get onboardingAccountBody =>
      'Una cuenta añade una copia de seguridad y permite sincronizar tus datos entre dispositivos. Más adelante, también podrá permitirte compartirlos con amigos y coaches. Nada cambia hasta que tú decidas hacerlo.';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String onboardingScreenOf(Object current, Object total) {
    return 'Pantalla $current de $total';
  }

  @override
  String get profile => 'Perfil';

  @override
  String get workout => 'Entreno';

  @override
  String get history => 'Historial';

  @override
  String get exercises => 'Ejercicios';

  @override
  String get search => 'Buscar';

  @override
  String get startNewWorkout => 'Nuevo entrenamiento';

  @override
  String get cancelCurrentWorkoutTitle => '¿Cancelar el entrenamiento actual?';

  @override
  String get cancelCurrentWorkoutBody => 'Tienes un entrenamiento en curso. ¿Quieres cancelarlo y empezar uno nuevo?';

  @override
  String get startNewWorkoutFromTemplate => '¿Empezar un nuevo entrenamiento con esta plantilla?';

  @override
  String get startWorkout => 'Empezar entrenamiento';

  @override
  String get yourWorkouts => 'Tus entrenamientos';

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
  String fillColumn(String column) {
    return '$column: rellenar todas las series sin marcar';
  }

  @override
  String get tickAllSets => 'Marcar todas las series';

  @override
  String get untickAllSets => 'Desmarcar todas las series';

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
  String get emptyHistoryBody => '¡Ve a por ellos!';

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
  String get whatsNew => 'Novedades';

  @override
  String get whatsNewThisVersion => 'Esta versión';

  @override
  String get whatsNewFeatureOff => 'Activar en Funciones';

  @override
  String get whatsNewFeatureOn => 'Activado · ver en Funciones';

  @override
  String get whatsNewEmpty => 'Esta versión de la app no incluye notas de la versión.';

  @override
  String get settingsWhatsNewUnread => 'Ajustes, novedades sin leer';

  @override
  String get whatsNewUnread => 'Novedades, sin leer';

  @override
  String get congratulations => '¡Felicidades!';

  @override
  String get congratulationsBody => '¡Completaste tu entrenamiento!';

  @override
  String recordsAchievedHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nuevos récords',
      one: 'Nuevo récord',
    );
    return '$_temp0';
  }

  @override
  String recordBadgeWas(String value) {
    return 'antes $value';
  }

  @override
  String recordBadgeLabel(String exercise, String kind, String value, String previous) {
    return 'Nuevo récord: $exercise, $kind $value, antes $previous';
  }

  @override
  String firstRecordsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'primeros récords',
      one: 'primer récord',
    );
    return '$_temp0';
  }

  @override
  String firstRecordsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count primeros récords, de ejercicios hechos por primera vez',
      one: '$count primer récord, de un ejercicio hecho por primera vez',
    );
    return '$_temp0';
  }

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
  String get notificationsOffPrompt =>
      'Las notificaciones están desactivadas, así que no podremos recordarte un entrenamiento sin terminar.';

  @override
  String get notificationsOffEnable => 'Activar';

  @override
  String get notificationsOffLater => 'Recordármelo luego';

  @override
  String get notificationsOffNever => 'No volver a recordármelo';

  @override
  String get untickedSetsTitle => 'Algunas series no están marcadas';

  @override
  String get untickedSetsBody =>
      'Las rellenaste pero no las marcaste. ¿Guardarlas como completadas o terminar sin ellas?';

  @override
  String get saveUntickedSets => 'Guardar como completadas';

  @override
  String get discardUntickedSets => 'Terminar sin ellas';

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
  String get workoutsPerWeekBody => '¡Ve a por ellos!';

  @override
  String get goals => 'Metas';

  @override
  String get addGoal => 'Nueva meta';

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
  String get noTemplatesYet => 'Aún no hay plantillas';

  @override
  String get noChartsYet => 'Aún no hay gráficos';

  @override
  String get exampleTemplates => 'Plantillas preestablecidas';

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
  String get duplicate => 'Duplicar';

  @override
  String templateCopyName(Object name) {
    return '$name (copia)';
  }

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
  String get eraseData => 'Borrar mis datos';

  @override
  String get eraseDataTitle => '¿Seguro que quieres borrar tus datos?';

  @override
  String get eraseDataBody =>
      'Tus entrenamientos, plantillas, ejercicios personalizados, objetivos y ajustes de gráficos se eliminan de este teléfono, junto con la copia de Heart de tus datos de salud. Los registros de salud de tu propio teléfono no se tocan. Sin una cuenta no hay copia de seguridad: esto no se puede deshacer.';

  @override
  String get eraseDataCancelMessage => 'Conservar mis datos';

  @override
  String get eraseDataConfirmMessage => 'Borrar todo';

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
  String get movement => 'Ejercicio';

  @override
  String get pattern => 'Tipo';

  @override
  String get stability => 'Modo';

  @override
  String get skillAtMost => 'Nivel';

  @override
  String get patternHelp =>
      'Este filtro de ejercicios es más amplio que el botón Categoría y más específico que el Músculo. Los ejercicios que pertenecen al mismo Tipo pueden sustituirse entre sí.';

  @override
  String get stabilityHelp =>
      'Es la elección del nivel de asistencia. Peso libre te permite elegir la trayectoria y el peso. Al elegir la máquina la trayectoria es fija.';

  @override
  String get skillAtMostHelp =>
      'Qué nivel y qué preparación física requiere cada ejercicio. El nivel Medio también incluye el nivel Bajo.';

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
  String get pickerRecent => 'Recientes';

  @override
  String get pickerAllExercises => 'Todos los ejercicios';

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
  String get bestSetVolume => 'Mejor volumen por serie';

  @override
  String get mostReps => 'Más repeticiones';

  @override
  String get bestPace => 'Mejor ritmo';

  @override
  String get leastAssistance => 'Menor asistencia';

  @override
  String get repMaxes => 'Máximos por repeticiones';

  @override
  String repMaxCount(num reps) {
    String _temp0 = intl.Intl.pluralLogic(
      reps,
      locale: localeName,
      other: '$reps reps',
      one: '$reps rep',
    );
    return '$_temp0';
  }

  @override
  String get allTime => 'Histórico';

  @override
  String get sessions => 'Sesiones';

  @override
  String get firstPerformed => 'Primera vez';

  @override
  String get totalTime => 'Tiempo total';

  @override
  String get totalDistance => 'Distancia total';

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
  String get addChartToProfile => 'Agregar al perfil';

  @override
  String get addToActiveWorkout => 'Agregar al entrenamiento';

  @override
  String get exerciseAddedToWorkout => 'Agregado al entrenamiento';

  @override
  String get chartAddedToProfile => 'Agregado al perfil';

  @override
  String get removeChartFromProfile => 'Quitar del perfil';

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
  String get healthInviteAction => 'Mis datos de salud';

  @override
  String get healthInviteBody =>
      'Heart puede mostrar tu frecuencia cardiaca en reposo, sueño, pasos y masa corporal junto a tus entrenamientos. Heart puede sacar tus datos de salud de otras aplicaciones y guardarlos en este dispositivo.';

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
  String get exportData => 'Exportar mis datos';

  @override
  String get exportExplainer =>
      'Todo lo que Heart guarda en este teléfono, en un archivo que es tuyo: entrenamientos con cada serie, plantillas y carpetas, ejercicios personalizados, ajustes de unidades y objetivos.';

  @override
  String get exportNoHealthData => 'Tus datos de salud no se incluyen: nunca salen de tu teléfono.';

  @override
  String get backfillRunning => 'Restaurando tu historial…';

  @override
  String backfillRunningOf(Object done, Object total) {
    return 'Restaurando tu historial… $done de $total';
  }

  @override
  String get backfillFailed => 'No se pudo terminar de restaurar tu historial.';

  @override
  String get exportAsJson => 'Exportar como JSON';

  @override
  String get exportJsonHint => 'Todo lo anterior, en el formato propio de Heart.';

  @override
  String get exportAsCsv => 'Exportar como CSV';

  @override
  String get exportCsvHint => 'Solo entrenamientos, una fila por serie: se abre en cualquier hoja de cálculo.';

  @override
  String get exportInFlight => 'Preparando tu archivo…';

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

  @override
  String get categoryWeightedBodyWeight => 'Peso corporal lastrado';

  @override
  String get categoryAssistedBodyWeight => 'Peso corporal asistido';

  @override
  String get categoryRepsOnly => 'Solo repeticiones';

  @override
  String get categoryCardio => 'Cardio';

  @override
  String get categoryDuration => 'Duración';

  @override
  String get categoryMachine => 'Máquina';

  @override
  String get categoryDumbbell => 'Mancuernas';

  @override
  String get categoryBarbell => 'Barra';

  @override
  String get categoryWeightedDistance => 'Distancia lastrada';

  @override
  String get categoryWeightedDuration => 'Duración lastrada';

  @override
  String get metresShort => 'm';

  @override
  String get yardsShort => 'yd';

  @override
  String get targetCore => 'Core';

  @override
  String get targetArms => 'Brazos';

  @override
  String get targetBack => 'Espalda';

  @override
  String get targetChest => 'Pecho';

  @override
  String get targetLegs => 'Piernas';

  @override
  String get targetShoulders => 'Hombros';

  @override
  String get targetOther => 'Otro';

  @override
  String get targetOlympic => 'Olímpico';

  @override
  String get targetFullBody => 'Cuerpo completo';

  @override
  String get targetCardio => 'Cardio';

  @override
  String get skillLow => 'Bajo';

  @override
  String get skillModerate => 'Medio';

  @override
  String get skillHigh => 'Alto';

  @override
  String get stabilityFree => 'Peso libre';

  @override
  String get stabilitySupported => 'Con apoyo';

  @override
  String get stabilityMachine => 'Máquina';

  @override
  String get patternCalfRaise => 'Elevación de talones';

  @override
  String get patternCardioSteady => 'Cardio constante';

  @override
  String get patternChestDip => 'Fondos en paralelas';

  @override
  String get patternChestFly => 'Aperturas de pecho';

  @override
  String get patternCoreBracing => 'Estabilización del core';

  @override
  String get patternDeadliftFloor => 'Peso muerto desde el suelo';

  @override
  String get patternDeclinePress => 'Press declinado';

  @override
  String get patternElbowExtension => 'Extensión de codo';

  @override
  String get patternElbowFlexion => 'Flexión de codo';

  @override
  String get patternForearm => 'Antebrazo';

  @override
  String get patternFrontRaise => 'Elevación frontal';

  @override
  String get patternFullBodyConditioning => 'Acondicionamiento general';

  @override
  String get patternGluteIsolation => 'Aislamiento de glúteos';

  @override
  String get patternHipAbduction => 'Abducción de cadera';

  @override
  String get patternHipAdduction => 'Aducción de cadera';

  @override
  String get patternHipExtensionBridge => 'Puente de glúteos';

  @override
  String get patternHipFlexionHanging => 'Elevación de piernas colgado';

  @override
  String get patternHipHingeStifflegged => 'Peso muerto piernas rígidas';

  @override
  String get patternHorizontalPress => 'Press horizontal';

  @override
  String get patternHorizontalRow => 'Remo horizontal';

  @override
  String get patternInclinePress => 'Press inclinado';

  @override
  String get patternKneeExtension => 'Extensión de rodilla';

  @override
  String get patternKneeFlexion => 'Flexión de rodilla';

  @override
  String get patternLateralRaise => 'Elevación lateral';

  @override
  String get patternLungeSplit => 'Zancadas';

  @override
  String get patternMobility => 'Movilidad';

  @override
  String get patternOlympicLift => 'Levantamiento olímpico';

  @override
  String get patternPlyometricLower => 'Pliometría de piernas';

  @override
  String get patternPullover => 'Pullover';

  @override
  String get patternRearDelt => 'Deltoide posterior';

  @override
  String get patternShrug => 'Encogimientos';

  @override
  String get patternSpinalExtension => 'Extensión lumbar';

  @override
  String get patternSquatBilateral => 'Sentadilla';

  @override
  String get patternTrunkFlexion => 'Flexión de tronco';

  @override
  String get patternTrunkLateralRotation => 'Rotación de tronco';

  @override
  String get patternUprightRow => 'Remo al mentón';

  @override
  String get patternVerticalPress => 'Press vertical';

  @override
  String get patternVerticalPull => 'Jalón vertical';

  @override
  String get patternLoadedCarry => 'Acarreo con carga';

  @override
  String get patternSledPushDrag => 'Empuje y arrastre de trineo';

  @override
  String upsyncRunning(Object done, Object total) {
    return 'Guardando en tu cuenta… $done de $total';
  }

  @override
  String upsyncFailed(Object done, Object total) {
    return 'Copia en pausa — $done de $total subidos. Comprueba tu conexión e inténtalo de nuevo.';
  }

  @override
  String upsyncRefused(Object done, Object total) {
    return 'Copia de seguridad en pausa: $done de $total subidos. Algo ha fallado por nuestra parte.';
  }

  @override
  String upsyncDone(Object uploaded, Object existing) {
    return 'Copia completada: $uploaded subidos, $existing ya estaban.';
  }

  @override
  String upsyncSkipped(num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped elementos no se pudieron subir.',
      one: '1 elemento no se pudo subir.',
    );
    return '$_temp0';
  }

  @override
  String get exerciseNote => 'Nota del ejercicio';

  @override
  String get addExerciseNote => 'Añadir nota';

  @override
  String get editExerciseNote => 'Editar nota';

  @override
  String get removeExerciseNote => 'Eliminar nota';

  @override
  String get pinExerciseNote => 'Fijar para futuros entrenamientos';

  @override
  String get unpinExerciseNote => 'Desfijar para futuros entrenamientos';

  @override
  String exerciseNoteLimit(int limit) {
    return 'Usa un máximo de $limit caracteres';
  }

  @override
  String get exerciseNoteSaveFailed => 'No se pudo guardar la nota. Inténtalo de nuevo.';

  @override
  String get workoutNote => 'Nota del entrenamiento';

  @override
  String get addWorkoutNote => 'Añadir nota';

  @override
  String get editWorkoutNote => 'Editar nota';

  @override
  String get removeWorkoutNote => 'Eliminar nota';

  @override
  String get ongoingWorkoutChannel => 'Entrenamiento en curso';

  @override
  String get ongoingWorkoutRest => 'Descanso';

  @override
  String ongoingWorkoutNextSet(int number) {
    return 'Siguiente: serie $number';
  }

  @override
  String ongoingWorkoutNextSetDetail(int number, Object detail) {
    return 'Siguiente: serie $number · $detail';
  }

  @override
  String get ongoingWorkoutAllDone => 'Todas las series completadas';

  @override
  String get lockScreenWorkout => 'Entrenamiento en la pantalla de bloqueo';

  @override
  String get lockScreenWorkoutSubtitle => 'Tiempo, siguiente serie y descanso mientras entrenas';

  @override
  String get watchApp => 'Apple Watch';

  @override
  String get watchAppSubtitle => 'Tu entrenamiento en la muñeca';

  @override
  String get watchAppIdle => 'Empieza un entrenamiento en tu iPhone';

  @override
  String get watchAppOff => 'Desactivado en Heart en tu iPhone';

  @override
  String get watchSetDone => 'Hecho';

  @override
  String get watchHeartRate => 'Frecuencia cardíaca';

  @override
  String get watchPhoneUnreachable => 'Se sincroniza con tu iPhone cuando vuelva';

  @override
  String watchSetPosition(int number, int total) {
    return 'Serie $number de $total';
  }

  @override
  String watchLastTime(String result) {
    return 'La última vez: $result';
  }

  @override
  String get watchSave => 'Guardar';

  @override
  String get watchSetNotDone => 'No hecha';

  @override
  String get watchSending => 'Enviando a tu iPhone…';

  @override
  String get watchFinishedAway => 'Guardado en tu reloj. Tu iPhone lo recibirá cuando vuelva.';

  @override
  String get watchAlwaysOnNote =>
      'Para que tu entrenamiento no se vea con la muñeca bajada, desactiva Heart en Ajustes del reloj › Pantalla y brillo › Siempre activa.';

  @override
  String get watchAppAwayNote =>
      '¿El teléfono en la taquilla? El reloj sigue registrando y tu iPhone se pone al día cuando vuelve. Puede tardar unos segundos.';

  @override
  String get watchCatchingUp => 'Sincronizando con tu reloj…';

  @override
  String watchSetsArrived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series desde tu reloj',
      one: '1 serie desde tu reloj',
    );
    return '$_temp0';
  }

  @override
  String get restTimers => 'Temporizadores de descanso';

  @override
  String get restTimersEmpty =>
      'No hay temporizadores de descanso. Configura uno desde el menú de un ejercicio durante un entrenamiento.';

  @override
  String clearRestTimerFor(String exercise) {
    return 'Quitar el temporizador de descanso de $exercise';
  }

  @override
  String get restTimerCleared => 'Temporizador de descanso quitado';

  @override
  String get undo => 'Deshacer';

  @override
  String get features => 'Funciones';

  @override
  String get featuresFooter => 'Extras que Heart solo muestra si los activas. Actívalos o desactívalos cuando quieras.';

  @override
  String get muscleMap => 'Mapa muscular';

  @override
  String get muscleMapSubtitle => 'Series por grupo muscular, en tu perfil y tus entrenamientos';

  @override
  String get muscleMapOfferTitle => '¿Ver qué músculos entrenas?';

  @override
  String get muscleMapOfferBody =>
      'Un mapa del cuerpo en tu perfil, sombreado según las series que ha recibido cada grupo muscular últimamente.';

  @override
  String get turnOn => 'Activar';

  @override
  String get noThanks => 'No, gracias';

  @override
  String get featureDeclinedNotice => 'Puedes activarlo cuando quieras en Ajustes › Funciones.';

  @override
  String get lastSevenDays => '7 días';

  @override
  String get lastThirtyDays => '30 días';

  @override
  String get muscleMapEmpty => 'No hay series en este periodo.';

  @override
  String get muscleMapFigure => 'Mapa del cuerpo con las series por grupo muscular';

  @override
  String get muscleGroupGlutes => 'Glúteos';

  @override
  String get muscleGroupHamstrings => 'Isquiotibiales';

  @override
  String get muscleGroupAdductors => 'Aductores';

  @override
  String get muscleGroupNeck => 'Cuello';

  @override
  String muscleMapUnmapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0 de ejercicios sin datos musculares sin contar';
  }

  @override
  String get muscleMapWeekly => 'Series por semana';

  @override
  String muscleMapWeeklyRow(String group, String values) {
    return '$group, series por semana, de la más antigua: $values';
  }

  @override
  String get muscleMapMonthly => 'Series por mes';

  @override
  String muscleMapMonthlyRow(String group, String values) {
    return '$group, series por mes, del más antiguo: $values';
  }

  @override
  String muscleMapMuscleSets(String group, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
      zero: 'sin series',
    );
    return '$group: $_temp0';
  }

  @override
  String muscleMapMuscleSetsFractional(String group, String sets) {
    return '$group: $sets series';
  }

  @override
  String get muscleMapBreakdown => 'Series por grupo';

  @override
  String get muscleMapOptionFigures => 'Mapa del cuerpo';

  @override
  String get muscleMapFigureHelp =>
      'Cada grupo muscular se sombrea según las series que recibió en el periodo elegido: cuanto más oscuro, más. Toca un músculo para ver su número.';

  @override
  String get muscleMapOptionWorkout => 'Cada entrenamiento';

  @override
  String get musclesWorked => 'Músculos trabajados';

  @override
  String get workoutMuscleMapHelp =>
      'Cada grupo muscular se sombrea según las series que recibió en este entrenamiento: cuanto más oscuro, más. Toca un músculo para ver su número.';

  @override
  String get muscleMapBreakdownHelp =>
      'Series completadas por grupo muscular en el periodo elegido. Una serie cuenta entera para los músculos que el ejercicio trabaja principalmente y media para los que también trabaja: una serie de press de banca suma 1 a Pecho y ½ a Brazos.';

  @override
  String get muscleMapHeatmapHelp =>
      'Series por grupo muscular a lo largo del tiempo, contadas igual que en la lista: una columna por semana, o por mes en un año, la más antigua a la izquierda. Más oscuro es más; un punto significa ninguna. Toca una fila para ver sus números.';

  @override
  String muscleMapWeekOf(String week) {
    return 'Semana del $week';
  }

  @override
  String muscleMapCellCaption(String period, String detail) {
    return '$period · $detail';
  }

  @override
  String get setTypeWarmup => 'Calentamiento';

  @override
  String get setTypeDrop => 'Serie descendente';

  @override
  String get setTypeFailure => 'Al fallo';

  @override
  String get setTypeWarmupLetter => 'C';

  @override
  String get setTypeDropLetter => 'D';

  @override
  String get setTypeFailureLetter => 'F';

  @override
  String get setTypeWarmupExplained =>
      'Una serie ligera para prepararte antes del trabajo. Los calentamientos no cuentan para tus récords, gráficas ni volumen.';

  @override
  String get setTypeDropExplained =>
      'Justo después de una serie, baja el peso y sigue con poco o ningún descanso. Cuenta como cualquier otra serie.';

  @override
  String get setTypeFailureExplained =>
      'Una serie llevada hasta no poder hacer ni una repetición limpia más. Cuenta como cualquier otra serie.';

  @override
  String get setType => 'Tipo de serie';

  @override
  String aboutSetType(String setType) {
    return 'Acerca de: $setType';
  }

  @override
  String get rpe => 'RPE';

  @override
  String get rpeSubtitle => 'Valora lo duro que fue cada serie desde su número';

  @override
  String get rpeHint => 'Cuántas repeticiones sentías que te quedaban. Toca un número para valorar la serie.';

  @override
  String get aboutRpe => 'Acerca de RPE';

  @override
  String get rpeScale10 => '10: ni una más';

  @override
  String get rpeScale9 => '9: una más';

  @override
  String get rpeScale8 => '8: dos más';

  @override
  String get rpeScale7 => '7: tres más';

  @override
  String get rpeScale6 => '6: cuatro o más';

  @override
  String rpeBadge(String value) {
    return '@$value';
  }

  @override
  String rpeValue(String value) {
    return 'RPE $value';
  }

  @override
  String get clearRpe => 'Quitar RPE';

  @override
  String get keepAwake => 'Mantener la pantalla encendida';

  @override
  String get keepAwakeSubtitle => 'La pantalla sigue encendida durante tu entrenamiento';

  @override
  String get keepAwakeBadge => 'La pantalla sigue encendida';

  @override
  String get setStopwatch => 'Cronómetro de serie';

  @override
  String get setStopwatchSubtitle => 'Cronometra una serie y detén el cronómetro para registrarla.';

  @override
  String stopwatchLogHeld(String time) {
    return 'Registrar $time';
  }

  @override
  String get timeSet => 'Cronometrar serie';

  @override
  String get showSetStopwatch => 'Mostrar cronómetro de serie';

  @override
  String get stopwatchPause => 'Pausar';

  @override
  String get stopwatchResume => 'Reanudar';

  @override
  String get stopwatchDone => 'Hecho';

  @override
  String get stopwatchPaused => 'En pausa';

  @override
  String ongoingWorkoutStopwatch(int number) {
    return 'Serie $number';
  }

  @override
  String get workoutPauses => 'Pausar entrenamientos';

  @override
  String get workoutPausesSubtitle =>
      'Detén el reloj a mitad del entrenamiento, y termina uno olvidado en su última serie';

  @override
  String get pauseWorkout => 'Pausar entrenamiento';

  @override
  String get resumePausedWorkout => 'Reanudar entrenamiento';

  @override
  String get workoutPaused => 'En pausa';

  @override
  String finishedAtTitle(String time) {
    return '¿Terminaste a las $time?';
  }

  @override
  String get finishedAtBody =>
      'Esa fue tu última serie. El entrenamiento puede terminar ahí, y el tiempo desde entonces no contará.';

  @override
  String get keepGoing => 'Seguir';

  @override
  String get watchPause => 'Pausar';

  @override
  String get watchResume => 'Reanudar';

  @override
  String get shortcuts => 'Atajos';

  @override
  String get shortcutsSubtitle =>
      'Empieza o termina un entrenamiento desde Siri, la app Atajos o tu pantalla de inicio';

  @override
  String get lockScreenDone => 'Hecho';

  @override
  String askRecord(Object exercise, Object value, Object date) {
    return 'Tu récord en $exercise es $value, conseguido el $date';
  }

  @override
  String askNoRecord(Object exercise) {
    return 'Aún no hay récord en $exercise';
  }

  @override
  String askLastExercise(Object exercise, Object date, Object workout) {
    return 'La última vez que hiciste $exercise fue el $date, en $workout';
  }

  @override
  String askNeverDid(Object exercise) {
    return 'Aún no has hecho $exercise';
  }

  @override
  String askLastTemplate(Object template, Object date) {
    return 'La última vez que hiciste $template fue el $date';
  }

  @override
  String askNeverDidTemplate(Object template) {
    return 'Aún no has hecho $template';
  }

  @override
  String askWeekly(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrenamientos esta semana',
      one: 'Un entrenamiento esta semana',
      zero: 'Aún no hay entrenamientos esta semana',
    );
    return '$_temp0';
  }

  @override
  String get askNoWorkouts => 'Aún no hay entrenamientos';

  @override
  String get askUnknownExercise => 'No conozco ese ejercicio';

  @override
  String get importUnitTitle => 'Unidades de tu exportación';

  @override
  String get importUnitBody =>
      'Strong exporta en la unidad que tenías elegida allí, y el archivo no lo dice. Elígela aquí, o 100 lb llegarían como 100 kg.';

  @override
  String get developerApi => 'API para desarrolladores';

  @override
  String get apiTokensExplainer =>
      'Tu registro de entrenamientos, legible por tus propios scripts, hojas de cálculo y asistentes de IA. Un token puede mostrar lo que registraste y no cambiar nada.';

  @override
  String get apiTokensHowTo => 'Cómo usar un token';

  @override
  String get newApiToken => 'Nuevo token';

  @override
  String apiTokensAtCapacity(Object count) {
    return 'Puedes tener $count tokens activos. Revoca uno para hacer sitio a otro.';
  }

  @override
  String get apiTokensEmpty => 'Todavía no hay ninguno.';

  @override
  String get apiTokensLoadFailed => 'La lista no llegó.';

  @override
  String get apiTokensActive => 'Activos';

  @override
  String get apiTokensPast => 'Ya no válidos';

  @override
  String apiTokenCreatedOn(Object date) {
    return 'Creado el $date';
  }

  @override
  String apiTokenExpiresOn(Object date) {
    return 'Caduca el $date';
  }

  @override
  String get apiTokenNeverExpires => 'No caduca';

  @override
  String apiTokenLastUsedOn(Object date) {
    return 'Último uso el $date';
  }

  @override
  String get apiTokenNeverUsed => 'Nunca usado';

  @override
  String apiTokenRevokedOn(Object date) {
    return 'Revocado el $date';
  }

  @override
  String apiTokenExpiredOn(Object date) {
    return 'Caducó el $date';
  }

  @override
  String apiTokenEndsWith(Object hint) {
    return 'Termina en $hint';
  }

  @override
  String get revokeApiToken => 'Revocar';

  @override
  String revokeApiTokenTitle(Object name) {
    return '¿Revocar $name?';
  }

  @override
  String get revokeApiTokenBody =>
      'Lo que lo use dejará de leer tu registro en su siguiente petición. No se puede deshacer, pero un token nuevo está a un toque.';

  @override
  String get keepApiToken => 'Conservarlo';

  @override
  String get apiTokenNameHint => 'Mi hoja, Home Assistant, Claude…';

  @override
  String get apiTokenExpiry => 'Caduca';

  @override
  String get apiTokenExpiryYear => 'En un año';

  @override
  String get apiTokenExpiryNever => 'Nunca';

  @override
  String get apiTokenPurpose => 'Lo usará';

  @override
  String get apiTokenPurposeHelp => 'Opcional. No cambia nada; te dice a ti, y a nosotros, para qué son los tokens.';

  @override
  String get apiTokenPurposeScript => 'Un script';

  @override
  String get apiTokenPurposeSpreadsheet => 'Una hoja de cálculo';

  @override
  String get apiTokenPurposeHomeAutomation => 'Domótica';

  @override
  String get apiTokenPurposeAiAssistant => 'Un asistente de IA';

  @override
  String get apiTokenPurposeOther => 'Otra cosa';

  @override
  String get apiTokenPurposeUnset => 'Prefiero no decirlo';

  @override
  String get createApiToken => 'Crear token';

  @override
  String get apiTokenReady => 'Aquí está';

  @override
  String get apiTokenRevealBody =>
      'Heart lo muestra solo esta vez. Cópialo ahora en tu herramienta; a partir de aquí solo verás sus últimos cuatro caracteres.';

  @override
  String get apiTokenSecretLabel => 'Tu nuevo token';

  @override
  String get copyApiToken => 'Copiar';

  @override
  String get apiTokenCopied => 'Copiado';

  @override
  String get apiTokenStored => 'Ya lo tengo';
}
