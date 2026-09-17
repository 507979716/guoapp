import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core_bridge.dart';
import 'home_screen.dart';
import 'local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  MediaKit.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final repository = NativeRepository();
  LocalStore? store;
  Object? error;

  @override
  void dispose() {
    store?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await repository.initialize();
      if (mounted) {
        setState(() {
          store = LocalStore(preferences);
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DuanjuApp(
    repository: repository,
    store: store,
    bootstrapError: error?.toString(),
    onRetry: _initialize,
  );
}

class DuanjuApp extends StatelessWidget {
  const DuanjuApp({
    super.key,
    required this.repository,
    this.store,
    this.bootstrapError,
    this.onRetry,
  });
  final AppRepository repository;
  final LocalStore? store;
  final String? bootstrapError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '短剧库',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF664F),
        brightness: Brightness.dark,
        primary: const Color(0xFFFF765F),
        surface: const Color(0xFF16171B),
      ),
      scaffoldBackgroundColor: const Color(0xFF101114),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101114),
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF18191E),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF23252D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: store != null
        ? HomeScreen(repository: repository, store: store!)
        : Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFFFF765F),
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      bootstrapError ?? '正在打开短剧库',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    if (bootstrapError == null)
                      const CircularProgressIndicator()
                    else
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('重新打开'),
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}
