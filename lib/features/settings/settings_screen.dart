import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/usuario_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/sound_service.dart';

class SettingsScreen extends StatefulWidget {
  final int idUsuario;

  const SettingsScreen({super.key, required this.idUsuario});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'Usuario';
  bool _changedForHome = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = await UsuarioService.obtenerNombre(widget.idUsuario);
    
    setState(() {
      _userName = nombre ?? prefs.getString('user_name') ?? 'Usuario';
    });
  }

  Future<void> _updateName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);

    final ok = await UsuarioService.actualizarNombre(widget.idUsuario, newName);

    if (!ok) {
      print("❌ Error al actualizar nombre en Supabase");
    }

    setState(() {
      _userName = newName;
      _changedForHome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primaryColor = themeProvider.primaryColor;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changedForHome);
        return false;
      },
      child: Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryColor),
            onPressed: () => Navigator.pop(context, _changedForHome),
          ),
          title: const Text('Ajustes'),
          titleTextStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF212C36),
                        const Color(0xFF313940),
                        themeProvider.backgroundColor,
                      ]
                    : [
                        const Color(0xFFB6C9D6),
                        const Color(0xFFE6DACA),
                        themeProvider.backgroundColor,
                      ],
                stops: const [0.0, 0.75, 1.0],
              ),
            ),
          ),
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ✨ SECCIÓN DE PERFIL - Grande y destacada
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar grande
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 42,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Nombre
                        Text(
                          _userName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Usuario de Lumi',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Botón editar
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) => _NameEditDialog(
                                initialName: _userName,
                                primary: primaryColor,
                                cardColor: cardColor,
                              ),
                            );
                            if (result != null) await _updateName(result);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Editar nombre'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ✨ SECCIÓN DE APARIENCIA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Apariencia',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          secondary: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: primaryColor,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            'Modo Oscuro',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            isDark ? 'Activo' : 'Desactivado',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          value: isDark,
                          activeColor: primaryColor,
                          onChanged: (value) async {
                            await themeProvider.toggleTheme(value);
                            _changedForHome = true;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ✨ SONIDO — NUEVA SECCIÓN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Sonido',
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    FutureBuilder<bool>(
                      future: SoundService.isSoundEnabled(),
                      builder: (context, snapshot) {
                        bool soundOn = snapshot.data ?? true;

                        return Card(
                          color: cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              secondary: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.volume_up,
                                  color: primaryColor,
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                'Sonido',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                soundOn ? 'Activado' : 'Desactivado',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                              value: soundOn,
                              activeColor: primaryColor,
                              onChanged: (value) async {
                                await SoundService.setSoundEnabled(value);
                                setState(() {});
                                _changedForHome = true;
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ✨ INFO ADICIONAL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  color: primaryColor.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Los cambios se guardan automáticamente',
                            style: TextStyle(
                              color: textColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameEditDialog extends StatefulWidget {
  final String initialName;
  final Color primary;
  final Color cardColor;
  
  const _NameEditDialog({
    required this.initialName,
    required this.primary,
    required this.cardColor,
    Key? key,
  }) : super(key: key);

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.edit, color: widget.primary),
          const SizedBox(width: 12),
          const Text('Cambiar nombre'),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Nombre',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.primary, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: widget.primary.withOpacity(0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
