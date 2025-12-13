import 'package:flutter/material.dart';

import 'explore_page.dart';
import 'for_you_page.dart';

import 'search_users_screen.dart';
import 'messages_inbox_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [
    ExplorePage(),
    ForYouPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Explore' : 'For You'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesInboxScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: _pages[_index],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: Colors.orange,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'For You'),
        ],
      ),
    );
  }
}
