import 'package:flutter/material.dart';
import '../core/services/connectivity_service.dart'; // ajusta ruta si hace falta

Future<void> showNoConnectionDialog(
  BuildContext context, {
  String message = 'Revisa tu conexión a internet y vuelve a intentarlo.',
}) async {
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isChecking = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final theme = Theme.of(ctx);

          Future<void> _onRetry() async {
            if (isChecking) return;
            setState(() => isChecking = true);

            final ok = await ConnectivityService.verificarConexion();
            if (ok) {
              Navigator.of(ctx).pop(); // ✅ solo se cierra si volvió internet
            } else {
              setState(() => isChecking = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: theme.cardColor,
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 90,
                  child: Image.asset(
                    'assets/images/lumi_offline.png', 
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin conexión',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                if (isChecking) ...[
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(strokeWidth: 2.5),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: isChecking ? null : _onRetry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(isChecking ? 'Comprobando...' : 'Reintentar'),
              ),
            ],
          );
        },
      );
    },
  );
}
