// c:\Users\User\CODIGOS\Lumi\lumi_app\lib\widgets\lumi_char.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class LumiChar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const LumiChar({
    super.key,
    this.size = 84,
    this.onTap,
  });

  @override
  State<LumiChar> createState() => _LumiCharState();
}

class _LumiCharState extends State<LumiChar> {
  final audioPlayer = AudioPlayer();
  OverlayEntry? _overlayEntry;

  final List<String> _motivationalMessages = [
    '¡Tú puedes lograrlo! 💪',
    'El éxito se construye día a día 📚',
    'Cada minuto cuenta 🕒',
    'El conocimiento es poder 🧠',
    'Un paso más cerca de tus metas ⭐',
  ];

  Future<void> _playSound() async {
    try {
      await audioPlayer.play(AssetSource('sounds/pop.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _showMotivationalMessage(BuildContext context, Offset tapPosition) {
    _hideOverlay();
    
    final random = Random();
    final message = _motivationalMessages[random.nextInt(_motivationalMessages.length)];
    
    _playSound();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: tapPosition.dx + widget.size,
        top: tapPosition.dy - widget.size,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _hideOverlay,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _showMotivationalMessage(context, details.globalPosition);
        widget.onTap?.call();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(widget.size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Image.asset(
            'assets/images/lumi_char.jpg',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
