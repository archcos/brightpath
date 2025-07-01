import 'package:brightpath/display/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Supabase Login Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(), // Route to the LoginScreen
    );
  }
}
