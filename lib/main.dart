import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/audio_handler.dart';
import 'theme/maoneart_theme.dart';
import 'views/home_screen.dart';
import 'views/search_screen.dart';
import 'views/library_screen.dart';
import 'views/settings_screen.dart';
import 'widgets/glass_container.dart';
import 'widgets/mini_player.dart';

class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = AppHttpOverrides();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize AudioService for background playback & notification controls
  try {
    await initAudioService();
  } catch (e) {
    print("AudioService init error: $e");
  }

  runApp(const ProviderScope(child: MaoneArtMusicApp()));
}

class MaoneArtMusicApp extends StatelessWidget {
  const MaoneArtMusicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaoneArt Music',
      debugShowCheckedModeBanner: false,
      theme: MaoneArtTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        body: Row(
          children: [
            // Glass Navigation Rail on Left
            _buildLandscapeNavRail(),
            // Main Content Area with docked MiniPlayer
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 6,
                    child: MiniPlayer(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Floating Bottom Navigation Bar + MiniPlayer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF141926).withOpacity(0.88),
                                  const Color(0xFF0F131F).withOpacity(0.94),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
                                _buildNavItem(1, Icons.search_rounded, Icons.search_outlined, "Cari"),
                                _buildNavItem(2, Icons.library_music_rounded, Icons.library_music_outlined, "Koleksi"),
                                _buildNavItem(3, Icons.settings_rounded, Icons.settings_outlined, "Pengaturan"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeNavRail() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF0F131F).withOpacity(0.96),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.12),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Logo / App Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ic_launcher.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, indent: 12, endIndent: 12, height: 1),
            const SizedBox(height: 6),
            // Navigation Items
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRailItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
                    const SizedBox(height: 6),
                    _buildRailItem(1, Icons.search_rounded, Icons.search_outlined, "Cari"),
                    const SizedBox(height: 6),
                    _buildRailItem(2, Icons.library_music_rounded, Icons.library_music_outlined, "Koleksi"),
                    const SizedBox(height: 6),
                    _buildRailItem(3, Icons.settings_rounded, Icons.settings_outlined, "Pengaturan"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? MaoneArtTheme.spotifyGreen.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MaoneArtTheme.spotifyGreen.withOpacity(0.4) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.55),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? MaoneArtTheme.spotifyGreen.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? MaoneArtTheme.spotifyGreen.withOpacity(0.38) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.55),
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.55),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
