import 'package:flutter/material.dart';
import 'package:heart/presentation/navigation/router.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final L(:logOut, :settings) = L.of(context);
    final auth = Auth.watch(context);
    final user = auth.user;
    if (user == null) return const Scaffold();
    final User(:avatar, :email, :displayName) = user;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CircleAvatar(
            foregroundImage: switch (avatar) {
              String avatar when avatar.startsWith('https') => NetworkImage(avatar),
              _ => null,
            },
            child: Text(displayName?.substring(0, 1) ?? '?'),
          ),
        ),
        title: Text(displayName ?? '?'),
        actions: [
          IconButton(
            tooltip: settings,
            onPressed: context.goToSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton.outlined(
            tooltip: logOut,
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    Auth.of(context).onSignOut();
    Exercises.of(context).onSignOut();
    Preferences.of(context).onSignOut();
    Workouts.of(context).onSignOut();
  }
}
