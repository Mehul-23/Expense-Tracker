import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  const SettingsPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListTile(
        leading: Icon(Icons.dark_mode),
        title: Text('Dark Mode'),
        trailing: Switch(
          value: _darkMode,
          onChanged: (value) {
            setState(() => _darkMode = value);
            widget.toggleTheme(value);
          },
        ),
      ),
    );
  }
}
