import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/theme_service.dart';
import 'widgets/app_brand_title.dart';
import 'views/login_view.dart';
import 'views/customer_portal.dart';
import 'views/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.exceptionAsString());
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  SchedulerBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher.onError: $error');
    debugPrint(stack.toString());
    return true;
  };

  Object? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    firebaseInitError = e;
    debugPrint('Firebase.initializeApp failed: $e\n$st');
  }

  if (firebaseInitError != null) {
    runApp(
      MaterialApp(
        title: 'Multi-chat',
        home: Scaffold(
          appBar: AppBar(title: const AppBrandTitle()),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firebase failed to start',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        firebaseInitError.toString(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check lib/firebase_options.dart and run '
                    '`dart pub global run flutterfire_cli:flutterfire configure` for this platform.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  final themeService = await ThemeService.create();
  runApp(MyApp(themeService: themeService));
}

abstract final class AppRoutes {
  static const root = '/';
  static const admin = '/admin';
  static const chat = '/chat';

  static String normalize(String? routeName) {
    switch (routeName) {
      case admin:
        return admin;
      case chat:
        return chat;
      case root:
      case null:
      default:
        return root;
    }
  }
}

String _initialAppRoute() {
  if (!kIsWeb) return AppRoutes.root;
  return AppRoutes.normalize(Uri.base.path);
}

class MyApp extends StatelessWidget {
  final ThemeService themeService;
  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: themeService),
        Provider(create: (_) => ChatService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) => MaterialApp(
          title: 'Multi-chat',
          debugShowCheckedModeBanner: false,
          initialRoute: _initialAppRoute(),
          onGenerateRoute: (settings) {
            final targetRoute = AppRoutes.normalize(settings.name);
            return MaterialPageRoute<void>(
              settings: RouteSettings(name: targetRoute),
              builder: (_) => AuthRouter(targetRoute: targetRoute),
            );
          },
          themeMode: themeService.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            appBarTheme: AppBarTheme(
              centerTitle: false,
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthRouter extends StatelessWidget {
  final String targetRoute;
  const AuthRouter({super.key, required this.targetRoute});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return LoginView(
        title: targetRoute == AppRoutes.admin ? 'Admin Sign In' : 'Sign In',
      );
    }

    if (user.role == 'admin') {
      return const AdminDashboard();
    }

    if (targetRoute == AppRoutes.admin) {
      return const AccessDeniedView();
    }

    return const CustomerPortal();
  }
}

class AccessDeniedView extends StatelessWidget {
  const AccessDeniedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBrandTitle()),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'This account does not have admin access.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in with an account whose Firestore user profile has role "admin", or return to the customer chat.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed(
                        AppRoutes.chat,
                      ),
                      child: const Text('Open Customer Chat'),
                    ),
                    OutlinedButton(
                      onPressed: () => Provider.of<AuthService>(
                        context,
                        listen: false,
                      ).signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
