import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'add_book_screen.dart';
import 'animations.dart';
import 'auth_page.dart';
import 'book_model.dart';
import 'reader_screen.dart';
import 'settings_provider.dart';
import 'image_utils.dart';
import 'widgets/book_flip_loading.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          if (e.message.contains("Could not find the")) {}
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
        ).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("✓ Profile updated successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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
            Tab(text: 'Settings'),
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
                  child: Center(child: LogoLoading()),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                      ),
                    ),
                    const Divider(height: 30),
                  ],
                ),
              );
            },
          ),

          // --- TabBarView for Published, Drafts, and Settings ---
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
                // Settings Tab
                _buildSettingsTab(),
              ],
            ),
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
          return const Center(child: LogoLoading());
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
              color: Theme.of(
                context,
              ).colorScheme.surface.withAlpha((0.05 * 255).round()),
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
            child: Text(
              "Delete",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog before saving profile - Fixed to close edit dialog first
  void _confirmSaveProfile(String newUsername) {
    // Close the edit dialog first
    Navigator.pop(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
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

  // Change Email dialog
  void _showChangeEmailDialog() {
    final controller = TextEditingController(
      text: _supabase.auth.currentUser?.email ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newEmail = controller.text.trim();
              Navigator.pop(context);
              await _changeEmail(newEmail);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(String newEmail) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email updated')));
      }
    } catch (e) {
      debugPrint('Failed to update email: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update email')));
      }
    }
  }

  // Change Password dialog
  void _showChangePasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newPassword = controller.text;
              Navigator.pop(context);
              await _changePassword(newPassword);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated')));
      }
    } catch (e) {
      debugPrint('Failed to update password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update password')),
        );
      }
    }
  }

  // Support & Legal dialog boilerplate (shows content and allows copy)
  void _showSupportDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(content),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Build Settings Tab
  Widget _buildSettingsTab() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 10),
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

            // --- Account & Profile ---
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                'Account & Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchProfile(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final username = profile?['username'] ?? 'Unknown User';
                final email = _supabase.auth.currentUser?.email ?? '';
                return Column(
                  children: [
                    ListTile(
                      title: Text(username),
                      subtitle: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final p = await _fetchProfile();
                          _editProfile(p);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Change Email'),
                      subtitle: Text(email),
                      onTap: () => _showChangeEmailDialog(),
                    ),
                    ListTile(
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your password'),
                      onTap: () => _showChangePasswordDialog(),
                    ),
                  ],
                );
              },
            ),

            const Divider(),

            // --- Application Preferences ---
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                'Application Preferences',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                  if (value != null) settings.setThemeMode(value);
                },
              ),
            ),

            // Push Notifications (expanded)
            ExpansionTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Push Notifications'),
              children: [
                SwitchListTile(
                  title: const Text('New Chapter Reminders'),
                  value: settings.pushNewChapterReminders,
                  onChanged: (val) =>
                      settings.setPushNewChapterReminders(val),
                ),
                SwitchListTile(
                  title: const Text('Story Likes'),
                  value: settings.pushStoryLikes,
                  onChanged: (val) => settings.setPushStoryLikes(val),
                ),
                SwitchListTile(
                  title: const Text('Comments'),
                  value: settings.pushComments,
                  onChanged: (val) => settings.setPushComments(val),
                ),
              ],
            ),

            // Language
            ListTile(
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: settings.language,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                ],
                onChanged: (val) {
                  if (val != null) settings.setLanguage(val);
                },
              ),
            ),

            const Divider(),

            // --- Reader & Writer Specifics ---
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                'Reader & Writer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // Font Size Slider
            ListTile(
              title: const Text('Default Font Size'),
              subtitle: Text(
                settings.fontSize <= 0.85
                    ? 'Small'
                    : settings.fontSize <= 1.05
                    ? 'Medium'
                    : 'Large',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              subtitleTextStyle: const TextStyle(),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.fontSize,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: '${(settings.fontSize * 100).round()}%',
                  onChanged: (val) => settings.setFontSize(
                    double.parse(val.toStringAsFixed(2)),
                  ),
                ),
              ),
            ),

            // Reading Background
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ReadingBackground.values.map((b) {
                return RadioListTile<ReadingBackground>(
                  title: Text(
                    b == ReadingBackground.white
                        ? 'White'
                        : b == ReadingBackground.sepia
                        ? 'Sepia'
                        : 'Pure Black',
                  ),
                  value: b,
                  groupValue: settings.readingBackground,
                  onChanged: (val) {
                    if (val != null) settings.setReadingBackground(val);
                  },
                );
              }).toList(),
            ),

            // Auto-save drafts
            SwitchListTile(
              title: const Text('Auto-save Drafts'),
              value: settings.autoSaveDrafts,
              onChanged: (val) => settings.setAutoSaveDrafts(val),
            ),

            const Divider(),

            // --- AI Writing Assistant ---
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                'AI Writing Assistant',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              children: AiTone.values.map((t) {
                return RadioListTile<AiTone>(
                  title: Text(
                    t == AiTone.creative
                        ? 'Creative'
                        : t == AiTone.formal
                        ? 'Formal'
                        : 'Dramatic',
                  ),
                  value: t,
                  groupValue: settings.aiTone,
                  onChanged: (val) {
                    if (val != null) settings.setAiTone(val);
                  },
                );
              }).toList(),
            ),
            ListTile(
              title: const Text('AI Help Level'),
              trailing: DropdownButton<AiHelpLevel>(
                value: settings.aiHelpLevel,
                items: const [
                  DropdownMenuItem(
                    value: AiHelpLevel.full,
                    child: Text('Full Suggestions'),
                  ),
                  DropdownMenuItem(
                    value: AiHelpLevel.grammar,
                    child: Text('Grammar Only'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) settings.setAiHelpLevel(val);
                },
              ),
            ),

            const Divider(),

            // --- Support & Legal ---
            ListTile(
              title: const Text('Help Center / Contact Us'),
              subtitle: const Text('support@chaptr.example'),
              onTap: () => _showSupportDialog(
                'Contact Support',
                'Email: support@chaptr.example',
              ),
            ),
            ListTile(
              title: const Text('Privacy Policy'),
              onTap: () => _showSupportDialog(
                'Privacy Policy',
                'https://chaptr.example/privacy',
              ),
            ),
            ListTile(
              title: const Text('Terms of Service'),
              onTap: () => _showSupportDialog(
                'Terms of Service',
                'https://chaptr.example/terms',
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: Text(
                'App Version v1.0.0',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),
            // Logout Button (prominent)
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
        );
      },
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
            child: Text(
              "Log Out",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
