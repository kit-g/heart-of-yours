# English copy: findings log (#439)

Every English string was read: the 1,714 rows of `shared/heart_language/scripts/translations.csv`
(the 1,611 app strings and the 103 native ones: permission sentences, Siri and assistant phrases,
widget and shortcut labels) and the 82 notes in `assets/whats_new/en.json`. 87 strings changed (86 in the app, 1 native),
and six sentences in What's new. A string that reads as a person wrote it has no row here.

Each row gives the key, the string before and after, the kind of artifact and the reason. `<br>` is a
line break inside the string. Rows marked **meaning** changed what the string says, so that row was
re-translated in Spanish, French and Russian in the same change (9 rows); every other row changed
wording only and its translations are untouched.

## Inconsistent terms (28)

| Key | Before | After | Reason |
|---|---|---|---|
| `finishWorkoutWarningTitle` | Complete Your Workout? | Finish your workout? | The button says Finish; "Complete" named the same act a second way, in Title Case. |
| `emailExistsOkButton` | Yes, sign me in! | Yes, log me in! | The app's verb is "log in"; "sign in" named the same act a second way. |
| `accountUnderOtherProvider` | This email already has a Heart account under a different sign-in. Sign in that way once, and this one is connected to it. | This email already has a Heart account under a different sign-in. Log in that way once, and this one is connected to it. | The verb is "log in" everywhere else. "Sign-in" stays as the noun for a way of logging in. |
| `goalOpenWorkout` | View the session | Open the workout | It opens a logged workout. "Session" is the word for a program's planned day. |
| `goalWorkoutGone` | That session is no longer on this device | That workout is no longer on this device | A logged workout, called a session. |
| `goalLadderSummary` | {achieved} of {total} targets reached. Current: {current}. | {achieved} of {total} milestones reached. Current: {current}. | The ladder's steps are "milestones" on screen; the screen reader called them "targets". |
| `goalAchievedOn` | Achieved {date} | Reached {date} | A goal is "reached" everywhere else ("Goal reached", "Reached"); "achieved" was a second word for it. |
| `goalsViewAchieved` | Achieved | Reached | As above: one word for a goal that was met. |
| `goalsAchievedTitle` | Achieved | Goals reached | As above, and it now matches the Done page's heading. |
| `deleteImageDialogTitle` | Remove this image? | Remove this photo? | Photo, image and picture all named the same thing; the app's word is photo ("Add photo", "Remove photo"). |
| `deleteImageDialogBody` | It won't affect the workout — just clears the picture | The workout stays as it is. Only the photo goes. | "Picture" for the photo, and "just clears" hedged what the button does. |
| `cropImage` | Crop image | Crop photo | Image for photo. |
| `cropAvatar` | Crop avatar | Crop profile photo | "Avatar" appears nowhere else; the same thing is "profile photo" on the button that opens this. |
| `importConsentBody` | These didn't match anything in the library. Check the ones to bring over as your own custom exercises — anything unchecked stays behind, along with its sets. | These didn't match anything in the library. Tick the ones to bring over as custom exercises — anything unticked stays behind, along with its sets. | "Check" and "unchecked" where the app ticks and unticks; "your own custom" said the same thing twice. |
| `notificationsOffEnable` | Enable | Turn on | The sentence above it says notifications are "off"; the app turns things on, it does not "enable" them. |
| `deleteTemplateBody` | This cannot be undone | This can't be undone | "Cannot" beside the app's usual "can't be undone". |
| `deleteWorkoutBody` | This cannot be undone | This can't be undone | "Cannot" beside the app's usual "can't be undone". |
| `eraseDataBody` | Your workouts, templates, custom exercises, goals and chart settings are deleted from this device, together with Heart's copy of your health data. The records in your health app are not touched. Without an account there is no backup — this cannot be undone. | Your workouts, templates, custom exercises, goals and chart settings are deleted from this device, together with Heart's copy of your health data. The records in your health app are not touched. Without an account there is no backup — this can't be undone. | "Cannot" beside the app's usual "can't be undone". |
| `exerciseNoteSaveFailed` | Could not save the note. Please try again. | Couldn't save the note. Try again. | Every other failure reads "Couldn't … Try again."; this one said "Could not … Please try again." |
| `upsyncSkipped` | {skipped, plural, =1{1 item could not be uploaded.} other{{skipped} items could not be uploaded.}} | {skipped, plural, =1{1 item couldn't be uploaded.} other{{skipped} items couldn't be uploaded.}} | "Could not" beside the app's usual "couldn't". |
| `noAccountBodyLose` **meaning** | If you lose this phone, you lose your data. | If you lose this device, you lose your data. | "this phone" where the app runs on tablets too, and says "this device" everywhere else. Meaning changed: re-translated. |
| `exportExplainer` **meaning** | Everything Heart keeps on this phone, in a file that is yours to keep: workouts with every set, templates and folders, custom exercises, unit settings and goals. | Everything Heart keeps on this device, in a file that is yours to keep: workouts with every set, templates and folders, custom exercises, unit settings and goals. | "this phone" where the app runs on tablets too, and says "this device" everywhere else. Meaning changed: re-translated. |
| `importExplainerHeart` **meaning** | From another account or another phone? Bring your Heart history along.<br><br>In Heart, go to Settings → Export my data and save either file, then pick it here. The JSON brings everything back: workouts, templates and folders, custom exercises and goals. The CSV brings workouts and their sets only. | From another account or another device? Bring your Heart history along.<br><br>In Heart, go to Settings → Export my data and save either file, then pick it here. The JSON brings everything back: workouts, templates and folders, custom exercises and goals. The CSV brings workouts and their sets only. | "Another phone" where the app runs on tablets too, and says "this device" everywhere else. Meaning changed: re-translated. |
| `importExplainerHeartJson` **meaning** | Bring back what you exported from Heart, on this phone or another.<br><br>In Heart, go to Settings → Export my data → Export as JSON. Save the file, then pick it here. Everything in it comes back: workouts, templates and folders, custom exercises and goals. | Bring back what you exported from Heart, on this device or another.<br><br>In Heart, go to Settings → Export my data → Export as JSON. Save the file, then pick it here. Everything in it comes back: workouts, templates and folders, custom exercises and goals. | "this phone" where the app runs on tablets too, and says "this device" everywhere else. Meaning changed: re-translated. |
| `programCalendarNone` **meaning** | There's no calendar on this phone Heart can add to. | There's no calendar on this device Heart can add to. | "this phone" where the app runs on tablets too, and says "this device" everywhere else. Meaning changed: re-translated. |
| `invitationMakeAccount` | Make an account | Sign up | Making an account is "Sign up" on every other button, including the form this one opens. |
| `invitationNeedsAccount` | Coaching needs an account. Make one, and your workouts come with you. | Coaching needs an account. Sign up, and your workouts come with you. | As above: "Make one" for "Sign up". |
| `programCalendarGoogleHint` **meaning** | Using Google Calendar? Add your Google account to this iPhone (Settings › Apps › Calendar › Calendar Accounts) and turn on Calendars; its calendars then appear here. | Using Google Calendar? Add your Google account to this device (Settings › Apps › Calendar › Calendar Accounts) and turn on Calendars; its calendars then appear here. | "This iPhone" on a hint an iPad shows too. Meaning changed: re-translated. |

