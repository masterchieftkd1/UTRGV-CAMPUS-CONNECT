// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_page.dart'; // <-- this is your bottom-nav Explore/ForYou shell

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
          // waiting for Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // not logged in
          if (!snapshot.hasData) {
            return const AuthScreen();
          }

          // logged in
          return const HomePage();
        },
      ),

      // ✅ EXPLICIT ROUTES (THIS FIXES YOUR ERROR)
      routes: {
        '/home': (_) => const HomePage(),
        '/login': (_) => const AuthScreen(),
      },
    );
  }
}
