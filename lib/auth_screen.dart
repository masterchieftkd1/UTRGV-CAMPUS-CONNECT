import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'home_page.dart';
import 'main.dart'; // Import themeNotifier

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (!email.endsWith("@utrgv.edu")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only @utrgv.edu emails are allowed.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful! ✅")),
        );
      } else {
        await _authService.signUp(email, password);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! 🎉")),
        );
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            final bool isDark = currentMode == ThemeMode.dark;

            return Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.orange.shade50,
              body: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Icon(Icons.account_circle,
                              size: 90,
                              color: isDark
                                  ? Colors.orange.shade200
                                  : Colors.orange),
                          const SizedBox(height: 20),
                          Text(
                            _isLogin ? "Welcome Back 👋" : "Create Account 🧡",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.orange.shade200
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: "UTRGV Email",
                              hintText: "example@utrgv.edu",
                              labelStyle: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: _loading ? null : _handleAuth,
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? "Login" : "Register",
                                    style: const TextStyle(
                                        fontSize: 18, color: Colors.white),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() => _isLogin = !_isLogin);
                                  },
                            child: Text(
                              _isLogin
                                  ? "Don't have an account? Register"
                                  : "Already have an account? Login",
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 🔘 Dark/Light Mode Toggle at top-right
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Row(
                      children: [
                        Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: Colors.orange,
                        ),
                        Switch(
                          value: isDark,
                          activeColor: Colors.orange,
                          onChanged: (val) {
                            themeNotifier.value =
                                val ? ThemeMode.dark : ThemeMode.light;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
