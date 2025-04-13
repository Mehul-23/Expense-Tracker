import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'settings.dart';

class ProfilePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  const ProfilePage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
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
      setState(() {
        _image = pickedFile;
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

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.receipt_long,
        'label': 'All Transactions',
        'onTap': () => _showComingSoon(context, 'All Transactions'),
      },
      {
        'icon': Icons.currency_exchange,
        'label': 'Currency',
        'onTap': () => _showComingSoon(context, 'Currency'),
      },
      {
        'icon': Icons.info_outline,
        'label': 'About Us',
        'onTap': () => _showComingSoon(context, 'About Us'),
      },
      {
        'icon': Icons.support_agent,
        'label': 'Support',
        'onTap': () => _showComingSoon(context, 'Support'),
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
                        final imageProvider =
                            _image != null
                                ? FileImage(File(_image!.path))
                                : AssetImage('assets/image/profile_image.jpg')
                                    as ImageProvider;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ImagePreviewPage(image: imageProvider),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 60, // or bigger if you want
                        backgroundImage:
                            _image != null
                                ? FileImage(File(_image!.path))
                                : AssetImage('assets/image/profile_image.jpg')
                                    as ImageProvider,
                        backgroundColor: Colors.green.shade200,
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
