import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/admin_portal_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const CECApp());
}

class CECApp extends StatelessWidget {
  const CECApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, _, themeProvider, __) {
          return MaterialApp(
            title: 'CEC ECHO',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/admin-portal': (context) => const AdminPortalScreen(),
            },
            home: const AppBootstrapScreen(),
          );
        },
      ),
    );
  }
}

ThemeData _buildLightTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFF7C600),
    onPrimary: Color(0xFF111111),
    primaryContainer: Color(0xFFFFE48A),
    onPrimaryContainer: Color(0xFF2A2300),
    secondary: Color(0xFF1A1A1A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE6E6E6),
    onSecondaryContainer: Color(0xFF111111),
    tertiary: Color(0xFF7A6500),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFEADCA0),
    onTertiaryContainer: Color(0xFF2C2400),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    background: Color(0xFFFFFBF0),
    onBackground: Color(0xFF141414),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF141414),
    surfaceVariant: Color(0xFFF4F0E3),
    onSurfaceVariant: Color(0xFF3A3525),
    outline: Color(0xFFE2D8B8),
    outlineVariant: Color(0xFFEDE4C8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1B1B1B),
    onInverseSurface: Color(0xFFF5F5F5),
    inversePrimary: Color(0xFFF7C600),
    surfaceTint: Color(0xFFF7C600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    fontFamily: 'Verdana',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: scheme.onSurface),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}

ThemeData _buildDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF7C600),
    onPrimary: Color(0xFF111111),
    primaryContainer: Color(0xFFD9AE00),
    onPrimaryContainer: Color(0xFF2A2300),
    secondary: Color(0xFFF2F2F2),
    onSecondary: Color(0xFF111111),
    secondaryContainer: Color(0xFF2A2A2A),
    onSecondaryContainer: Color(0xFFEDEDED),
    tertiary: Color(0xFFC9A200),
    onTertiary: Color(0xFF111111),
    tertiaryContainer: Color(0xFF7E6400),
    onTertiaryContainer: Color(0xFFFFE7A3),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    background: Color(0xFF0B0B0B),
    onBackground: Color(0xFFF2F2F2),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFF2F2F2),
    surfaceVariant: Color(0xFF1A1A1A),
    onSurfaceVariant: Color(0xFFCACACA),
    outline: Color(0xFF2A2A2A),
    outlineVariant: Color(0xFF3A3A3A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEDEDED),
    onInverseSurface: Color(0xFF111111),
    inversePrimary: Color(0xFFF7C600),
    surfaceTint: Color(0xFFF7C600),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    fontFamily: 'Verdana',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: scheme.onSurface),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}

class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _initializing = true;
  static const Duration _minSplashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      auth.tryAutoLogin().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      ),
      Future.delayed(_minSplashDuration),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const SplashScreen();
    }
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    if (auth.user?.role == 'admin') {
      return const AdminPortalScreen();
    }
    return const HomeScreen();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              scheme.secondary.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(scale: _scale.value, child: child),
                  );
                },
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    size: 52,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'CEC ECHO',
                style: TextStyle(
                  color: scheme.onSecondary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Campus communication, unified.',
                style: TextStyle(
                  color: scheme.onSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