## Typography (25)

| Key | Before | After | Reason |
|---|---|---|---|
| `logInBody` | You've already started something important. <br>Let's keep going. | You've already started something important.<br>Let's keep going. | A stray space sat before the line break. |
| `signUpBody` | Every journey starts with one decision. <br>This one's yours. | Every journey starts with one decision.<br>This one's yours. | A stray space sat before the line break. |
| `recoverBody` | Your journey isn't lost. <br>Just a moment of pause — we'll reset together. | Your journey isn't lost.<br>Just a moment of pause — we'll reset together. | A stray space sat before the line break. |
| `exerciseArchived` | This exercise is archived <br>and won't appear in your main library anymore. | This exercise is archived<br>and won't appear in your main library anymore. | A stray space sat before the line break. |
| `logInTitle` | Welcome Back | Welcome back | Title Case where the rest of the app uses sentence case. |
| `recoverTitle` | Still with You | Still with you | Title Case where the rest of the app uses sentence case. |
| `finishWorkoutTitle` | Finish Workout? | Finish workout? | Title Case where the rest of the app uses sentence case. |
| `newTemplate` | New Template | New template | Title Case; its neighbours read "New folder", "New goal". |
| `editTemplate` | Edit Template | Edit template | Title Case where the rest of the app uses sentence case. |
| `editWorkout` | Edit Workout | Edit workout | Title Case where the rest of the app uses sentence case. |
| `sendResetLink` | Send Reset Link | Send reset link | Title Case where the rest of the app uses sentence case. |
| `adjustTimes` | Adjust Start/End Time | Edit start and end times | Title Case, a slash standing in for "and", and "Adjust" for what its menu item calls "Edit times". |
| `myDashboard` | My Dashboard | My dashboard | Title Case where the rest of the app uses sentence case. |
| `goToWorkout` | Go to Workout | Go to workout | A capital on a common noun mid-phrase. |
| `logWorkout` | Log Workout | Log workout | Title Case where the rest of the app uses sentence case. |
| `okBang` | Ok! | OK! | "Ok" beside the app's own "OK". |
| `subtractSeconds` | -10s | −10s | A hyphen standing in for a minus sign; the app uses − elsewhere. |
| `recoveryLinkMessageSent` | 💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide). | 💌 Your password setup email is on its way! Check your inbox (or maybe your spam folder — it likes to hide). | No space after the emoji, and an unspaced dash where the app spaces them. |
| `resetPasswordBody` | We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌 | We'll send a reset link to your email faster than you can say “forgot my password.” No turning back after this — unless you cancel, of course. 😌 | An unspaced dash and a curly apostrophe, where the app spaces its dashes and uses straight apostrophes. The joke is left alone. |
| `leaveFeedbackBody` | Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you're at it.<br><br>We love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. {emoji} | Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you're at it.<br><br>We love feedback. Every squiggle and comment helps us make the app better — for you and everyone else. So thanks. Seriously. {emoji} | An unspaced dash where the app spaces them. |
| `exercisesTabSubtitle` | The exercise library as a tab of its own. Without it, you still pick and create exercises in a workout | The exercise library as a tab of its own. Without it, you still pick and create exercises in a workout. | Two sentences, the second without its full stop. |
| `updateRequiredTitle` | Oops. That one’s on us | Oops. That one's on us | A curly apostrophe where the app uses straight ones. |
| `updateRequiredBody` | There’s an important update waiting — one that keeps your app working as it should.<br><br>You’ll need to install it before continuing.<br>Thanks for your patience — and sorry for the interruption. | There's an important update waiting — one that keeps your app working as it should.<br><br>You'll need to install it before continuing.<br>Thanks for your patience — and sorry for the interruption. | Curly apostrophes where the app uses straight ones. |
| `healthOffInSettings` | Let Heart read your health data in your device’s health settings. Allow past data too, or charts stop at the last 30 days. | Let Heart read your health data in your device's health settings. Allow past data too, or charts stop at the last 30 days. | A curly apostrophe where the app uses straight ones. |
| `healthOffTitle` | Heart isn’t reading any health data | Heart isn't reading any health data | A curly apostrophe where the app uses straight ones. |

