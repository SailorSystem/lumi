// c:\Users\User\CODIGOS\Lumi\lumi_app\lib\widgets\lumi_char.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LumiChar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final Function(String message)? onMessage;

  const LumiChar({
    super.key,
    this.size = 84,
    this.onTap,
    this.onMessage,
  });

  @override
  State<LumiChar> createState() => _LumiCharState();
}

class _LumiCharState extends State<LumiChar> {
  final audioPlayer = AudioPlayer();

  final List<String> _motivationalMessages = [
    '¡Tú puedes lograrlo! 💪',
    'El éxito se construye día a día 📚',
    'Cada minuto cuenta 🕒',
    'El conocimiento es poder 🧠',
    'Un paso más cerca de tus metas ⭐',
  ];

  Future<void> _playSound() async {
    final prefs = await SharedPreferences.getInstance();
    final sonido = prefs.getBool('sound') ?? true;
    if (sonido) {
      try {
        await audioPlayer.play(AssetSource('sounds/pop.mp3'));
      } catch (_) {}
    }
  }

  void _triggerMessage() {
    final msg = _motivationalMessages[Random().nextInt(_motivationalMessages.length)];
    _playSound();
    widget.onMessage?.call(msg);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerMessage,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/lumi.png',
            fit: BoxFit.cover,  // 🔥 AHORA OCUPA TODO EL CÍRCULO
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
