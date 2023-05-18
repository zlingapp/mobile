import 'dart:core';
import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange, brightness: Brightness.light),
  fontFamily: "Whitney",
);

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7289DA), brightness: Brightness.dark),
  fontFamily: "Whitney",
);