## Register (12)

| Key | Before | After | Reason |
|---|---|---|---|
| `deleteAccountBody` | Your account is scheduled for deletion in {deadline, plural, =1{1 day} other{{deadline} days}}. During this time, you can still sign in and reverse this decision. Once the deadline has passed, your account and personal data will be permanently deleted. | Your account will be deleted in {deadline, plural, =1{1 day} other{{deadline} days}}. Until then you can still log in and change your mind. After that, your account and personal data are deleted for good. | "Scheduled for deletion", "During this time", "Once the deadline has passed": office language for a plain fact. Also "sign in" for "log in". |
| `accountDeletedBody` | Your account has been scheduled for deletion on {date}.<br><br>If you change your mind, you can restore your account anytime before this date.<br><br>Simply click the button below to cancel the deletion and keep your account safe. | Your account will be deleted on {date}.<br><br>If you change your mind, you can restore it any time before then.<br><br>Tap the button below to cancel the deletion and keep your account. | "Has been scheduled for deletion", "Simply click" on a touch screen, "keep your account safe": bureaucratic, then padded. |
| `confirmDeleteAccountTitle` | Confirm your account deletion | Confirm you want to delete your account | "Your account deletion" is a noun pile; a person says what they are confirming. |
| `cannotBeEmpty` | Cannot be empty | Can't be empty | "Cannot" is stiffer than anything around it. |
| `cancelWorkoutBody` | All progress made so far will be lost. | Everything you've logged so far will be lost. | "All progress made so far": a passive with nobody in it. |
| `workoutsPerWeekTitle` | Your workouts will be presented here | Your workouts will show up here | "Will be presented" is a slide deck's verb. |
| `restTimerSubtitle` | Adjust duration via the +/- buttons. | Adjust the time with the +10s and −10s buttons. | "Via" and an article-less "duration"; the buttons are now called what they say. |
| `feedbackReceived` | Your feedback was received, thank you! | Got your feedback, thank you! | "Was received" is a passive receipt. |
| `rpeSubtitle` | Rate how hard each set was, from its number | Tap a set's number to rate how hard it was | "From its number" leaves out the tap that the sentence is about. |
| `rpeImportOfferBody` | Show it in Heart? Each set's rating appears beside it, and you can rate new sets from their number. | Show it in Heart? Each set's rating appears beside it, and you can rate new sets by tapping their number. | "From their number", as above. |
| `androidFunctionAppClosed` | Heart is not running; it will apply this when opened | Heart isn't running. It will apply this when you open it. | A semicolon and a subjectless passive in a sentence the assistant speaks aloud. |
| `accountDeleted` **meaning** | Account deleted | Your account will be deleted | The page says the account is deleted, then gives the date it will be and a button to keep it. Asked by the French, Spanish and Russian logs. Meaning changed: re-translated. |

