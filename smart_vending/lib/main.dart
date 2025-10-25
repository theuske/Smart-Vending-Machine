import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/front_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartVendingApp());
}

class SmartVendingApp extends StatelessWidget {
  const SmartVendingApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF2E6F55);
    return MaterialApp(
      title: 'Smart Vending',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandGreen),
        useMaterial3: true,
      ),
      home: const FrontPage(),
    );
  }
}
