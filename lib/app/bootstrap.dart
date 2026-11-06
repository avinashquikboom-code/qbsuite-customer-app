import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/environment.dart';
import '../core/storage/preferences.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  Environment.validate();
  final preferences = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [preferencesProvider.overrideWithValue(preferences)], child: const App()));
}
