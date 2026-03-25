import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;
  final VoidCallback? onProfileChanged;

  const ProfilePage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    this.onProfileChanged,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  XFile? _image;

  final ImagePicker _picker = ImagePicker();

  // Method to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', pickedFile.path);
      setState(() {
        _image = pickedFile;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path != null && path.isNotEmpty) {
      setState(() {
        _image = XFile(path);
      });
    }
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title page coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('About Us'),
        content: SingleChildScrollView(
          child: Text(
            'Expense Tracker is a lightweight personal finance app to track categories, transactions and daily to‑dos.\n\n'
            'Features include category-based spending breakdowns, a simple to-do calendar with recurring tasks, and local storage for your preferences and data.\n\n'
            'Your data is stored locally on your device using SharedPreferences. For feature requests or issues, use the Support option to contact us.',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('Close'))],
      ),
    );
  }

  Future<void> _showSupportDialog() async {
    const supportEmail = 'mehulchoudhary2307@gmail.com';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For support or feedback please email:'),
            SizedBox(height: 8),
            SelectableText(supportEmail, style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: supportEmail));
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email copied to clipboard')));
            },
            child: Text('Copy Email'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_name') ?? '';
    final email = prefs.getString('profile_email') ?? '';
    final gender = prefs.getString('profile_gender') ?? 'unspecified';

    final nameCtrl = TextEditingController(text: name);
    final emailCtrl = TextEditingController(text: email);
    String selGender = gender;

    final res = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Name')),
            SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email')),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selGender,
              items: [
                DropdownMenuItem(value: 'unspecified', child: Text('Unspecified')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => selGender = v ?? 'unspecified',
              decoration: InputDecoration(labelText: 'Gender'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
          TextButton(
              onPressed: () async {
                await prefs.setString('profile_name', nameCtrl.text.trim());
                await prefs.setString('profile_email', emailCtrl.text.trim());
                await prefs.setString('profile_gender', selGender);
                Navigator.pop(c, true);
              },
              child: Text('Save')),
        ],
      ),
    );
    if (res == true) {
      widget.onProfileChanged?.call();
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.person,
        'label': 'Edit Profile',
        'onTap': () => _showEditProfileDialog(),
      },
      {
        'icon': Icons.info_outline,
        'label': 'About Us',
        'onTap': () => _showAboutDialog(),
      },
      {
        'icon': Icons.support_agent,
        'label': 'Support',
        'onTap': () => _showSupportDialog(),
      },
      {
        'icon': Icons.settings,
        'label': 'Settings',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SettingsPage(
                    toggleTheme: widget.toggleTheme,
                    isDarkMode: widget.isDarkMode,
                  ),
            ),
          );
        },
      },
    ];

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount:
            items.length + 1, // Adding an extra item for the image section
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                          GestureDetector(
                            onTap: () {
                              if (_image != null) {
                                final imageProvider = FileImage(File(_image!.path));
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImagePreviewPage(image: imageProvider),
                                  ),
                                );
                              }
                            },
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: _image != null ? FileImage(File(_image!.path)) : null,
                              backgroundColor: _image != null ? Colors.transparent : Colors.grey.shade300,
                              child: _image == null ? Icon(Icons.person_outline, size: 60, color: Colors.white) : null,
                            ),
                          ),

                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt, color: Colors.green),
                      label: const Text(
                        'Change Profile Image',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // List of other items
          final item = items[index - 1]; // Adjust for image section
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ListTile(
              leading: Icon(item['icon'] as IconData, color: Colors.green),
              title: Text(item['label'] as String),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: item['onTap'] as void Function(),
            ),
          );
        },
      ),
    );
  }
}

class ImagePreviewPage extends StatelessWidget {
  final ImageProvider image;

  const ImagePreviewPage({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Image')),
      body: Center(
        child: InteractiveViewer(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Image(image: image, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
