// c:\Users\User\CODIGOS\Lumi\lumi_app\lib\features\stats\stats_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _bg = Color(0xFFD9CBBE);
  static const _bar = Color(0xFFB49D87);
  static const _primary = Color(0xFF2C4459);

  late SharedPreferences _prefs;
  bool _loading = true;

  DateTime? _registeredAt;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, int> _sessionsPerDay = {};
  int _totalSessions = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    _prefs = await SharedPreferences.getInstance();

    // cargar/establecer fecha de registro
    final reg = _prefs.getString('registered_at');
    if (reg == null) {
      _registeredAt = DateTime.now();
      await _prefs.setString('registered_at', _registeredAt!.toIso8601String());
    } else {
      _registeredAt = DateTime.tryParse(reg) ?? DateTime.now();
    }

    // cargar sesiones guardadas (clave usada en la app: 'completed_sessions')
    final sessionsJson = _prefs.getStringList('completed_sessions') ?? [];
    _sessions = sessionsJson.map((s) {
      try {
        return Map<String, dynamic>.from(json.decode(s));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.containsKey('fecha')).toList();

    _computeAggregates();
    setState(() => _loading = false);
  }

  void _computeAggregates() {
    _sessionsPerDay = {};
    _totalSessions = 0;
    final start = _registeredAt ?? DateTime.now();

    for (final s in _sessions) {
      final fechaStr = s['fecha'] as String?;
      if (fechaStr == null) continue;
      final d = DateTime.tryParse(fechaStr);
      if (d == null) continue;
      if (d.isBefore(start)) continue; // solo desde registro

      final key = _dayKey(d);
      _sessionsPerDay[key] = (_sessionsPerDay[key] ?? 0) + 1;
      _totalSessions++;
    }

    // asegurar orden cronológico (más reciente primero)
    final ordered = Map<String, int>.fromEntries(
      _sessionsPerDay.entries.toList()
        ..sort((a, b) => _parseDayKey(b.key).compareTo(_parseDayKey(a.key))),
    );
    _sessionsPerDay = ordered;
  }

  String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime _parseDayKey(String k) {
    final parts = k.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  String _prettyDayLabel(String key) {
    final d = _parseDayKey(key);
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final yesterdayKey = _dayKey(now.subtract(const Duration(days: 1)));
    if (key == todayKey) return 'Hoy';
    if (key == yesterdayKey) return 'Ayer';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: const Text('Estadísticas'), backgroundColor: _bar, centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Estadísticas',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Gradiente igual que Home, hasta el 75%
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFB6C9D6), // mar
                Color(0xFFE6DACA), // arena clara
                Color(0xFFD9CBBE), // arena suave
              ],
              stops: [0.0, 0.75, 1.0],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resumen', style: TextStyle(color: _primary, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statItem('Total sesiones', _totalSessions.toString(), _primary),
                              _statItem('Desde registro', _registeredAt != null ? _formatDate(_registeredAt!) : '-', Colors.black54),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sesiones por día', style: TextStyle(color: _primary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          if (_sessionsPerDay.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('Aún no hay sesiones registradas', style: TextStyle(color: Colors.black54))),
                            )
                          else
                            Column(
                              children: _sessionsPerDay.entries.map((e) {
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _bar,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        e.value.toString(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  title: Text(_prettyDayLabel(e.key), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Fecha: ${e.key}', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detalle de sesiones', style: TextStyle(color: _primary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (_sessions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: Text('No hay sesiones guardadas')),
                            )
                          else
                            Column(
                              children: _sessions.map((s) {
                                final titulo = s['titulo'] ?? 'Sesión';
                                final metodo = s['metodo'] ?? '-';
                                final fecha = DateTime.tryParse(s['fecha'] ?? '') ;
                                final hora = fecha != null ? '${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')}' : '-';
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Método: $metodo • Hora: $hora'),
                                  trailing: Text(fecha != null ? '${fecha.day}/${fecha.month}/${fecha.year}' : ''),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Actualizar estadísticas'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}