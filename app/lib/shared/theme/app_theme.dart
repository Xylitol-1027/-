import 'package:flutter/material.dart';

/// design.mdのモックアップで使ったティール系のアクセントカラーをシード色として使う。
const Color kAccentSeedColor = Color(0xFF2B6E63);

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccentSeedColor,
      brightness: Brightness.light,
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccentSeedColor,
      brightness: Brightness.dark,
    ),
  );
}
