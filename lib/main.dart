// lib/main.dart
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTRGV Campus Connect',
      debugShowCheckedModeBanner: false,

      // 🔑 AUTH STATE HANDLER
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Waiting for Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Not logged in
          if (!snapshot.hasData) {
            return const AuthScreen();
          }

          // Logged in
          return const HomePage();
        },
      ),

      // ✅ NAMED ROUTES
      routes: {
        '/login': (_) => const AuthScreen(),
        '/home': (_) => const HomePage(),
        '/profile': (_) => const ProfileScreen(),
        '/friends': (_) => const FriendsPage(),
        '/messages': (_) => const MessagesInboxScreen(),
      },

      // ✅ ROUTES WITH ARGUMENTS
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
  }
}
