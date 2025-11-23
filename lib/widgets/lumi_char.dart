import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/mood_service.dart';

class LumiChar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final Function(String message)? onMessage;
  final int? estadoAnimo; // ✅ NUEVO: recibir el estado de ánimo

  const LumiChar({
    super.key,
    this.size = 84,
    this.onTap,
    this.onMessage,
    this.estadoAnimo, // ✅ NUEVO
  });

  @override
  State<LumiChar> createState() => _LumiCharState();
}

class _LumiCharState extends State<LumiChar> {
  final _audioPlayer = AudioPlayer();

  Future<void> _playSound() async {
    final prefs = await SharedPreferences.getInstance();
    final sonido = prefs.getBool('sound') ?? true;

    if (sonido) {
      try {
        await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
      } catch (_) {}
    }
  }

  void _triggerMessage() {
    // ✅ Usar el estado de ánimo para obtener mensajes apropiados
    final estadoActual = widget.estadoAnimo ?? 2;
    final mensajes = MoodService.obtenerMensajesAnimo(estadoActual);
    final msg = mensajes[Random().nextInt(mensajes.length)];
    
    _playSound();
    widget.onMessage?.call(msg);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Usar el estado de ánimo para determinar la imagen
    final estadoActual = widget.estadoAnimo ?? 2;
    final imagePath = MoodService.obtenerImagenAnimo(estadoActual);
    
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              // Fallback a la imagen por defecto si hay error
              return Image.asset(
                'assets/images/lumi.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
