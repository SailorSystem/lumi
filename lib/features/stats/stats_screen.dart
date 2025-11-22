import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/sesion_service.dart';
import '../../core/services/usuario_service.dart';
import '../../core/models/sesion.dart';
import '../../core/models/usuario.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  StatsScreenState createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  bool loading = true;
  int? userId;
  
  // Sesiones
  List<Sesion> todasSesiones = [];
  List<Sesion> sesionesFiltradas = [];
  
  // Estadísticas
  int totalProgramadas = 0;
  int totalRapidas = 0;
  int totalSesiones = 0;
  
  // Filtros
  String ordenSeleccionado = 'Más reciente';
  String tipoSeleccionado = 'Todas';
  
  // Paginación
  int sesionesVisibles = 10;
  final int sesionesPorPagina = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadStats();
    });
  }

  Future<void> loadStats() async {
    print('🔄 Iniciando carga de estadísticas...');
    setState(() => loading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userid');
      
      print('👤 UserID desde SharedPreferences: $userId');
      
      // Si no hay userId o no tiene sesiones, buscar el usuario con sesiones
      if (userId == null) {
        print('🔍 Buscando usuario en Supabase...');
        try {
          final usuarios = await UsuarioService.getTodos();
          if (usuarios.isNotEmpty) {
            userId = usuarios.first.idUsuario;
            await prefs.setInt('userid', userId!);
            print('✅ Usuario encontrado en Supabase: $userId');
          }
        } catch (e) {
          print('❌ Error obteniendo usuarios: $e');
        }
      }
      
      if (userId == null) {
        print('⚠️ No hay userId disponible, saliendo...');
        setState(() => loading = false);
        return;
      }

      // CARGAR TODAS LAS SESIONES DEL USUARIO
      try {
        print('🌐 Cargando todas las sesiones desde Supabase con userId=$userId...');
        
        final response = await Supabase.instance.client
            .from('sesiones')
            .select()
            .eq('id_usuario', userId!);
        
        print('📦 Respuesta de Supabase: ${response.length} sesiones encontradas');
        
        // Si no hay sesiones con este userId, buscar cualquier sesión del sistema
        if (response.isEmpty) {
          print('⚠️ No hay sesiones para userId=$userId');
          print('🔍 Buscando cualquier sesión en el sistema...');
          
          final allSessions = await Supabase.instance.client
              .from('sesiones')
              .select()
              .limit(1);
          
          if (allSessions.isNotEmpty) {
            final correctUserId = allSessions.first['id_usuario'] as int;
            print('✅ Encontradas sesiones del usuario $correctUserId');
            print('🔄 Actualizando userId a $correctUserId');
            
            userId = correctUserId;
            await prefs.setInt('userid', correctUserId);
            
            // Volver a cargar con el userId correcto
            final correctResponse = await Supabase.instance.client
                .from('sesiones')
                .select()
                .eq('id_usuario', userId!);
            
            print('📦 Sesiones del usuario correcto: ${correctResponse.length}');
            
            todasSesiones = [];
            for (var json in correctResponse) {
              try {
                final sesion = Sesion(
                  idSesion: json['id_sesion'] as int?,
                  idUsuario: json['id_usuario'] as int? ?? userId!,
                  idMetodo: json['id_metodo'] as int?,
                  idTema: json['id_tema'] as int?,
                  nombreSesion: json['nombre_sesion'] as String? ?? 'Sesión',
                  fecha: DateTime.parse(json['fecha'] as String),
                  esRapida: json['es_rapida'] as bool? ?? false,
                  duracionTotal: json['duracion_total'] as int?,
                  estado: json['estado'] as String? ?? 'programada',
                );
                todasSesiones.add(sesion);
                print('✅ Sesión cargada: ${sesion.nombreSesion} (${sesion.estado})');
              } catch (e) {
                print('❌ Error parseando sesión: $e');
              }
            }
          }
        } else {
          // Hay sesiones, procesarlas normalmente
          todasSesiones = [];
          for (var json in response) {
            try {
              final sesion = Sesion(
                idSesion: json['id_sesion'] as int?,
                idUsuario: json['id_usuario'] as int? ?? userId!,
                idMetodo: json['id_metodo'] as int?,
                idTema: json['id_tema'] as int?,
                nombreSesion: json['nombre_sesion'] as String? ?? 'Sesión',
                fecha: DateTime.parse(json['fecha'] as String),
                esRapida: json['es_rapida'] as bool? ?? false,
                duracionTotal: json['duracion_total'] as int?,
                estado: json['estado'] as String? ?? 'programada',
              );
              todasSesiones.add(sesion);
              print('✅ Sesión cargada: ${sesion.nombreSesion} (${sesion.estado})');
            } catch (e) {
              print('❌ Error parseando sesión: $e');
            }
          }
        }
        
        print('✅ Total de sesiones cargadas desde Supabase: ${todasSesiones.length}');
      } catch (e) {
        print('❌ Error Supabase: $e');
        todasSesiones = [];
      }
      
      // Resto del código permanece igual...
      // Calcular estadísticas
      totalSesiones = todasSesiones.length;
      totalProgramadas = todasSesiones.where((s) => !s.esRapida).length;
      totalRapidas = todasSesiones.where((s) => s.esRapida).length;
      
      print('📊 ESTADÍSTICAS FINALES:');
      print('   Total: $totalSesiones');
      print('   Programadas: $totalProgramadas');
      print('   Rápidas: $totalRapidas');
      
      aplicarFiltros();
    } catch (e) {
      print('💥 ERROR GENERAL cargando stats: $e');
    }
    
    setState(() => loading = false);
    print('✅ Carga completada\n');
  }


  void aplicarFiltros() {
    print('🔍 Aplicando filtros: $tipoSeleccionado, $ordenSeleccionado');
    
    // Filtrar por tipo
    if (tipoSeleccionado == 'Todas') {
      sesionesFiltradas = List.from(todasSesiones);
    } else if (tipoSeleccionado == 'Programadas') {
      sesionesFiltradas = todasSesiones.where((s) => !s.esRapida).toList();
    } else if (tipoSeleccionado == 'Rápidas') {
      sesionesFiltradas = todasSesiones.where((s) => s.esRapida).toList();
    }
    
    // Ordenar
    if (ordenSeleccionado == 'Más reciente') {
      sesionesFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));
    } else if (ordenSeleccionado == 'Más antiguo') {
      sesionesFiltradas.sort((a, b) => a.fecha.compareTo(b.fecha));
    }
    
    print('✅ Sesiones filtradas: ${sesionesFiltradas.length}');
    
    // Resetear paginación
    sesionesVisibles = sesionesPorPagina;
  }

  void cargarMasSesiones() {
    setState(() {
      sesionesVisibles += sesionesPorPagina;
      print('📄 Mostrando $sesionesVisibles de ${sesionesFiltradas.length}');
    });
  }

  List<FlSpot> obtenerDatosGrafico() {
    if (todasSesiones.isEmpty) return [];
    
    // Agrupar sesiones por fecha
    Map<String, int> sesionesPorDia = {};
    
    for (var sesion in todasSesiones) {
      String key = '${sesion.fecha.year}-${sesion.fecha.month.toString().padLeft(2, '0')}-${sesion.fecha.day.toString().padLeft(2, '0')}';
      sesionesPorDia[key] = (sesionesPorDia[key] ?? 0) + 1;
    }
    
    // Ordenar por fecha y obtener últimos 7 días
    var sortedKeys = sesionesPorDia.keys.toList()..sort();
    var last7Days = sortedKeys.length > 7 ? sortedKeys.sublist(sortedKeys.length - 7) : sortedKeys;
    
    List<FlSpot> spots = [];
    for (int i = 0; i < last7Days.length; i++) {
      spots.add(FlSpot(i.toDouble(), sesionesPorDia[last7Days[i]]!.toDouble()));
    }
    
    print('📈 Gráfico con ${spots.length} puntos');
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bg = themeProvider.backgroundColor;
    final appBarCol = themeProvider.appBarColor;
    final primary = themeProvider.primaryColor;
    final cardColor = themeProvider.cardColor;
    final textColor = themeProvider.textColor;

    if (loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Estadísticas'),
          backgroundColor: appBarCol,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Cargando estadísticas...',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Estadísticas',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeProvider.isDarkMode
                  ? [
                      const Color(0xFF212C36),
                      const Color(0xFF313940),
                      bg,
                    ]
                  : [
                      const Color(0xFFB6C9D6),
                      const Color(0xFFE6DACA),
                      bg,
                    ],
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildResumenCard(cardColor, textColor, primary),
              const SizedBox(height: 20),
              _buildGraficoCard(cardColor, textColor, primary),
              const SizedBox(height: 20),
              _buildHistorialSection(cardColor, textColor, primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenCard(Color cardColor, Color textColor, Color primary) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Total', totalSesiones.toString(), primary, Icons.library_books),
                _statItem('Programadas', totalProgramadas.toString(), Colors.blue, Icons.event),
                _statItem('Rápidas', totalRapidas.toString(), Colors.orange, Icons.flash_on),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoCard(Color cardColor, Color textColor, Color primary) {
    final spots = obtenerDatosGrafico();
    
    // Obtener las fechas para las etiquetas
    Map<String, int> sesionesPorDia = {};
    for (var sesion in todasSesiones) {
      String key = '${sesion.fecha.year}-${sesion.fecha.month.toString().padLeft(2, '0')}-${sesion.fecha.day.toString().padLeft(2, '0')}';
      sesionesPorDia[key] = (sesionesPorDia[key] ?? 0) + 1;
    }
    var sortedKeys = sesionesPorDia.keys.toList()..sort();
    var last7Days = sortedKeys.length > 7 ? sortedKeys.sublist(sortedKeys.length - 7) : sortedKeys;
    
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progreso de Sesiones',
              style: TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? Center(
                      child: Text(
                        'No hay datos suficientes',
                        style: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0, // ✅ Forzar que empiece en 0
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1, // ✅ Mostrar solo números enteros
                              getTitlesWidget: (value, meta) {
                                if (value < 0) return const SizedBox(); // ✅ No mostrar negativos
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(color: textColor, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1, // ✅ Asegurar que cada punto tenga su etiqueta
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= last7Days.length) {
                                  return const SizedBox();
                                }
                                // Mostrar día del mes
                                final fecha = DateTime.parse(last7Days[index]);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${fecha.day}/${fecha.month}',
                                    style: TextStyle(color: textColor, fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false, // ✅ LÍNEAS RECTAS
                            color: primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: primary,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: primary.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialSection(Color cardColor, Color textColor, Color primary) {
    final sesionesAMostrar = sesionesFiltradas.take(sesionesVisibles).toList();
    final hayMas = sesionesVisibles < sesionesFiltradas.length;
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial de Sesiones', style: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withOpacity(0.3))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: ordenSeleccionado, isExpanded: true, icon: Icon(Icons.sort, color: primary), dropdownColor: cardColor, style: TextStyle(color: textColor, fontSize: 14), items: ['Más reciente', 'Más antiguo'].map((orden) => DropdownMenuItem(value: orden, child: Text(orden))).toList(), onChanged: (value) { setState(() { ordenSeleccionado = value!; aplicarFiltros(); }); })))),
                const SizedBox(width: 12),
                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withOpacity(0.3))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: tipoSeleccionado, isExpanded: true, icon: Icon(Icons.filter_alt, color: primary), dropdownColor: cardColor, style: TextStyle(color: textColor, fontSize: 14), items: ['Todas', 'Programadas', 'Rápidas'].map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))).toList(), onChanged: (value) { setState(() { tipoSeleccionado = value!; aplicarFiltros(); }); })))),
              ],
            ),
            const SizedBox(height: 16),
            if (sesionesAMostrar.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No hay sesiones para mostrar', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16)))) else ...sesionesAMostrar.map((sesion) => _buildSesionItem(sesion, textColor, primary)),
            if (hayMas) Center(child: Padding(padding: const EdgeInsets.only(top: 12), child: ElevatedButton.icon(onPressed: cargarMasSesiones, icon: const Icon(Icons.expand_more), label: const Text('Cargar más'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))))),
          ],
        ),
      ),
    );
  }

  Widget _buildSesionItem(Sesion sesion, Color textColor, Color primary) {
    final fecha = '${sesion.fecha.day.toString().padLeft(2, '0')}/${sesion.fecha.month.toString().padLeft(2, '0')}/${sesion.fecha.year}';
    final hora = '${sesion.fecha.hour.toString().padLeft(2, '0')}:${sesion.fecha.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12), // ✅ Reducido de 14 a 12
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column( // ✅ Cambio de Row a Column para mejor manejo del espacio
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primera fila: Icono, nombre y estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8), // ✅ Reducido de 10 a 8
                decoration: BoxDecoration(
                  color: sesion.esRapida ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sesion.esRapida ? Icons.flash_on : Icons.event,
                  color: sesion.esRapida ? Colors.orange : Colors.blue,
                  size: 20, // ✅ Reducido de 22 a 20
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sesion.nombreSesion,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // ✅ Reducido
                decoration: BoxDecoration(
                  color: sesion.estado == 'concluida' || sesion.estado == 'finalizada'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sesion.estado == 'concluida' || sesion.estado == 'finalizada' ? 'Completada' : 'Programada',
                  style: TextStyle(
                    color: sesion.estado == 'concluida' || sesion.estado == 'finalizada' 
                        ? Colors.green 
                        : Colors.amber.shade800,
                    fontSize: 10, // ✅ Reducido de 11 a 10
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          // Segunda fila: Fecha y hora
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44), // ✅ Alineado con el texto del nombre
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: textColor.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  fecha,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 13, color: textColor.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  hora,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 8), Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)), Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500))]);
  }
}
