import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/usuario_service.dart';

import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/configuracion_service.dart';
import '../../core/models/configuracion.dart';

class SettingsScreen extends StatefulWidget {
  final int idUsuario;

  const SettingsScreen({super.key, required this.idUsuario});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> {
  // Paleta
  //static const _bg = Color(0xFFD9CBBE);
  //static const _bar = Color(0xFFB49D87);
  //static const _primary = Color(0xFF2C4459);

  String _userName = 'Usuario';
  //bool _isDarkMode = false;
  bool _notifications = true;
  bool _sound = true;

  bool _changedForHome = false; // para notificar al Home que refresque

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = await UsuarioService.obtenerNombre(widget.idUsuario);
    if (nombre != null) _userName = nombre;
    else _userName = prefs.getString('user_name') ?? 'Usuario';
    final config = await ConfiguracionService.obtenerPorUsuario(widget.idUsuario);
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _notifications = prefs.getBool('notifications') ?? true;
      _sound = prefs.getBool('sound') ?? true;
      //_isDarkMode = prefs.getBool('dark_mode') ?? false;
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
      _changedForHome = true;  // 🔥 indica que Home debe refrescar
    });
  }


  //Future<void> _updateBool(String key, bool value) async {
  //  final prefs = await SharedPreferences.getInstance();
  //  await prefs.setBool(key, value);
  //}

  Future<void> _updateConfig(String field, dynamic value) async {
    setState(() {
      if (field == 'notificaciones_activadas') _notifications = value as bool;
      if (field == 'sonido') _sound = value as bool;
    });

    // 2. Guardar en Supabase
    final config = await ConfiguracionService.obtenerPorUsuario(widget.idUsuario);

    if (config != null) {
      await ConfiguracionService.actualizarConfiguracion(config.idConfig!, {field: value});
    } else {
      final newConfig = Configuracion(
        idUsuario: widget.idUsuario,
        modoOscuro: Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
        notificacionesActivadas: field == 'notificaciones_activadas' ? value as bool : true,
        sonido: field == 'sonido' ? value as bool : true,
      );
      await ConfiguracionService.crearConfiguracion(newConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isDark = themeProvider.isDarkMode;
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;
    final primaryColor = themeProvider.primaryColor;
    final appBarColor = themeProvider.appBarColor;


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

        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const SizedBox(height: 8),

            // Perfil
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    _userName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Editar...'),
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => _NameEditDialog(
                          initialName: _userName,
                          primary: primaryColor,
                          bar: appBarColor,
                        ),
                      );
                      if (result != null) await _updateName(result);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Preferencias
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.dark_mode, color: primaryColor),
                      title: Text('Modo Oscuro',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      value: isDarkMode,
                      activeColor: primaryColor,
                      onChanged: (value) async {
                        await themeProvider.toggleTheme(value);
                        _changedForHome = true;
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(Icons.notifications, color: primaryColor),
                      title: Text('Notificaciones',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      value: _notifications,
                      activeColor: primaryColor,
                      onChanged: (value) => _updateConfig('notificaciones_activadas', value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(Icons.volume_up, color: primaryColor),
                      title: Text('Sonido',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                      value: _sound,
                      activeColor: primaryColor,
                      onChanged: (value) => _updateConfig('sonido', value),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Acciones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opciones guardadas')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Guardar cambios'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Restablecer ajustes'),
                          content: const Text('¿Deseas restablecer ajustes a su valor por defecto?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                            TextButton(
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('user_name');
                                await prefs.remove('notifications');
                                await prefs.remove('sound');
                                await prefs.remove('dark_mode');
                                await _loadSettings();
                                _changedForHome = true;
                                if (mounted) Navigator.pop(context);
                              },
                              child: const Text('Restablecer'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side:  BorderSide(color: appBarColor),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Restablecer ajustes'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NameEditDialog extends StatefulWidget {
  final String initialName;
  final Color primary;
  final Color bar;
  const _NameEditDialog({
    required this.initialName,
    required this.primary,
    required this.bar,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Cambiar nombre'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Nombre',
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.primary),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: widget.bar),
          child: const Text('Guardar'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
        ),
      ],
    );
  }
}
