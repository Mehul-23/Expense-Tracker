import 'package:expense_tracker/home_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: Colors.teal).primary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: ColorScheme.fromSeed(seedColor: Colors.teal).secondary,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: ColorScheme.fromSeed(seedColor: Colors.teal).primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          showUnselectedLabels: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        scaffoldBackgroundColor: Color(0xFF0B0B0B),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark).surface,
          elevation: 0,
          centerTitle: false,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark).secondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF111111),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: Color(0xFF121212),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark).primary,
          unselectedItemColor: Colors.grey,
          backgroundColor: Color(0xFF0B0B0B),
        ),
      ),
      home: HomePage(
        toggleTheme: toggleTheme,
        isDarkMode: isDarkMode,
      ),
    );
  }
}
