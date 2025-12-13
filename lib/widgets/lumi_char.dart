import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/services/mood_service.dart';
import '../../core/services/audio_player_service.dart'; // 🔊 Reproductor controlado

class LumiChar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final Function(String message)? onMessage;
  final int? estadoAnimo; // recibe estado de ánimo

  const LumiChar({
    super.key,
    this.size = 84,
    this.onTap,
    this.onMessage,
    this.estadoAnimo,
  });

  @override
  State<LumiChar> createState() => _LumiCharState();
}

class _LumiCharState extends State<LumiChar> {

  Future<void> _triggerMessage() async {
    // Obtener estado de ánimo
    final estadoActual = widget.estadoAnimo ?? 2;
    final mensajes = MoodService.obtenerMensajesAnimo(estadoActual);
    final msg = mensajes[Random().nextInt(mensajes.length)];

    // 🔊 Reproducir sonido SOLO si está activado globalmente
    await AudioPlayerService.play("sounds/pop.mp3");

    // Enviar mensaje al padre
    widget.onMessage?.call(msg);

    // Ejecutar callback adicional
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
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
              // fallback si hay error cargando la imagen
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
}