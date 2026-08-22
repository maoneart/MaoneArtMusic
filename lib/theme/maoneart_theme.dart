import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MaoneArtTheme {
  static const Color primaryCyan = Color(0xFF00F0FF);
  static const Color primaryPurple = Color(0xFF9D00FF);
  static const Color accentGreen = Color(0xFF00FF9D);
  static const Color spotifyGreen = Color(0xFF1DB954);
  static const Color spotifyGreenBright = Color(0xFF1ED760);
  static const Color bgDark = Color(0xFF0B0F19);
  static const Color cardGlass = Color(0x1AFFFFFF);
  static const Color cardGlassBorder = Color(0x33FFFFFF);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    primaryColor: primaryCyan,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: primaryPurple,
      surface: Color(0xFF141927),
      background: bgDark,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    useMaterial3: true,
  );
}
