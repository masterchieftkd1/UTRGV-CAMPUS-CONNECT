import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_page.dart';
import 'profile_screen.dart';
import 'view_profile_screen.dart';
import 'friends_page.dart';
import 'messages_page.dart';
import 'chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTRGV Campus Connect',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const AuthScreen(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfileScreen(),
        '/friends': (context) => const FriendsPage(),
        '/messages': (context) => const MessagesPage(),
      },

      // Routes that need arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/viewProfile') {
          final userId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ViewProfileScreen(userId: userId),
          );
        }

        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>;
          final otherUserId = args['userId'] as String;
          final otherEmail = args['email'] as String? ?? 'User';
          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: otherUserId,
              otherUserEmail: otherEmail,
            ),
          );
        }

        return null;
      },
    );
  }
}