## Over-explained or hedged (10)

| Key | Before | After | Reason |
|---|---|---|---|
| `emailExistsTitle` | Email already exists | This email already has an account | The email does not "exist"; an account for it does. |
| `cancelWorkoutTitle` | Do you want to cancel this workout? | Cancel this workout? | "Do you want to" pads a question the title already asks; newer dialogs read "Delete this note?". |
| `deleteTemplateTitle` | Do you want to delete this workout template? | Delete this template? | "Do you want to" padding, and "workout template" for what is "template" everywhere else. |
| `deleteWorkoutTitle` | Do you want to delete this workout? | Delete this workout? | "Do you want to" padding. |
| `archiveConfirmBody` | This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).<br> Archiving won't affect any of your past workouts — your history stays intact. | It moves to Archived exercises (Exercises → More → Show archived).<br>Your past workouts aren't affected. | It said the same thing twice ("won't affect… stays intact"), capitalised a label the app writes in sentence case, and had a stray space after the line break. |
| `emptyChartStateBody` | Add your first set to start tracking real progress | Add your first set to start tracking your progress | "Real progress" implied some other kind. |
| `replaceScopeBody` | {to} is in this workout now. It can also take {from}'s place in every session of the program, and the way it grows with it. | {to} is in this workout now. It can also take {from}'s place in every session of the program, and grow the way {from} did. | "And the way it grows with it": two pronouns and no clear owner for either. |
| `patternHelp` | The movement itself — coarser than equipment, finer than body part. Exercises that share a pattern can stand in for one another. | The kind of movement, like a squat or a press: finer than a body part, and whatever the equipment. Exercises that share a pattern can stand in for one another. | It defined a pattern only by what it sits between ("coarser than equipment, finer than body part") and never said what one is. The French, Spanish and Russian logs asked for this. |
| `healthWriteWorkoutsOn` **meaning** | Saving how long you train, and nothing else | Saving how long you train and what kind of workout it was, nothing else | "And nothing else" was not true: the permission sentence and the release note both say the kind of workout is saved too. No health behaviour changes. Asked by all three sibling logs. Meaning changed: re-translated. |
| `programCalendarSetupNote` **meaning** | Each session lands on your training days, with a link that starts it. Every event is called just “{title}”, so a shared calendar shows nothing more. | Each session lands on your training days, with a link that starts it. Every event is titled just “{title}”; the session and its exercises are in its notes, for those you share details with. | "So a shared calendar shows nothing more" promised more than the app does: the title is neutral, but the event's notes name the program, the session and its exercises. Asked by the French and Spanish logs. Meaning changed: re-translated. |

## Grammar (6)

