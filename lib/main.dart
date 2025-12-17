import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_page.dart';
import 'profile_screen.dart';
import 'friends_page.dart';
import 'messages_inbox_screen.dart';
import 'view_profile_screen.dart';
import 'chat_screen.dart';

// 🌗 Global theme notifier
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔄 Load saved theme from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'UTRGV Campus Connect',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData) return const AuthScreen();
              return const HomePage();
            },
          ),
          routes: {
            '/login': (_) => const AuthScreen(),
            '/home': (_) => const HomePage(),
            '/profile': (_) => const ProfileScreen(),
            '/friends': (_) => const FriendsPage(),
            '/messages': (_) => const MessagesInboxScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/viewProfile') {
              final userId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => ViewProfileScreen(userId: userId),
              );
            }
            if (settings.name == '/chat') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUserId: args['userId'],
                  otherUserEmail: args['email'] ?? 'User',
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
