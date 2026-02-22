import 'dart:convert';
import 'package:expense_tracker/activityDetailPage.dart';
import 'package:expense_tracker/categoryDetailPage.dart';
import 'package:expense_tracker/profile.dart';
import 'package:expense_tracker/categoryPiePage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;

  const HomePage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;
  List<Map<String, dynamic>> _categories = [];
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _homeSearchController = TextEditingController();
  String _homeQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _homeSearchController.dispose();
    super.dispose();
  }

  void _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    String? categoriesJson = prefs.getString('categories');

    if (categoriesJson != null) {
      List<dynamic> categoriesList = json.decode(categoriesJson);
      setState(() {
        _categories = categoriesList.map((category) {
          final map = Map<String, dynamic>.from(category);
          // if icon was saved as a codePoint (int), reconstruct IconData
          final iconVal = map['icon'];
          if (iconVal is int) {
            map['icon'] = IconData(iconVal, fontFamily: 'MaterialIcons');
          }
          return map;
        }).toList();
      });
    }
  }

  void _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert any IconData to a serializable representation (codePoint)
    final serializable = _categories.map((c) {
      final icon = c['icon'];
      final iconCode = icon is IconData ? icon.codePoint : icon;
      return {
        'icon': iconCode,
        'label': c['label'],
        'transactions': c['transactions'],
      };
    }).toList();

    String categoriesJson = json.encode(serializable);
    await prefs.setString('categories', categoriesJson);
  }

  void _addCategory(String label) {
    setState(() {
      _categories.add({
        'icon': _getIconForCategory(label),
        'label': label,
        'transactions': [],
      });
    });
    _saveCategories();
    _categoryController.clear();
  }

  void _confirmDeleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text(
          'Do you really want to delete "${category['label']}" and all its transactions?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _categories.remove(category);
              });
              await prefs.remove(category['label']); // Remove transaction data
              _saveCategories();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Add New Category'),
        content: TextField(
          controller: _categoryController,
          decoration: InputDecoration(
            hintText: 'Enter category name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              if (_categoryController.text.isNotEmpty) {
                _addCategory(_categoryController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ActivityPage(),
      _buildHome(),
      ProfilePage(
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello Mehul'),
        actions: [
          IconButton(
            tooltip: 'Category breakdown',
            icon: Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryPiePage()),
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      floatingActionButton:
          _currentIndex == 1
              ? FloatingActionButton(
                onPressed: _showAddCategoryDialog,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.add),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Activity',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final filtered = _homeQuery.trim().isEmpty
        ? _categories
        : _categories.where((c) => (c['label'] ?? '').toString().toLowerCase().contains(_homeQuery.toLowerCase())).toList();

    return filtered.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No categories yet!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: Icon(Icons.add),
                label: Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        )
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _homeSearchController,
                decoration: InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _homeQuery = v),
              ),
              SizedBox(height: 12),
              Text(
                'Category Wise Spending',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ...filtered.map(
                (item) => Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(item['icon'], color: Colors.green),
                    title: Text(item['label']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.bar_chart, color: Colors.green),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => CategoryDetailPage(
                                      label: item['label'],
                                      icon: item['icon'],
                                      transactions: item['transactions'],
                                    ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _confirmDeleteCategory(item),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CategoryDetailPage(
                                label: item['label'],
                                icon: item['icon'],
                                transactions: item['transactions'],
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

IconData _getIconForCategory(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('food') || lower.contains('Food')) {
    return Icons.fastfood;
  }
  if (lower.contains('medical') ||
      lower.contains('Medical') ||
      lower.contains('medicine') ||
      lower.contains('medicines') ||
      lower.contains('Hospital') ||
      lower.contains('hospital') ||
      lower.contains('health') ||
      lower.contains('doctor') ||
      lower.contains('Health') ||
      lower.contains('Doctor')) {
    return Icons.medical_information;
  }
  if (lower.contains('rent') ||
      lower.contains('Rent') ||
      lower.contains('home') ||
      lower.contains('Home') ||
      lower.contains('house') ||
      lower.contains('House')) {
    return Icons.home;
  }
  if (lower.contains('investment') ||
      lower.contains('stock') ||
      lower.contains('Investment') ||
      lower.contains('Stock') ||
      lower.contains('Investments') ||
      lower.contains('Stocks')) {
    return Icons.trending_up;
  }
  if (lower.contains('grocery') ||
      lower.contains('shopping') ||
      lower.contains('Grocery') ||
      lower.contains('Shopping') ||
      lower.contains('groceries') ||
      lower.contains('Groceries')) {
    return Icons.shopping_cart;
  }
  if (lower.contains('travel') ||
      lower.contains('trip') ||
      lower.contains('Travel') ||
      lower.contains('Trip') ||
      lower.contains('Outing') ||
      lower.contains('outing') ||
      lower.contains('picnic') ||
      lower.contains('Picnic')) {
    return Icons.card_travel;
  }
  if (lower.contains('bill') ||
      lower.contains('Bill') ||
      lower.contains('bills') ||
      lower.contains('Bills')) {
    return Icons.receipt_long;
  }
  if (lower.contains('entertainment') ||
      lower.contains('Entertainment') ||
      lower.contains('movie') ||
      lower.contains('Movie')) {
    return Icons.emoji_emotions;
  }
  if (lower.contains('salary') ||
      lower.contains('income') ||
      lower.contains('Salary') ||
      lower.contains('Income') ||
      lower.contains('profit') ||
      lower.contains('Profit') ||
      lower.contains('profits') ||
      lower.contains('Profits')) {
    return Icons.attach_money;
  }
  return Icons.category;
}
