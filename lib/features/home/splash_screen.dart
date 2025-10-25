import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2, milliseconds: 550), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity, // Ocupar todo el ancho
        height: double.infinity, // Ocupar todo el alto
        child: Image.asset(
          'assets/images/lumi.jpg',
          fit: BoxFit.cover, // Ajustar la imagen para cubrir todo el espacio
        ),
      ),
    );
  }
}
