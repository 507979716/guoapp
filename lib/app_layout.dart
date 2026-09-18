import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const appName = '真果鉴';
const appVersion = '0.2.0';

ThemeData televisionTheme(ThemeData theme) {
  final focusSide = WidgetStateProperty.resolveWith<BorderSide?>(
    (states) => states.contains(WidgetState.focused)
        ? const BorderSide(color: Color(0xFFFFAE93), width: 3)
        : null,
  );
  final focusBackground = WidgetStateProperty.resolveWith<Color?>(
    (states) =>
        states.contains(WidgetState.focused) ? const Color(0xFF523128) : null,
  );
  final button = ButtonStyle(
    side: focusSide,
    minimumSize: const WidgetStatePropertyAll(Size(52, 48)),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 17)),
  );
  return theme.copyWith(
    focusColor: const Color(0xFF754838),
    iconButtonTheme: IconButtonThemeData(
      style: button.copyWith(backgroundColor: focusBackground),
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button),
    textButtonTheme: TextButtonThemeData(
      style: button.copyWith(backgroundColor: focusBackground),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFFAE93), width: 3),
      ),
    ),
  );
}

class AppDevice {
  const AppDevice({this.television = false, this.version = appVersion});
  final bool television;
  final String version;
  static const channel = MethodChannel('duanju/device');

  static Future<AppDevice> detect() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const AppDevice();
    }
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('deviceInfo');
      return AppDevice(
        television: data?['television'] == true,
        version: data?['version'] as String? ?? appVersion,
      );
    } on PlatformException {
      return const AppDevice();
    } on MissingPluginException {
      return const AppDevice();
    }
  }
}

class AppLayout extends InheritedWidget {
  const AppLayout({
    super.key,
    required this.television,
    this.version = appVersion,
    required super.child,
  });
  final bool television;
  final String version;

  static bool isTelevision(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayout>()?.television ??
      false;
  static String versionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayout>()?.version ??
      appVersion;

  @override
  bool updateShouldNotify(AppLayout oldWidget) =>
      television != oldWidget.television || version != oldWidget.version;
}
