import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  String? photoUrl;
  bool isDarkMode = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfile();
    loadTheme();
  }

  // Load profile info from Firestore
  Future<void> loadProfile() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    final data = doc.data() ?? {};

    setState(() {
      photoUrl = data["photoUrl"];
      _nameController.text = data["name"] ?? "";
      _bioController.text = data["bio"] ?? "";
      _phoneController.text = data["phone"] ?? "";
    });
  }

  // Load theme preference
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isDarkMode = prefs.getBool("darkMode") ?? false);
  }

  Future<void> saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("darkMode", value);
  }

  // Upload profile picture
  Future<void> uploadProfilePicture() async {
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child("profile_pics/${user!.uid}.jpg");

    await storageRef.putFile(File(picked.path));
    final url = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .update({"photoUrl": url});

    setState(() => photoUrl = url);
  }

  // Save profile info
  Future<void> saveProfileData() async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .update({
      "name": _nameController.text.trim(),
      "bio": _bioController.text.trim(),
      "phone": _phoneController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.orange,
        centerTitle: true,

        // Friends screen icon
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: "Friends / Requests",
            onPressed: () {
              Navigator.pushNamed(context, '/friends');
            },
          ),
        ],
      ),

      // Body
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: uploadProfilePicture,
              child: CircleAvatar(
                radius: 65,
                backgroundColor: Colors.orange.shade200,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, size: 80, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(height: 15),

            // Email
            Text(
              user?.email ?? "",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Fields
            buildInput("Name", _nameController),
            buildInput("Bio", _bioController),
            buildInput("Phone Number", _phoneController),

            const SizedBox(height: 10),

            // Save button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(180, 45),
              ),
              onPressed: saveProfileData,
              child: const Text("Save Profile"),
            ),

            const SizedBox(height: 30),

            // Account info
            cardSection([
              infoTile(Icons.mail, "Email", user?.email ?? "Unknown"),
              infoTile(Icons.badge, "User ID", user?.uid ?? "--"),
              infoTile(
                Icons.calendar_month,
                "Created",
                user?.metadata.creationTime.toString() ?? "",
              ),
            ]),

            const SizedBox(height: 30),

            // Theme toggle
            cardSection([
              SwitchListTile(
                title: Text(
                  "Dark Mode",
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                ),
                value: isDarkMode,
                onChanged: (v) {
                  setState(() => isDarkMode = v);
                  saveTheme(v);
                },
              ),
            ]),

            const SizedBox(height: 25),

            // Change password
            ElevatedButton(
              onPressed: () async {
                if (user?.email == null) return;

                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: user!.email!);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password reset email sent.")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                minimumSize: const Size(220, 45),
              ),
              child: const Text("Change Password"),
            ),

            const SizedBox(height: 15),

            // Delete account
            ElevatedButton(
              onPressed: () async {
                await user?.delete();
                if (!mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/login",
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(220, 45),
              ),
              child: const Text("Delete Account"),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // UI Widgets
  // =====================================================

  Widget buildInput(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          filled: true,
          fillColor:
              isDarkMode ? Colors.grey.shade800 : Colors.orange.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget cardSection(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}
