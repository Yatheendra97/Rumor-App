import 'package:flutter/material.dart';

const lime = Color(0xFFA3E635);
const canvasDark = Color(0xFF09090B);
const surfaceDark = Color(0xFF11141E);

ThemeData appTheme(bool light) {
  final scheme = ColorScheme.fromSeed(
    seedColor: lime,
    brightness: light ? Brightness.light : Brightness.dark,
    primary: lime,
    onPrimary: const Color(0xFF17200B),
    surface: light ? const Color(0xFFF5F6F2) : canvasDark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Outfit',
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: light ? const Color(0xFF17191F) : const Color(0xFFE8E8EE),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: lime,
        foregroundColor: const Color(0xFF111509),
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
  );
}

Color panel(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? surfaceDark
    : const Color(0xFFE8EBE3);
Color muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF92939D)
    : const Color(0xFF666C61);

class KeyMark extends StatelessWidget {
  const KeyMark({super.key, this.size = 64, this.disc = true});
  final double size;
  final bool disc;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: disc
        ? ClipOval(child: Image.asset('assets/app_icon.png'))
        : Image.asset('assets/app_icon.png'),
  );
}