| Key | Before | After | Reason |
|---|---|---|---|
| `sendResetLinkBody` | Enter you email and we'll help you reset your password | Enter your email and we'll help you reset your password | "Enter you email": a typo. |
| `setTypeWarmup` | Warm up | Warm-up | "Warm up" is the verb; the set type is the noun, as in "Warm-up sets". |
| `aboutApp` | About app | About the app | A missing article. |
| `aboutExercise` | About exercise | About this exercise | A missing article. |
| `unpinExerciseNote` | Unpin for future workouts | Unpin from future workouts | You pin a note for future workouts and unpin it from them. |
| `muscleMapUnmapped` | {count, plural, one{1 set} other{{count} sets}} from exercises without muscle data not counted | {count, plural, one{1 set from an exercise without muscle data isn't counted.} other{{count} sets from exercises without muscle data aren't counted.}} | "… not counted" had no verb, "1 set from exercises" did not agree, and the sentence had no full stop. |

## Stock phrase (4)

| Key | Before | After | Reason |
|---|---|---|---|
| `unknownError` | Unknown error occurred | Something went wrong | "Unknown error occurred": an error-log phrase, missing its article. |
| `quitPage` | Quit this page | Leave this page | You quit an app and leave a page. |
| `accountControl` | Account control | Manage account | "Account control" is not an English menu item; the row opens account management. |
| `pushDeliveryFollow` | As for all | Same as all | "As for all" is not something an English speaker says. |

## Word order (2)

| Key | Before | After | Reason |
|---|---|---|---|
| `selected` | Selected {count} | {count} selected | "Selected 3" puts the number after the word, as a label-and-value pair would; the phrase is "3 selected". |
| `recapsNone` | Recaps appear here once a month with workouts is over. | Recaps appear here after any month with workouts in it. | "Once a month with workouts is over" reads first as "once a month". |

## What's new (`assets/whats_new/en.json`)

| Note | Before | After | Kind | Reason |
|---|---|---|---|---|
| `sign-in-later` (title) | Sign in whenever you like | Log in whenever you like | inconsistent terms | The app's verb is "log in", and onboarding has this same title with it. |
| `sign-in-later` (body) | Sign in later and everything… | Log in later and everything… | inconsistent terms | As above. |
| `features-follow-you` | your other signed-in devices know | your other logged-in devices know | inconsistent terms | As above. |
| `exercise-notes` | Signed in, you can **pin** a note | Logged in, you can **pin** a note | inconsistent terms | As above. |
| `go-easy` | The list stays on your phone. | The list stays on this device. | inconsistent terms | The app runs on tablets and says "this device". |
| `program-calendar` | a calendar on your phone | a calendar on your device | inconsistent terms | As above. |
| 13 older notes | ’ | ' | typography | Curly apostrophes in the oldest notes, straight ones in every note since. |

The two "device" notes changed meaning, so `go-easy` and `program-calendar` were changed the same
way in `es.json`, `fr.json` and `ru.json`.

No label quoted in a note was reworded, so the quoted labels still match the app.

## Glossary

The terms this pass settled on. Where two words named one thing, the one already in the majority won.

| Concept | Term | Not |
|---|---|---|
| Entering your account | **log in**, log out, logged in | sign in, signed in |
| Making an account | **sign up** | make an account, register |
| A way of logging in (Google, Apple, email and password) | **sign-in** (noun only) | provider, login |
| The thing the app runs on | **this device** | this phone. "Your phone" and "your iPhone" stay where a watch is talking about the phone it pairs with. |
| A logged training session | **workout** | session |
| A program's planned day; one outing of an exercise | **session** | workout |
| A picture | **photo** (profile photo, progress photo) | image, picture, avatar |
| Marking a set or a choice | **tick**, untick | check, uncheck |
| A goal that was met | **reached** | achieved |
| A step on a goal's ladder | **milestone** | target, rung. "Target" is what a set aims for. |
| An exercise the user made | **custom exercise**; "your own" in running text | user exercise |
| A feature switch | **turn on**, turn off | enable, disable |
| Ending a workout | **finish** | complete (as a verb). "Complete" stays as the adjective: "Your workout is complete!" |
| What can't be reversed | **can't be undone** | cannot be undone |
| A failure | **Couldn't … Try again.** | Could not … Please try again. |

