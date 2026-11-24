import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/push.dart';
import 'core/remember.dart';
import 'core/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  await initFirebase();
  final prefs = await SharedPreferences.getInstance();
  final store = SessionStore(prefs);
  final session = await store.load();
  final info = await PackageInfo.fromPlatform();
  runApp(ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      rememberProvider.overrideWithValue(RememberStore(prefs)),
      initialSessionProvider.overrideWithValue(session),
      appVersionProvider.overrideWithValue(info.version),
    ],
    child: const DTaskApp(),
  ));
}
