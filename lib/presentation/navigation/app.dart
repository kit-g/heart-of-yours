import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

import 'router.dart';

class HeartApp extends StatelessWidget {
  const HeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
        ChangeNotifierProvider<Exercises>(
          create: (_) => Exercises(),
        ),
        ChangeNotifierProvider<Auth>(
          create: (_) => Auth(
            onUserChange: (_) => HeartRouter.refresh(),
          ),
        ),
      ],
      builder: (__, _) {
        return Consumer<AppTheme>(
          builder: (__, theme, _) {
            return _App(themeMode: theme.mode);
          },
        );
      },
    );
  }
}

class _App extends StatefulWidget {
  final ThemeMode? themeMode;

  const _App({this.themeMode});

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> with AfterLayoutMixin<_App> {
  @override
  Widget build(BuildContext context) {
    const theme = MaterialTheme();
    return MaterialApp.router(
      theme: theme.light(),
      darkTheme: theme.dark(),
      themeMode: widget.themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: HeartRouter.config,
      supportedLocales: const [
        Locale('en', 'CA'),
        Locale('fr', 'CA'),
      ],
      localizationsDelegates: const [
        LocsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    var Exercises(:isInitialized, :init) = Exercises.of(context);
    if (!isInitialized) {
      init();
    }
  }
}
