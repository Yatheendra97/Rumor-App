import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local_store.dart';
import 'data/room_repository.dart';
import 'ui/join_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    final store = LocalStore(await SharedPreferences.getInstance());
    runApp(RumorApp(store: store));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme(false),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KeyMark(),
                  const SizedBox(height: 24),
                  const Text('Rumour could not start'),
                  const SizedBox(height: 12),
                  const Text(
                    'Please close and reopen the app. If the problem continues, reinstall the latest APK.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RumorApp extends StatefulWidget {
  const RumorApp({super.key, required this.store});
  final LocalStore store;
  @override
  State<RumorApp> createState() => _RumorAppState();
}

class _RumorAppState extends State<RumorApp> {
  late bool light = widget.store.lightMode;
  late final repository = RoomRepository(widget.store);
  void toggleTheme() {
    setState(() => light = !light);
    widget.store.setLightMode(light);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rumour',
    debugShowCheckedModeBanner: false,
    theme: appTheme(true),
    darkTheme: appTheme(false),
    themeMode: light ? ThemeMode.light : ThemeMode.dark,
    builder: (context, child) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: canvasDark,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: const Color(0xFFF5F6F2),
              ),
        child: child!,
      );
    },
    home: JoinScreen(repository: repository, onToggleTheme: toggleTheme),
  );
}
