import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_page.dart';
import 'profile_screen.dart';
import 'friends_page.dart';
import 'messages_inbox_screen.dart';
import 'view_profile_screen.dart';
import 'chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// Global theme notifier
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'UTRGV Campus Connect',
          debugShowCheckedModeBanner: false,

          // 🌗 THEMES
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,

          // 🔐 AUTH STATE HANDLER
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData) {
                return const AuthScreen();
              }

              return const HomePage();
            },
          ),

          // ✅ REGISTER ALL ROUTES HERE
          routes: {
            '/login': (_) => const AuthScreen(),
            '/home': (_) => const HomePage(),
            '/profile': (_) => const ProfileScreen(),
            '/friends': (_) => const FriendsPage(),
            '/messages': (_) => const MessagesInboxScreen(),
          },

          // 🧭 ROUTES WITH ARGUMENTS
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
