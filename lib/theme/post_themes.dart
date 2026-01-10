import 'package:flutter/material.dart';

class PostThemes {
  static const List<Map<String, dynamic>> themes = [
    {
      'name': 'Default',
      'backgroundColor': Color(0xFFFFFFFF),
      'textColor': Color(0xFF000000),
    },
    {
      'name': 'Sky',
      'backgroundColor': Color(0xFFBAE6FD), // bg-sky-200
      'textColor': Color(0xFF075985),       // text-sky-800
    },
    {
      'name': 'Rose',
      'backgroundColor': Color(0xFFFECDD3), // bg-rose-200
      'textColor': Color(0xFF9F1239),       // text-rose-800
    },
    {
      'name': 'Emerald',
      'backgroundColor': Color(0xFFA7F3D0), // bg-emerald-200
      'textColor': Color(0xFF065F46),       // text-emerald-800
    },
    {
      'name': 'Amber',
      'backgroundColor': Color(0xFFFDE68A), // bg-amber-200
      'textColor': Color(0xFF92400E),       // text-amber-800
    },
    {
      'name': 'Purple',
      'backgroundColor': Color(0xFFDDD6FE), // bg-purple-200
      'textColor': Color(0xFF581C87),       // text-purple-800
    },
    {
      'name': 'Pink',
      'backgroundColor': Color(0xFFFBCFE8), // bg-pink-200
      'textColor': Color(0xFF9D174D),       // text-pink-800
    },
    {
      'name': 'Indigo',
      'backgroundColor': Color(0xFFC7D2FE), // bg-indigo-200
      'textColor': Color(0xFF3730A3),       // text-indigo-800
    },
    {
      'name': 'Teal',
      'backgroundColor': Color(0xFF99F6E4), // bg-teal-200
      'textColor': Color(0xFF115E59),       // text-teal-800
    },
    {
      'name': 'Orange',
      'backgroundColor': Color(0xFFFED7AA), // bg-orange-200
      'textColor': Color(0xFF9A3412),       // text-orange-800
    },
    {
      'name': 'Violet',
      'backgroundColor': Color(0xFFDDD6FE), // bg-violet-200
      'textColor': Color(0xFF5B21B6),       // text-violet-800
    },
  ];

  static Map<String, dynamic> getThemeByName(String name) {
    return themes.firstWhere(
      (theme) => theme['name'] == name,
      orElse: () => themes[0], // Default theme
    );
  }

  static Map<String, dynamic> getThemeByColors(Color backgroundColor, Color textColor) {
    return themes.firstWhere(
      (theme) => theme['backgroundColor'] == backgroundColor && theme['textColor'] == textColor,
      orElse: () => themes[0], // Default theme
    );
  }
}