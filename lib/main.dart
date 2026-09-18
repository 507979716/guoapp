import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core_bridge.dart';
import 'app_layout.dart';
import 'home_screen.dart';
import 'local_store.dart';
import 'profiles_screen.dart';
import 'media_library.dart';
import 'package_smoke.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  MediaKit.ensureInitialized();
  if (Platform.isWindows && arguments.firstOrNull == '--package-smoke') {
    await runPackageSmoke(arguments);
    return;
  }
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with WidgetsBindingObserver {
  final repository = NativeRepository();
  LocalStore? store;
  Object? error;
  AppDevice device = const AppDevice();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MediaLibrary.current?.dispose();
    MediaLibrary.current = null;
    store?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS) return;
    final library = MediaLibrary.current;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (library != null) {
        library.suspended = true;
        unawaited(library.cancel());
      }
      unawaited(
        NativeRepository(
          background: true,
        ).controlDownloads('pauseAll').catchError((Object _) {}),
      );
    } else if (state == AppLifecycleState.resumed) {
      if (library != null) library.suspended = false;
    }
  }

  Future<void> _initialize() async {
    setState(() {
      error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      device = await AppDevice.detect();
      await repository.initialize();
      if (mounted) {
        setState(() {
          store = LocalStore(preferences);
          repository.access = store;
          MediaLibrary.attach(repository, store!);
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
    television: device.television,
    version: device.version,
  );
}

class DuanjuApp extends StatelessWidget {
  const DuanjuApp({
    super.key,
    required this.repository,
    this.store,
    this.bootstrapError,
    this.onRetry,
    this.television = false,
    this.version = appVersion,
  });
  final AppRepository repository;
  final LocalStore? store;
  final String? bootstrapError;
  final VoidCallback? onRetry;
  final bool television;
  final String version;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '真果鉴',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) {
      Widget layout() {
        final mode = store?.displayMode ?? 'auto';
        final tv = mode == 'television' || mode == 'auto' && television;
        return AppLayout(
          television: tv,
          version: version,
          child: Theme(
            data: tv ? televisionTheme(Theme.of(context)) : Theme.of(context),
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(
                  LogicalKeyboardKey.select,
                  includeRepeats: false,
                ): ActivateIntent(),
                SingleActivator(
                  LogicalKeyboardKey.gameButtonA,
                  includeRepeats: false,
                ): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
              },
              child: FocusTraversalGroup(child: child!),
            ),
          ),
        );
      }

      return store == null
          ? layout()
          : AnimatedBuilder(animation: store!, builder: (_, _) => layout());
    },
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
        ? AnimatedBuilder(
            animation: store!,
            builder: (_, _) => store!.locked
                ? ProfilesScreen(store: store!, locked: true)
                : HomeScreen(
                    key: ValueKey(
                      'profile-${store!.profile.id}-${store!.profileEpoch}',
                    ),
                    repository: repository,
                    store: store!,
                  ),
          )
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
                      bootstrapError ?? '正在打开真果鉴',
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