Typography, as the app already had it in the majority: sentence case for titles and buttons; a
spaced em dash; straight apostrophes with curly double quotes around a quoted name; a true minus
sign. Two things are not settled and were left as found: whether a one-sentence subtitle takes a
full stop (the short ones don't, the long ones do), and whether a path through the app is written
"Settings › Features" or "Settings → Your data" (both appear; the notes in What's new all use →).

## Read and left alone, on purpose

- **The jokes.** "Uh-oh! The internet tripped over a dumbbell.", "Ghost Reps Detected 👻", "Let's
  make a password that lifts:", "To feedback!", the Canadian "eh?", "🔥🏆 Undo the Goodbye 🥇🔥", the
  farewell buttons. They are somebody's voice, not a model's default, and a plain rewrite would be
  the expected sentence in place of the unexpected one. Only their punctuation was brought into
  line. Their mock-headline capitals stay too.
- **The motto**, "Every beat counts."
- **Pattern, category and body-part names** ("Calf Raise", "Reps Only", "Full Body"). They are Title
  Case as a set, like exercise names.
- **"Weighted Body Weight" and "Assisted Body Weight".** "Bodyweight" is the word for the kind of
  exercise, and "Bodyweight and cardio" already says so. But the category's stored value is spelled
  "Body Weight" and shows in exports, so the label was left to match it. Worth deciding together
  with the value.
- **The iOS widget parameters "Data Type" and "Date Range".** Sentence case would match the other
  parameters, but each is also a literal in `TrainingWidget.swift`, and Apple's own parameter titles
  are Title Case.
- **Asked by the French, Spanish and Russian logs, and answered here.** Changed: `accountDeleted`,
  `patternHelp`, `healthWriteWorkoutsOn` and `programCalendarSetupNote` (see their rows). Left:
  `resetPasswordBody` says "No turning back after this — unless you cancel, of course." The
  contradiction is the joke, and "of course" is where it lands. `recoverBody` and the empty-gym
  line in `emptyExerciseHistoryBody` are the same voice. `programPausedNotice` says a paused
  program "won't count against your week": the week is the program's own "2 of 3 this week" line,
  which sits right above the notice. The Russian plural forms of `miles` are the Russian pass's.
- **"Messages open on your phone, in the Heart app."** It is shown where the app is *not* a phone
  app (web, desktop), pointing at the one that is. "Device" would lose the point.
- **String descriptions that still say "Account control".** The translator notes for the sign-in
  rows name the page by its old label. They are notes, not copy, and changing eight rows'
  descriptions would have widened the diff for no reader of the app.
- **Siri phrases, intent titles and the Health permission sentences.** Read, and nothing in them is
  an artifact. Intent titles are Title Case by Apple's convention.
- **"My progression", "Mine", "Export my data".** The app speaks to "you" in sentences and lets
  buttons speak as "me". That split is a convention, and it holds.
- **"Account deleted"** as the title of the page that says the account *will* be deleted. The body
  is now plain about the date; the title is a product question, not a wording one.
- **"Heart could not answer that right now"**, which Siri and the Android assistant speak. By the
  glossary it would be "couldn't", but the sentence is also a literal in `Questions.swift` and its
  test, so it was left for a change that touches both.
- The Apple Watch's sample strings in `ios/Watch/WorkoutView.swift` still read "Complete Your
  Workout?" and "-10s". They are preview data, not in the translations flow.

## Patterns

Of the 93 changes, 34 are one concept under two names and 26 are typography; together they
are nearly two thirds of the log. The model does not misuse a word so much as forget which word it used
last time: "log in" on the buttons and "sign in" in the sentences around them, a photo that is
also an image, a picture and an avatar, a goal "reached" on one screen and "achieved" on the next,
"this phone" in an app that runs on tablets. Each string is fine alone, and the fault only exists
across strings, which is exactly what writing them one ticket at a time cannot see. The typography
tells the same story by date: Title Case, curly apostrophes, unspaced dashes and "cannot" cluster in
the oldest strings (login, account, the first dialogs), and the copy written since settled on
sentence case, straight apostrophes and contractions without anyone going back.

The stiff sentences cluster where the stakes feel high. Deleting an account produced "scheduled for
deletion", "During this time" and "Once the deadline has passed"; confirmation dialogs produced
"Do you want to…" in front of questions that were already questions; an error produced "Unknown
error occurred". When the model is being careful it reaches for office language and pads. The
genuinely un-English strings are few and are all two- or three-word labels written without their
screen in view: "Selected 3", "As for all", "Account control", "About app", "Quit this page". Long
copy is where the model is at its best, and the newest long copy (programs, coaching, messages,
device keys) needed almost nothing.
