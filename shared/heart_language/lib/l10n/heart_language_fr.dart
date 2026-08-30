// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'heart_language.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get appearance => 'Apparence';

  @override
  String get units => 'Unités';

  @override
  String get motto => 'Chaque battement compte.';

  @override
  String get toLightMode => 'Clair';

  @override
  String get toDarkMode => 'Sombre';

  @override
  String get toSystemMode => 'Système';

  @override
  String get email => 'E-mail';

  @override
  String get yourEmail => 'Votre e-mail';

  @override
  String get cropAvatar => 'Recadrer l’avatar';

  @override
  String get nameOptional => 'Nom (facultatif)';

  @override
  String get name => 'Nom';

  @override
  String get saveName => 'Enregistrer le nom';

  @override
  String get changeName => 'Modifier le nom';

  @override
  String get save => 'Enregistrer';

  @override
  String get settings => 'Paramètres';

  @override
  String get archive => 'Archiver';

  @override
  String get unarchive => 'Désarchiver';

  @override
  String get password => 'Mot de passe';

  @override
  String get logIn => 'Se connecter';

  @override
  String get logInTitle => 'Ravi de vous revoir';

  @override
  String get logInBody => 'Vous avez déjà commencé quelque chose d’important. \nContinuons sur cette lancée.';

  @override
  String get signUpTitle => 'Commencez avec Heart';

  @override
  String get signUpBody => 'Chaque parcours commence par une décision. \nCelle-ci vous appartient.';

  @override
  String get recoverTitle => 'Toujours là pour vous';

  @override
  String get recoverBody => 'Votre parcours n’est pas perdu. \nJuste une pause — on repart ensemble.';

  @override
  String get logInWithGoogle => 'Se connecter avec Google';

  @override
  String get signUpWithGoogle => 'S’inscrire avec Google';

  @override
  String get logInWithApple => 'Se connecter avec Apple';

  @override
  String get signUpWithApple => 'S’inscrire avec Apple';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get profile => 'Profil';

  @override
  String get workout => 'Séance';

  @override
  String get history => 'Historique';

  @override
  String get exercises => 'Exercices';

  @override
  String get search => 'Rechercher';

  @override
  String get startNewWorkout => 'Commencer une nouvelle séance';

  @override
  String get cancelCurrentWorkoutTitle => 'Annuler la séance en cours ?';

  @override
  String get cancelCurrentWorkoutBody =>
      'Vous avez une séance en cours. Voulez-vous l’annuler et en commencer une nouvelle ?';

  @override
  String get startNewWorkoutFromTemplate => 'Commencer une nouvelle séance à partir de ce modèle ?';

  @override
  String get startWorkout => 'Commencer la séance';

  @override
  String get cancelWorkout => 'Annuler la séance';

  @override
  String get addExercises => 'Ajouter des exercices';

  @override
  String get addSet => 'Ajouter une série';

  @override
  String get newExercise => 'Nouvel exercice';

  @override
  String get createNewExercise => 'Créer un nouvel exercice';

  @override
  String get exerciseOptions => 'Options de l’exercice';

  @override
  String get showArchived => 'Voir les archivés';

  @override
  String get archivedExercises => 'Exercices archivés';

  @override
  String archiveConfirmTitle(Object exerciseName) {
    return 'Archiver $exerciseName ?';
  }

  @override
  String get archiveConfirmBody =>
      'Cet exercice sera déplacé vers les exercices archivés (retrouvez-le dans Exercices → Plus → Voir les archivés).\n L’archivage n’affecte aucune de vos séances passées — votre historique reste intact.';

  @override
  String get exerciseArchived => 'Cet exercice est archivé \net n’apparaîtra plus dans votre bibliothèque principale.';

  @override
  String get deleteSet => 'Supprimer la série';

  @override
  String get set => 'Série';

  @override
  String get sets => 'Séries';

  @override
  String get previous => 'Précédent';

  @override
  String get reps => 'Reps';

  @override
  String get time => 'Temps';

  @override
  String get kg => 'kg';

  @override
  String get mile => 'mile';

  @override
  String get km => 'km';

  @override
  String get milesPlural => 'miles';

  @override
  String miles(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany miles',
      one: '$howMany mile',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Modifier';

  @override
  String get delete => 'Supprimer';

  @override
  String get repeat => 'Répéter';

  @override
  String get add => 'Ajouter';

  @override
  String get share => 'Partager';

  @override
  String get okBang => 'Ok !';

  @override
  String get cancel => 'Annuler';

  @override
  String get finish => 'Terminer';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get h => 'h';

  @override
  String get min => 'min';

  @override
  String get sec => 's';

  @override
  String get lbs => 'lb';

  @override
  String get skip => 'Passer';

  @override
  String lb(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany lb',
      one: '$howMany lb',
    );
    return '$_temp0';
  }

  @override
  String get saveAsTemplate => 'Enregistrer comme modèle';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get replaceExercise => 'Remplacer l’exercice';

  @override
  String get weightUnit => 'Poids';

  @override
  String get distanceUnit => 'Distance';

  @override
  String get duration => 'Durée';

  @override
  String get imperial => 'Impérial';

  @override
  String get metric => 'Métrique';

  @override
  String get restTimer => 'Minuteur de repos';

  @override
  String get cancelTimer => 'Annuler le minuteur';

  @override
  String get removeExercise => 'Retirer l’exercice';

  @override
  String morningWorkout(String when) {
    return '$when, matin';
  }

  @override
  String eveningWorkout(String when) {
    return '$when, soir';
  }

  @override
  String nightWorkout(String when) {
    return '$when, nuit';
  }

  @override
  String afternoonWorkout(String when) {
    return '$when, après-midi';
  }

  @override
  String get emptyHistoryTitle => 'Vos séances terminées apparaîtront ici';

  @override
  String get emptyHistoryBody => 'Allez, on s’y met !';

  @override
  String get historyEndReached => 'Vous avez atteint la fin';

  @override
  String get historyLoadMoreError => 'Impossible de charger plus de séances';

  @override
  String get retry => 'Réessayer';

  @override
  String get workoutTimeoutTitle => 'Toujours en train de vous entraîner ?';

  @override
  String get workoutTimeoutBody => 'Votre séance est inactive depuis un moment — reprenez-la ou terminez-la.';

  @override
  String get notificationsDisabledReminder =>
      'Les notifications sont désactivées, vous ne recevrez donc pas les alertes du minuteur de repos.';

  @override
  String get themePresetSetting => 'Thème';

  @override
  String get themePresetSettingSubtitle => 'Des préréglages pensés pour le clair comme le sombre';

  @override
  String get themePresetForge => 'Forge';

  @override
  String get themePresetInk => 'Encre';

  @override
  String get themePresetUtility => 'Utilitaire';

  @override
  String get themePresetEmber => 'Braise';

  @override
  String get aboutApp => 'À propos de l’app';

  @override
  String get congratulations => 'Félicitations !';

  @override
  String get congratulationsBody => 'Votre séance est terminée !';

  @override
  String goalsAchievedHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Objectifs atteints',
      one: 'Objectif atteint',
    );
    return '$_temp0';
  }

  @override
  String goalAchievedTarget(String goal, String target) {
    return '$goal · $target';
  }

  @override
  String get finishWorkoutTitle => 'Terminer la séance ?';

  @override
  String get finishWorkoutWarningTitle => 'Terminer votre séance ?';

  @override
  String get finishWorkoutWarningBody =>
      'Les séries vides ou invalides seront supprimées, et toutes les séries valides seront marquées comme terminées.';

  @override
  String get finishWorkoutBody => 'On termine cette séance ?';

  @override
  String get cancelWorkoutBody => 'Tous les progrès réalisés jusqu’ici seront perdus.';

  @override
  String get cancelWorkoutTitle => 'Voulez-vous annuler cette séance ?';

  @override
  String get readyToFinish => 'Oui, j’ai terminé !';

  @override
  String get keepCurrentAccount => 'Non, garder la séance en cours';

  @override
  String get cancelAndStartNewWorkout => 'Oui, annuler celle-là et en commencer une nouvelle';

  @override
  String get resumeWorkout => 'Non, reprendre la séance';

  @override
  String get deleteThis => 'Oui, supprimer';

  @override
  String get deleted => 'Supprimé';

  @override
  String get notReadyToFinish => 'Non, encore une série !';

  @override
  String get deleteTemplateTitle => 'Voulez-vous supprimer ce modèle de séance ?';

  @override
  String get deleteTemplateBody => 'Cette action est irréversible';

  @override
  String get quitEditing => 'Quitter l’édition ?';

  @override
  String get changesWillBeLost => 'Toutes les modifications seront perdues';

  @override
  String get quitPage => 'Quitter cette page';

  @override
  String get stayHere => 'Rester ici';

  @override
  String get notificationSettings => 'Paramètres de notification';

  @override
  String selected(Object count) {
    return 'Sélection : $count';
  }

  @override
  String forExercise(String exercise) {
    return 'pour $exercise';
  }

  @override
  String get restTimerSubtitle => 'Ajustez la durée avec les boutons +/-.';

  @override
  String get addSeconds => '+10s';

  @override
  String get subtractSeconds => '-10s';

  @override
  String get restComplete => 'Repos terminé !';

  @override
  String get workoutsPerWeek => 'Séances par semaine';

  @override
  String get workoutsPerWeekTitle => 'Vos séances seront présentées ici';

  @override
  String get workoutsPerWeekBody => 'Allez, on s’y met !';

  @override
  String get goals => 'Objectifs';

  @override
  String get addGoal => 'Ajouter un objectif';

  @override
  String get noGoalsYet => 'Aucun objectif pour l’instant';

  @override
  String get workouts => 'Séances';

  @override
  String get newGoal => 'Nouvel objectif';

  @override
  String get goalTarget => 'Cible';

  @override
  String get goalPerWeek => 'par semaine';

  @override
  String get goalPerMonth => 'par mois';

  @override
  String goalDue(String date) {
    return 'Échéance $date';
  }

  @override
  String get goalComplete => 'Atteint';

  @override
  String get goalMilestone => 'Ponctuel';

  @override
  String get goalWeekly => 'Hebdomadaire';

  @override
  String get goalMonthly => 'Mensuel';

  @override
  String get goalLadder => 'Paliers';

  @override
  String get goalAddRung => 'Ajouter un palier';

  @override
  String goalAchievedOn(String date) {
    return 'Atteint le $date';
  }

  @override
  String get goalNoDeadline => 'Sans échéance';

  @override
  String get goalSetDeadline => 'Définir une échéance';

  @override
  String get goalClearDeadline => 'Supprimer l’échéance';

  @override
  String get goalsViewAchieved => 'Atteints';

  @override
  String get goalsAchievedTitle => 'Atteints';

  @override
  String get goalsViewActive => 'Retour';

  @override
  String get goalOpenWorkout => 'Voir la séance';

  @override
  String get goalWorkoutGone => 'Cette séance n’est plus sur cet appareil';

  @override
  String get goalsAtCapacity =>
      'Vous avez autant d’objectifs que Heart peut en garder. Supprimez-en un pour faire de la place.';

  @override
  String get category => 'Catégorie';

  @override
  String get target => 'Cible';

  @override
  String get removeFilter => 'Retirer le filtre';

  @override
  String restCompleteBody(Object exercise) {
    return 'Suivant : $exercise';
  }

  @override
  String weightedSetRepresentation(Object weight, Object reps) {
    return '$weight x $reps';
  }

  @override
  String get templates => 'Modèles';

  @override
  String get exampleTemplates => 'Exemples de modèles';

  @override
  String get template => 'Modèle';

  @override
  String get newTemplate => 'Nouveau modèle';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get folderName => 'Nom du dossier';

  @override
  String get renameFolder => 'Renommer le dossier';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String get deleteFolderBody => 'Les modèles qu’il contient seront conservés';

  @override
  String get moveToFolder => 'Déplacer vers un dossier';

  @override
  String get noFolder => 'Aucun dossier';

  @override
  String get folderNameTaken => 'Vous avez déjà un dossier portant ce nom';

  @override
  String get editTemplate => 'Modifier le modèle';

  @override
  String get editWorkout => 'Modifier la séance';

  @override
  String get templateName => 'Nom du modèle';

  @override
  String get workoutName => 'Nom de la séance';

  @override
  String get cannotBeEmpty => 'Ne peut pas être vide';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get yourPassword => 'Votre mot de passe';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordBody =>
      'Nous vous enverrons un lien de réinitialisation par e-mail plus vite qu’il n’en faut pour dire « mot de passe oublié ». Pas de retour en arrière après ça — sauf si vous annulez, bien sûr. 😌';

  @override
  String get orConnector => '- ou -';

  @override
  String get invalidCredentials => 'Hmm, ça n’a pas marché ! Vérifiez vos identifiants, d’accord ?';

  @override
  String get weakPassword => 'Presque ! Essayez un mot de passe plus costaud pour protéger votre compte.';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get noConnectivity => 'Oh non ! Internet a trébuché sur un haltère. 🏋️‍♂️ Réessayez dans un instant !';

  @override
  String get signUp => 'S’inscrire';

  @override
  String get sendResetLink => 'Envoyer le lien de réinitialisation';

  @override
  String get recoveryLinkMessage =>
      'Si un compte existe pour cet e-mail, vous recevrez un lien de réinitialisation sous peu. Vérifiez votre boîte de réception et vos spams.';

  @override
  String get recoveryLinkMessageSent =>
      '💌Votre e-mail de configuration du mot de passe est en route ! Vérifiez votre boîte de réception (ou vos spams — il aime bien s’y cacher).';

  @override
  String get emailExistsTitle => 'Cet e-mail existe déjà';

  @override
  String get emailExistsOkButton => 'Oui, me connecter !';

  @override
  String get emailExistsCancelButton => 'Non, je gère';

  @override
  String emailExistsBody(Object address) {
    return 'Un compte avec $address existe déjà. Voulez-vous plutôt vous connecter ?';
  }

  @override
  String get sendResetLinkBody => 'Saisissez votre e-mail et nous vous aiderons à réinitialiser votre mot de passe';

  @override
  String get userDisabled => 'Ce compte est désactivé';

  @override
  String get unknownError => 'Une erreur inconnue s’est produite';

  @override
  String get accountControl => 'Gestion du compte';

  @override
  String get leaveFeedback => 'Donner votre avis';

  @override
  String leaveFeedbackBody(Object emoji) {
    return 'Prenez une capture d’écran, gribouillez vos impressions et laissez-nous un mot. Vous pouvez continuer à naviguer dans l’app pendant ce temps.\n\nOn adore les retours. Chaque gribouillis et chaque commentaire nous aide à améliorer l’app — pour vous et pour tout le monde. Alors merci. Sincèrement. $emoji';
  }

  @override
  String get feedbackReceived => 'Votre retour a bien été reçu, merci !';

  @override
  String get toFeedback => 'C’est parti !';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountTitle => 'Voulez-vous vraiment supprimer votre compte ?';

  @override
  String deleteAccountBody(Object deadline) {
    return 'La suppression de votre compte est programmée dans $deadline jours. D’ici là, vous pouvez toujours vous connecter et revenir sur votre décision. Une fois le délai passé, votre compte et vos données personnelles seront définitivement supprimés.';
  }

  @override
  String get deleteAccountCancelMessage => 'Oh non, je me plais ici !';

  @override
  String get deleteAccountConfirmMessage => 'Oui, continuez sans moi !';

  @override
  String get confirmDeleteAccountTitle => 'Confirmez la suppression de votre compte';

  @override
  String get confirmDeleteAccountCancelMessage => 'J’ai changé d’avis, annuler';

  @override
  String get confirmDeleteAccountOkMessage => 'Adieu !';

  @override
  String get accountDeleted => 'Compte supprimé';

  @override
  String accountDeletedBody(Object date) {
    return 'La suppression de votre compte est programmée pour le $date.\n\nSi vous changez d’avis, vous pouvez restaurer votre compte à tout moment avant cette date.\n\nAppuyez simplement sur le bouton ci-dessous pour annuler la suppression et garder votre compte.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Annuler les adieux 🥇🔥';

  @override
  String get movement => 'Mouvement';

  @override
  String get pattern => 'Schéma';

  @override
  String get stability => 'Stabilité';

  @override
  String get skillAtMost => 'Technicité max';

  @override
  String get patternHelp =>
      'Le mouvement lui-même — plus large que le matériel, plus fin que le groupe musculaire. Les exercices qui partagent un schéma peuvent se remplacer l’un l’autre.';

  @override
  String get stabilityHelp =>
      'À quel point le matériel guide la trajectoire à votre place. Libre : vous équilibrez la charge vous-même ; machine : la trajectoire est fixe.';

  @override
  String get skillAtMostHelp =>
      'Le niveau de technique qu’un exercice exige avant de pouvoir être chargé en toute sécurité. Choisir Modéré inclut aussi Faible.';

  @override
  String get clearFilters => 'Effacer';

  @override
  String get alsoTry => 'À essayer aussi';

  @override
  String get about => 'Description';

  @override
  String get records => 'Records';

  @override
  String get chartWeeklyAverage => 'Moyenne hebdomadaire';

  @override
  String get chartMonthlyAverage => 'Moyenne mensuelle';

  @override
  String get chartYearlyAverage => 'Moyenne annuelle';

  @override
  String get chartRangeMonth => '1M';

  @override
  String get chartRangeQuarter => '3M';

  @override
  String get chartRangeYear => '1A';

  @override
  String get chartRangeAll => 'Tout';

  @override
  String get chartGenericLabel => 'Graphique';

  @override
  String exerciseChartSummary(Object metric, Object start, Object end, Object latest, Object trend) {
    return '$metric du $start au $end. Dernière valeur : $latest. Tendance : $trend.';
  }

  @override
  String get exerciseChartTrendUp => 'En hausse';

  @override
  String get exerciseChartTrendDown => 'En baisse';

  @override
  String get exerciseChartTrendFlat => 'Stable';

  @override
  String healthCardSummary(String metric, String value, String when) {
    return '$metric, $value, $when';
  }

  @override
  String get charts => 'Graphiques';

  @override
  String get emptyExerciseHistoryTitle => 'Reps fantômes détectées 👻';

  @override
  String get emptyExerciseHistoryBody =>
      'Votre historique d’exercices est plus vide qu’une salle de sport un lundi matin. Il est temps de le remplir avec de glorieux records !';

  @override
  String get errorExerciseHistoryTitle => 'Oups ! Quelqu’un a séché le jour des données 🤷‍♀️';

  @override
  String get errorExerciseHistoryBody =>
      'On dirait que l’app s’est pris les pieds dans ses lacets. Réessayez, promis, on les serrera mieux la prochaine fois !';

  @override
  String get personalRecords => 'Records personnels';

  @override
  String get maxDuration => 'Durée max';

  @override
  String get maxDistance => 'Distance max';

  @override
  String get maxWeight => 'Charge max';

  @override
  String get maxReps => 'Reps max';

  @override
  String get capturePhoto => 'Prendre une nouvelle photo';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get removeCurrentPhoto => 'Supprimer la photo actuelle';

  @override
  String get mine => 'Les miens';

  @override
  String get goToWorkout => 'Aller à la séance';

  @override
  String get setTimer => 'Régler le minuteur';

  @override
  String get updateRequiredTitle => 'Oups. C’est de notre faute';

  @override
  String get updateRequiredBody =>
      'Une mise à jour importante vous attend — elle garantit le bon fonctionnement de votre app.\n\nVous devrez l’installer avant de continuer.\nMerci de votre patience — et désolé pour l’interruption.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Mettre à jour sur $storeName';
  }

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get editWorkoutName => 'Modifier le nom de la séance';

  @override
  String get editWorkoutTimes => 'Modifier les horaires';

  @override
  String get adjustTimes => 'Ajuster les heures de début/fin';

  @override
  String get startTime => 'Heure de début';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get endBeforeStart => 'L’heure de fin ne peut pas précéder l’heure de début.';

  @override
  String get cropImage => 'Recadrer l’image';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get aboutExercise => 'À propos de l’exercice';

  @override
  String get myDashboard => 'Mon tableau de bord';

  @override
  String get newChart => 'Nouveau graphique';

  @override
  String get emptyChartStateTitle => 'C’est un peu vide par ici';

  @override
  String get emptyChartStateBody => 'Ajoutez votre première série pour commencer à suivre vos vrais progrès';

  @override
  String get topSetWeight => 'Charge de la meilleure série';

  @override
  String get estimatedOneRepMax => '1RM estimé';

  @override
  String get totalVolume => 'Volume total';

  @override
  String get averageWorkingWeight => 'Charge moyenne de travail';

  @override
  String get assistanceWeight => 'Charge d’assistance';

  @override
  String get maxRepsInSet => 'Reps max sur une série';

  @override
  String get totalReps => 'Total de reps';

  @override
  String get cardioDistance => 'Distance';

  @override
  String get cardioDuration => 'Durée';

  @override
  String get averagePace => 'Allure moyenne';

  @override
  String get totalTimeUnderTension => 'Temps sous tension total';

  @override
  String get passwordPolicyTitle => 'Créons un mot de passe qui soulève lourd :';

  @override
  String passwordPolicyMinLength(int minLength) {
    return 'au moins $minLength caractères';
  }

  @override
  String passwordPolicyMaxLength(int maxLength) {
    return 'pas plus de $maxLength (on croit aux limites)';
  }

  @override
  String get passwordPolicyUpperCase => 'une lettre majuscule';

  @override
  String get passwordPolicyLowerCase => 'une lettre minuscule';

  @override
  String get passwordPolicyDigit => 'un chiffre quelque part là-dedans';

  @override
  String get deleteImageDialogTitle => 'Supprimer cette image ?';

  @override
  String get deleteImageDialogBody => 'La séance ne sera pas affectée — seule l’image sera effacée';

  @override
  String get myProgression => 'Ma progression';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get weightUnitLabel => 'Unité de poids';

  @override
  String get distanceUnitLabel => 'Unité de distance';

  @override
  String get close => 'Fermer';

  @override
  String get noWorkoutSelectedTitle => 'Aucune sélection';

  @override
  String get noWorkoutSelectedBody => 'Choisissez une séance pour voir ce que vous avez fait et la modifier.';

  @override
  String get noExerciseSelectedTitle => 'Aucune sélection';

  @override
  String get noExerciseSelectedBody =>
      'Choisissez un exercice pour voir comment le faire, ainsi que votre historique et vos records.';

  @override
  String get moreOptions => 'Plus d’options';

  @override
  String get viewProgressPhotos => 'Voir les photos de progression';

  @override
  String get confirmEdit => 'Confirmer';

  @override
  String get clearSearchTooltip => 'Effacer la recherche';

  @override
  String get changeProfilePhoto => 'Changer la photo de profil';

  @override
  String get viewAccountDetails => 'Détails du compte';

  @override
  String get viewProfilePhoto => 'Voir la photo de profil';

  @override
  String durationPickerSetTo(Object duration) {
    return 'Régler le minuteur de repos sur $duration';
  }

  @override
  String get emptyWorkoutLabel => 'Séance vide';

  @override
  String progressPhotoLabel(Object date) {
    return 'Photo de progression du $date';
  }

  @override
  String exerciseThumbnailLabel(Object exerciseName) {
    return 'Vignette de $exerciseName';
  }

  @override
  String goalLadderSummary(Object achieved, Object total, Object current) {
    return '$achieved cibles atteintes sur $total. En cours : $current.';
  }

  @override
  String restTimerRemaining(Object remaining) {
    return 'Minuteur de repos : il reste $remaining';
  }

  @override
  String get health => 'Santé';

  @override
  String get healthActiveEnergy => 'Énergie active';

  @override
  String get healthBodyMass => 'Poids corporel';

  @override
  String get healthBpm => 'bpm';

  @override
  String get healthChecking => 'Recherche de nouvelles mesures…';

  @override
  String healthLatestReading(String when) {
    return 'Dernière mesure · $when';
  }

  @override
  String get healthDelete => 'Supprimer les données de santé';

  @override
  String get healthDeleteBody =>
      'Cela efface ce que Heart a lu sur cet appareil. Rien ne change dans les données de santé de votre téléphone, et Heart les relira à la prochaine synchronisation.';

  @override
  String get healthDeleteTitle => 'Supprimer la copie que Heart garde de vos données de santé ?';

  @override
  String get healthHeartRateVariability => 'Variabilité de la fréquence cardiaque';

  @override
  String get healthHoursShort => 'h';

  @override
  String get healthInviteAction => 'Afficher mes données de santé';

  @override
  String get healthInviteBody =>
      'Heart peut afficher votre fréquence cardiaque au repos, votre sommeil, vos pas et votre poids à côté de vos séances. Il les lit depuis les données de santé de votre téléphone et les garde sur cet appareil.';

  @override
  String get healthInviteDismiss => 'Pas maintenant';

  @override
  String get healthInviteTitle => 'Données de santé';

  @override
  String get healthKilocalories => 'kcal';

  @override
  String get healthMilliseconds => 'ms';

  @override
  String get healthMinutesShort => 'min';

  @override
  String get healthOffInHealthApp =>
      'Dans l’app Santé, touchez votre photo de profil, puis Apps, et autorisez la lecture pour Heart.';

  @override
  String get healthOffInSettings =>
      'Autorisez Heart à lire vos données de santé dans les réglages santé de votre appareil. Autorisez aussi les données antérieures, sinon les graphiques s’arrêtent aux 30 derniers jours.';

  @override
  String get healthOffTitle => 'Heart ne lit aucune donnée de santé';

  @override
  String get healthOnThisDevice => 'Sur cet appareil';

  @override
  String get healthOpenHealthApp => 'Ouvrir l’app Santé';

  @override
  String get healthOpenHealthAppHint => 'Touchez votre photo de profil, puis Apps';

  @override
  String get healthOpenSettingsHint => 'Autorisez aussi l’accès aux données antérieures';

  @override
  String get healthOpenSettings => 'Ouvrir les paramètres';

  @override
  String get healthRestingHeartRate => 'Fréquence cardiaque au repos';

  @override
  String get healthSettingsBody =>
      'Heart lit la fréquence cardiaque au repos, la variabilité de la fréquence cardiaque, le sommeil, les pas, l’énergie active et le poids depuis les données de santé de votre téléphone. Ces données restent sur cet appareil.';

  @override
  String get healthWriteWorkouts => 'Enregistrer les séances dans Santé';

  @override
  String get healthWriteWorkoutsOn => 'Enregistre la durée de vos entraînements, et rien d’autre';

  @override
  String get healthWriteWorkoutsOff => 'Désactivé · Heart n’enregistre pas vos séances';

  @override
  String get healthSleep => 'Sommeil';

  @override
  String get healthSteps => 'Pas';

  @override
  String get deleteWorkoutTitle => 'Voulez-vous supprimer cette séance ?';

  @override
  String get deleteWorkoutBody => 'Cette action est irréversible';

  @override
  String get importData => 'Importer l’historique de séances';

  @override
  String get importPreviewTitle => 'Prêt à importer';

  @override
  String importPreviewSummary(num workouts, num sets) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts séances',
      one: '1 séance',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets séries',
      one: '1 série',
    );
    return '$_temp0 et $_temp1 prêtes à être importées';
  }

  @override
  String importPreviewSummaryPartial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances sont nouvelles',
      one: '1 séance est nouvelle',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNothingNew(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les $count séances de ce fichier sont',
      one: 'l’unique séance de ce fichier est',
    );
    return 'Rien de nouveau — $_temp0 déjà là';
  }

  @override
  String importPreviewMatched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercices correspondent déjà à la bibliothèque',
      one: '1 exercice correspond déjà à la bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String importPreviewAlreadyHere(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances sont déjà là — elles seront ignorées',
      one: '1 séance est déjà là — elle sera ignorée',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get importConsentTitle => 'Nouveaux exercices trouvés';

  @override
  String get importConsentBody =>
      'Ceux-ci ne correspondent à rien dans la bibliothèque. Cochez ceux à importer comme vos propres exercices personnalisés — tout ce qui n’est pas coché reste de côté, avec ses séries.';

  @override
  String get importAction => 'Importer';

  @override
  String importSetsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0';
  }

  @override
  String importSkippedSets(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries sont restées de côté',
      one: '1 série est restée de côté',
    );
    return '$_temp0 avec les exercices que vous avez refusés';
  }

  @override
  String get yourData => 'Vos données';

  @override
  String get account => 'Compte';

  @override
  String get app => 'Application';

  @override
  String get importExplainerStrong =>
      'Vous souleviez avec Strong ? Emportez votre historique avec vous.\n\nDans l’app Strong, allez dans Profile → Settings → Export Strong Data. Vous recevrez un fichier CSV par e-mail — enregistrez-le, puis choisissez-le ici.';

  @override
  String get importSafeToRetry =>
      'Tout est transféré — séances, séries, exercices. Importer deux fois le même fichier est sans risque : ce qui est déjà là est ignoré, jamais dupliqué.';

  @override
  String get chooseFile => 'Choisir un fichier';

  @override
  String get csvFiles => 'Fichiers CSV';

  @override
  String get importInFlight => 'Importation en cours — un instant…';

  @override
  String get importFailedHeadline => 'Ce fichier n’a pas fonctionné';

  @override
  String get importFailedBody =>
      'Impossible de le lire comme un export Strong. Choisissez le fichier CSV de l’e-mail d’export de Strong et réessayez.';

  @override
  String get importReportTitle => 'Importé !';

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances importées',
      one: '1 séance importée',
      zero: 'Aucune nouvelle séance',
    );
    return '$_temp0';
  }

  @override
  String importSkippedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances étaient déjà là — ignorées',
      one: '1 séance était déjà là — ignorée',
    );
    return '$_temp0';
  }

  @override
  String importedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0 au total';
  }

  @override
  String importSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes n’ont pas pu être lues',
      one: '1 ligne n’a pas pu être lue',
    );
    return '$_temp0';
  }

  @override
  String get importNewExercisesHeader => 'Nouveaux exercices personnalisés';

  @override
  String get importNewExercisesBody =>
      'Ceux-ci ne correspondaient à rien dans la bibliothèque, ils ont donc été importés comme vos exercices personnalisés :';

  @override
  String get machineTranslatedCopy => 'Traduction automatique';

  @override
  String get categoryWeightedBodyWeight => 'Poids du corps lesté';

  @override
  String get categoryAssistedBodyWeight => 'Poids du corps assisté';

  @override
  String get categoryRepsOnly => 'Répétitions seules';

  @override
  String get categoryCardio => 'Cardio';

  @override
  String get categoryDuration => 'Durée';

  @override
  String get categoryMachine => 'Machine';

  @override
  String get categoryDumbbell => 'Haltères';

  @override
  String get categoryBarbell => 'Barre';

  @override
  String get targetCore => 'Core';

  @override
  String get targetArms => 'Bras';

  @override
  String get targetBack => 'Dos';

  @override
  String get targetChest => 'Pectoraux';

  @override
  String get targetLegs => 'Jambes';

  @override
  String get targetShoulders => 'Épaules';

  @override
  String get targetOther => 'Autre';

  @override
  String get targetOlympic => 'Olympique';

  @override
  String get targetFullBody => 'Corps entier';

  @override
  String get targetCardio => 'Cardio';

  @override
  String get skillLow => 'Faible';

  @override
  String get skillModerate => 'Modéré';

  @override
  String get skillHigh => 'Élevé';

  @override
  String get stabilityFree => 'Charge libre';

  @override
  String get stabilitySupported => 'Avec appui';

  @override
  String get stabilityMachine => 'Machine';

  @override
  String get patternCalfRaise => 'Extension des mollets';

  @override
  String get patternCardioSteady => 'Cardio continu';

  @override
  String get patternChestDip => 'Dips';

  @override
  String get patternChestFly => 'Écartés';

  @override
  String get patternCoreBracing => 'Gainage';

  @override
  String get patternDeadliftFloor => 'Soulevé de terre au sol';

  @override
  String get patternDeclinePress => 'Développé décliné';

  @override
  String get patternElbowExtension => 'Extension du coude';

  @override
  String get patternElbowFlexion => 'Flexion du coude';

  @override
  String get patternForearm => 'Avant-bras';

  @override
  String get patternFrontRaise => 'Élévation frontale';

  @override
  String get patternFullBodyConditioning => 'Conditionnement complet';

  @override
  String get patternGluteIsolation => 'Isolation des fessiers';

  @override
  String get patternHipAbduction => 'Abduction de hanche';

  @override
  String get patternHipAdduction => 'Adduction de hanche';

  @override
  String get patternHipExtensionBridge => 'Pont fessier';

  @override
  String get patternHipFlexionHanging => 'Relevé de jambes suspendu';

  @override
  String get patternHipHingeStifflegged => 'Soulevé jambes tendues';

  @override
  String get patternHorizontalPress => 'Développé horizontal';

  @override
  String get patternHorizontalRow => 'Rowing horizontal';

  @override
  String get patternInclinePress => 'Développé incliné';

  @override
  String get patternKneeExtension => 'Extension du genou';

  @override
  String get patternKneeFlexion => 'Flexion du genou';

  @override
  String get patternLateralRaise => 'Élévation latérale';

  @override
  String get patternLungeSplit => 'Fentes';

  @override
  String get patternMobility => 'Mobilité';

  @override
  String get patternOlympicLift => 'Mouvement olympique';

  @override
  String get patternPlyometricLower => 'Pliométrie bas du corps';

  @override
  String get patternPullover => 'Pull-over';

  @override
  String get patternRearDelt => 'Deltoïde postérieur';

  @override
  String get patternShrug => 'Shrugs';

  @override
  String get patternSpinalExtension => 'Extension lombaire';

  @override
  String get patternSquatBilateral => 'Squat';

  @override
  String get patternTrunkFlexion => 'Flexion du tronc';

  @override
  String get patternTrunkLateralRotation => 'Rotation du tronc';

  @override
  String get patternUprightRow => 'Rowing menton';

  @override
  String get patternVerticalPress => 'Développé vertical';

  @override
  String get patternVerticalPull => 'Tirage vertical';
}
