import 'package:flutter/material.dart';
import 'auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final _authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("UTRGV Campus Connect"),
        backgroundColor: Colors.orange,

        actions: [

          // ⭐ Profile Button
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "My Profile",
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),

          // ⭐ Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      body: const Center(
        child: Text(
          "Welcome to UTRGV Campus Connect 🎓",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
