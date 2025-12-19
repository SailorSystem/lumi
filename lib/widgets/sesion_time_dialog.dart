//lib/widgets/sesion_time_dialog.dart
import 'package:flutter/material.dart';

class SesionTimeDialog extends StatelessWidget {
  final String nombreSesion;
  final DateTime fechaLocal;
  final VoidCallback? onStart;
  final VoidCallback? onSnooze;

  const SesionTimeDialog({
    super.key,
    required this.nombreSesion,
    required this.fechaLocal,
    this.onStart,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final hh = fechaLocal.hour.toString().padLeft(2, '0');
    final mm = fechaLocal.minute.toString().padLeft(2, '0');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("⏰ Sesión por iniciar"),
      content: Text(
        'Tu sesión "$nombreSesion" está programada para las $hh:$mm.\n\n'
        'Falta menos de 1 minuto. ¿Quieres empezarla ahora?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onSnooze?.call();
          },
          child: const Text("Posponer"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onStart?.call();
          },
          child: const Text("Iniciar"),
        ),
      ],
    );
  }
}

Future<void> showSesionTimeDialog(
  BuildContext context, {
  required String nombreSesion,
  required DateTime fechaLocal,
  VoidCallback? onStart,
  VoidCallback? onSnooze,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SesionTimeDialog(
      nombreSesion: nombreSesion,
      fechaLocal: fechaLocal,
      onStart: onStart,
      onSnooze: onSnooze,
    ),
  );
}