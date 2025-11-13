import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth_screen.dart';
import 'home_page.dart';
import 'profile_screen.dart';

void main() async {
  print("🔥 MAIN.DART IS RUNNING FROM HERE");
  print("🔥 ROUTES REGISTERED: /login /home /profile");

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

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        useMaterial3: true,
      ),

      initialRoute: '/login',

      routes: {
        '/login': (context) => const AuthScreen(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
