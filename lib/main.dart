import 'package:brightpath/display/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'display/mainscreen/dashboard.dart';
import 'display/mainscreen/sidebar/admin_configuration.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");

    print("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Check if Firebase is initialized
    if (Firebase.apps.isNotEmpty) {
      print("Firebase initialized successfully.");
    } else {
      throw Exception('Firebase failed to initialize.');
    }


    // Once everything is initialized, start the app
    runApp(const MyApp());
  } catch (e) {
    // Catch any initialization error
    print("Error during initialization: $e");

    // Show an error message in case of failure
    runApp(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Text('Initialization Error: $e'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BrightPath',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: const Color(0xFF1A237E),
        cardColor: Colors.indigo.shade800,
        canvasColor: const Color(0xFF0A0E21),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E21),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A0E21),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: user == null ? LoginScreen() : const DashboardScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/admin': (context) => const AdminUserManagementScreen(),
        // Add other screens here
      },
    );
  }
}
