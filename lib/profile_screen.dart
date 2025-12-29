import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'add_book_screen.dart';
import 'animations.dart';
import 'auth_page.dart';
import 'book_model.dart';
import 'reader_screen.dart';
import 'settings_provider.dart';
import 'image_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  int _profileRefreshKey = 0;
  int _publishedRefreshKey = 0;
  int _draftsRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch user profile data
  Future<Map<String, dynamic>?> _fetchProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }

  // Pick profile image
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final compressed = await compressImage(
          file,
          quality: 85,
          width: 400,
          height: 400,
        );
        _confirmChangeProfileImage(compressed);
      }
    } catch (e) {
      debugPrint('Profile image pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  // Upload profile image to storage
  Future<void> _uploadProfileImage(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final fileName =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profiles/$fileName';

      // Upload to Supabase storage (imageFile is already compressed)
      await _supabase.storage.from('covers').upload(filePath, imageFile);

      // Get public URL
      final imageUrl = _supabase.storage.from('covers').getPublicUrl(filePath);

      // Try updating several common columns in case the DB uses a different name
      final candidateKeys = [
        'profile_image_url',
        'image_url',
        'avatar_url',
        'avatar',
      ];
      var updated = false;
      for (final key in candidateKeys) {
        try {
          await _supabase
              .from('profiles')
              .update({key: imageUrl})
              .eq('id', user.id);
          updated = true;
          break;
        } on PostgrestException catch (e) {
          // If the column doesn't exist, Postgrest returns a message containing "Could not find the '...' column"
          if (e.message != null && e.message!.contains("Could not find the")) {
            // try the next candidate
            continue;
          }
          rethrow;
        }
      }

      if (!updated) {
        debugPrint(
          'Profile image upload failed: no matching image column in profiles table.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to update profile: add an image column to the profiles table',
              ),
            ),
          );
        }
        return;
      }

      setState(() => _profileRefreshKey++); // Refresh profile
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile image updated')));
      }
    } catch (e) {
      debugPrint('Profile image upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to upload image')));
      }
    }
  }

  // Fetch published stories written by the logged-in user
  Future<List<Book>> _fetchMyPublishedBooks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('books')
        .select()
        .eq('author_id', user.id)
        .eq('status', 'Published')
        .order('created_at', ascending: false);

    return (response as List).map((data) => Book.fromMap(data)).toList();
  }

  // Fetch draft stories written by the logged-in user
  Future<List<Book>> _fetchMyDraftBooks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('books')
        .select()
        .eq('author_id', user.id)
        .eq('status', 'Draft')
        .order('created_at', ascending: false);

    return (response as List).map((data) => Book.fromMap(data)).toList();
  }

  // Delete a story from the database
  Future<void> _deleteBook(String bookId) async {
    try {
      await _supabase.from('books').delete().eq('id', bookId);
      setState(() {}); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Story deleted")));
      }
    } catch (e) {
      debugPrint("Error deleting book: $e");
    }
  }

  // Edit profile
  void _editProfile(Map<String, dynamic>? profile) {
    final currentUsername = profile?['username'] ?? '';
    final controller = TextEditingController(text: currentUsername);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Username"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => _confirmSaveProfile(controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Update profile in database
  Future<void> _updateProfile(String username) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'username': username})
          .eq('id', user.id);
      setState(() => _profileRefreshKey++); // Refresh the profile
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile updated")));
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error updating profile")));
      }
    }
  }

  // Return profile image URL if available under any common column name
  String? _getProfileImageUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    return profile['profile_image_url'] ??
        profile['image_url'] ??
        profile['avatar_url'] ??
        profile['avatar'];
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Published'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- Profile Header ---
          FutureBuilder<Map<String, dynamic>?>(
            key: ValueKey(_profileRefreshKey),
            future: _fetchProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final profile = snapshot.data;
              final username = profile?['username'] ?? 'Unknown User';
              final profileImageUrl = _getProfileImageUrl(profile);
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFFFEB3B),
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editProfile(profile),
                        ),
                      ],
                    ),
                    Text(
                      user?.email ?? "User Email",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Divider(height: 30),
                  ],
                ),
              );
            },
          ),

          // --- TabBarView for Published and Drafts ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Published Tab
                _buildBookList(
                  _fetchMyPublishedBooks(),
                  "No published stories yet.",
                ),
                // Drafts Tab
                _buildBookList(_fetchMyDraftBooks(), "No drafts yet."),
              ],
            ),
          ),

          // --- Settings Section ---
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Theme Mode
                    ListTile(
                      title: const Text("Theme Mode"),
                      subtitle: Text(
                        settings.themeMode == ThemeMode.light
                            ? "Light"
                            : settings.themeMode == ThemeMode.dark
                            ? "Dark"
                            : "System",
                      ),
                      trailing: DropdownButton<ThemeMode>(
                        value: settings.themeMode,
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text("System"),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text("Light"),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text("Dark"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setThemeMode(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Theme changed successfully"),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // Font Size
                    ListTile(
                      title: const Text("Font Size"),
                      subtitle: Text(
                        settings.fontSize == 0.8
                            ? "Small"
                            : settings.fontSize == 1.0
                            ? "Medium"
                            : "Large",
                      ),
                      trailing: DropdownButton<double>(
                        value: settings.fontSize,
                        items: const [
                          DropdownMenuItem(value: 0.8, child: Text("Small")),
                          DropdownMenuItem(value: 1.0, child: Text("Medium")),
                          DropdownMenuItem(value: 1.2, child: Text("Large")),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setFontSize(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Font size changed successfully"),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // Account Settings
                    ListTile(
                      title: const Text("Account Settings"),
                      subtitle: const Text("Manage your profile"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showAccountSettings(),
                    ),
                    const Divider(),
                    // Logout Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text("Log Out"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _confirmLogout(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(Future<List<Book>> future, String emptyMessage) {
    return FutureBuilder<List<Book>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        final books = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return Card(
              elevation: 0,
              color: Colors.grey[50],
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: book.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          book.coverUrl!,
                          width: 40,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.book),
                title: Text(
                  book.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${book.genre} - ${book.status}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => Navigator.push(
                        context,
                        createSlideRoute(AddBookScreen(book: book)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmDelete(book),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(book: book),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Confirmation Dialog before deleting
  void _confirmDelete(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Story?"),
        content: Text(
          "Are you sure you want to delete '${book.title}'? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBook(book.id.toString());
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog before saving profile
  void _confirmSaveProfile(String newUsername) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Changes?"),
        content: Text("Update username to '$newUsername'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              await _updateProfile(newUsername);
              Navigator.pop(context); // Close edit dialog
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog before changing profile image
  void _confirmChangeProfileImage(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Profile Image?"),
        content: const Text(
          "Are you sure you want to update your profile image?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _uploadProfileImage(imageFile);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // Account Settings Dialog
  void _showAccountSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Account Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Edit Profile"),
              onTap: () {
                Navigator.pop(context);
                _editProfile(null); // Pass null, will fetch in dialog
              },
            ),
            ListTile(
              title: const Text("Change Password"),
              onTap: () {
                Navigator.pop(context);
                // Implement password change
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password change not implemented yet"),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog before logging out
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out?"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  createSlideRoute(const AuthPage()),
                  (route) => false,
                );
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
