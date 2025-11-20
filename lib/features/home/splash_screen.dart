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
    Timer(const Duration(milliseconds: 2550), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFFD9CBBE); // Usa el de tu app o el que prefieras

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen del personaje, centrada y en círculo
            CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/images/lumi.jpg'), // Usa png si tienes, mejor transparencia
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(height: 30),
            // Nombre de Lumi
            const Text(
              "Lumi",
              style: TextStyle(
                fontFamily: "Nunito", // O la fuente principal de tu app
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C4459),
                letterSpacing: 2
              ),
            ),
            const SizedBox(height: 20),
            // Círculo de carga animado
            const CircularProgressIndicator(
              color: Color(0xFF2C4459),
              strokeWidth: 4.5,
            ),
          ],
        ),
      ),
    );
  }
}
