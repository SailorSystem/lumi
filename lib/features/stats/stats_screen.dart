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
  
  // ✅ Estadísticas actualizadas
  int totalFinalizadas = 0;
  int totalIncompletas = 0;
  int totalRapidas = 0;
  int totalSesiones = 0;
  
  // Filtros
  String ordenSeleccionado = 'Más reciente';
  String tipoSeleccionado = 'Todas'; // ✅ Actualizado
  String filtroGrafico = 'Semana'; // Opciones: Semana, Mes, General

  // ✅ Lista de tipos de filtro
  final List<String> tiposFiltro = [
    'Todas',
    'Finalizadas',
    'Incompletas',
    'Rápidas',
  ];
  
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
    
    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('user_id');
      
      print('👤 UserID desde SharedPreferences: $userId');

      if (userId == null) {
        print('⚠️ No hay userId, buscando usuario en Supabase...');
        try {
          final usuarios = await UsuarioService.getTodos();
          if (usuarios.isNotEmpty) {
            userId = usuarios.first.idUsuario;
            await prefs.setInt('user_id', userId!);
            print('✅ Usuario encontrado en Supabase: $userId');
          }
        } catch (e) {
          print('❌ Error obteniendo usuarios: $e');
        }
      }

      if (userId == null) {
        print('❌ No hay userId disponible, saliendo...');
        setState(() {
          loading = false;
        });
        return;
      }

      // Limpiar datos antiguos
      todasSesiones = [];
      totalSesiones = 0;
      totalFinalizadas = 0;
      totalIncompletas = 0;
      totalRapidas = 0;

      // Cargar todas las sesiones desde Supabase
      try {
        print('🌐 Cargando todas las sesiones desde Supabase con userId=$userId...');
        
        final response = await Supabase.instance.client
            .from('sesiones')
            .select()
            .eq('id_usuario', userId!)
            .order('fecha', ascending: false);
        
        print('📦 Respuesta de Supabase: ${response.length} sesiones encontradas');

        for (var json in response) {
          try {
            final sesion = Sesion(
              idSesion: json['id_sesion'] as int?,
              idUsuario: json['id_usuario'] as int,
              idMetodo: json['id_metodo'] as int?,
              idTema: json['id_tema'] as int?,
              nombreSesion: json['nombre_sesion'] as String? ?? 'Sesión',
              fecha: DateTime.parse(json['fecha'] as String),
              esRapida: json['es_rapida'] as bool? ?? false,
              duracionTotal: json['duracion_total'] as int?,
              estado: json['estado'] as String? ?? 'programada',
            );
            
            todasSesiones.add(sesion);
            print('✅ Sesión cargada: ${sesion.nombreSesion} - Estado: ${sesion.estado} - Rápida: ${sesion.esRapida}');
          } catch (e) {
            print('❌ Error parseando sesión: $e');
          }
        }

        print('📊 Total de sesiones cargadas: ${todasSesiones.length}');
      } catch (e) {
        print('❌ Error Supabase: $e');
        todasSesiones = [];
      }

      // ✅ Calcular estadísticas
      totalSesiones = todasSesiones.length;
      totalFinalizadas = todasSesiones.where((s) => s.estado == 'finalizada').length;
      totalIncompletas = todasSesiones.where((s) => s.estado == 'incompleta').length;
      totalRapidas = todasSesiones.where((s) => s.esRapida).length;

      print('📈 ESTADÍSTICAS FINALES:');
      print('   Total: $totalSesiones');
      print('   Finalizadas: $totalFinalizadas');
      print('   Incompletas: $totalIncompletas');
      print('   Rápidas: $totalRapidas');

      aplicarFiltros();
    } catch (e) {
      print('❌ ERROR GENERAL cargando stats: $e');
    } finally {
      setState(() {
        loading = false;
      });
      print('✅ Carga completada');
    }
  }

  void aplicarFiltros() {
    print('🔍 Aplicando filtros: $tipoSeleccionado, $ordenSeleccionado');
    
    // ✅ Filtrar por tipo
    if (tipoSeleccionado == 'Todas') {
      sesionesFiltradas = List.from(todasSesiones);
    } else if (tipoSeleccionado == 'Finalizadas') {
      sesionesFiltradas = todasSesiones
          .where((s) => s.estado == 'finalizada')
          .toList();
    } else if (tipoSeleccionado == 'Incompletas') {
      sesionesFiltradas = todasSesiones
          .where((s) => s.estado == 'incompleta')
          .toList();
    } else if (tipoSeleccionado == 'Rápidas') {
      sesionesFiltradas = todasSesiones
          .where((s) => s.esRapida)
          .toList();
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
    
    final ahora = DateTime.now();
    DateTime fechaInicio;
    
    // ✅ Determinar rango según el filtro
    if (filtroGrafico == 'Semana') {
      fechaInicio = ahora.subtract(const Duration(days: 7));
    } else if (filtroGrafico == 'Mes') {
      fechaInicio = ahora.subtract(const Duration(days: 30));
    } else {
      // General: todos los datos
      fechaInicio = DateTime(2000); // Fecha muy antigua para incluir todo
    }
    
    // Filtrar sesiones por rango de fecha
    final sesionesFiltradas = todasSesiones
        .where((s) => s.fecha.isAfter(fechaInicio))
        .toList();
    
    if (sesionesFiltradas.isEmpty) return [];
    
    // Agrupar sesiones por fecha
    Map<String, int> sesionesPorDia = {};
    
    for (var sesion in sesionesFiltradas) {
      String key = '${sesion.fecha.year}-${sesion.fecha.month.toString().padLeft(2, '0')}-${sesion.fecha.day.toString().padLeft(2, '0')}';
      sesionesPorDia[key] = (sesionesPorDia[key] ?? 0) + 1;
    }
    
    // Ordenar por fecha
    var sortedKeys = sesionesPorDia.keys.toList()..sort();
    
    // Limitar puntos según filtro
    List<String> keysAMostrar;
    if (filtroGrafico == 'Semana') {
      keysAMostrar = sortedKeys.length > 7 
          ? sortedKeys.sublist(sortedKeys.length - 7) 
          : sortedKeys;
    } else if (filtroGrafico == 'Mes') {
      keysAMostrar = sortedKeys.length > 30 
          ? sortedKeys.sublist(sortedKeys.length - 30) 
          : sortedKeys;
    } else {
      // General: limitar a últimos 60 días para no saturar
      keysAMostrar = sortedKeys.length > 60 
          ? sortedKeys.sublist(sortedKeys.length - 60) 
          : sortedKeys;
    }
    
    List<FlSpot> spots = [];
    for (int i = 0; i < keysAMostrar.length; i++) {
      spots.add(FlSpot(i.toDouble(), sesionesPorDia[keysAMostrar[i]]!.toDouble()));
    }
    
    print('📈 Gráfico con ${spots.length} puntos (filtro: $filtroGrafico)');
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

  // ✅ Resumen actualizado con 4 estadísticas
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
            Text(
              'Resumen',
              style: TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Total', totalSesiones.toString(), primary, Icons.library_books),
                _statItem('Finalizadas', totalFinalizadas.toString(), Colors.green, Icons.check_circle),
                _statItem('Incompletas', totalIncompletas.toString(), Colors.orange, Icons.warning),
                _statItem('Rápidas', totalRapidas.toString(), Colors.blue, Icons.flash_on),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _filtroBoton(String filtro, Color primary, Color cardColor, Color textColor) {
    final esSeleccionado = filtroGrafico == filtro;
    
    return InkWell(
      onTap: () {
        setState(() {
          filtroGrafico = filtro;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: esSeleccionado ? primary : primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: esSeleccionado ? primary : primary.withOpacity(0.3),
            width: esSeleccionado ? 2 : 1,
          ),
        ),
        child: Text(
          filtro,
          style: TextStyle(
            color: esSeleccionado ? Colors.white : primary,
            fontWeight: esSeleccionado ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGraficoCard(Color cardColor, Color textColor, Color primary) {
    final spots = obtenerDatosGrafico();
    
    // Obtener las fechas para las etiquetas
    final ahora = DateTime.now();
    DateTime fechaInicio;
    
    if (filtroGrafico == 'Semana') {
      fechaInicio = ahora.subtract(const Duration(days: 7));
    } else if (filtroGrafico == 'Mes') {
      fechaInicio = ahora.subtract(const Duration(days: 30));
    } else {
      fechaInicio = DateTime(2000);
    }
    
    final sesionesFiltradas = todasSesiones
        .where((s) => s.fecha.isAfter(fechaInicio))
        .toList();
    
    Map<String, int> sesionesPorDia = {};
    for (var sesion in sesionesFiltradas) {
      String key = '${sesion.fecha.year}-${sesion.fecha.month.toString().padLeft(2, '0')}-${sesion.fecha.day.toString().padLeft(2, '0')}';
      sesionesPorDia[key] = (sesionesPorDia[key] ?? 0) + 1;
    }
    
    var sortedKeys = sesionesPorDia.keys.toList()..sort();
    
    List<String> keysAMostrar;
    if (filtroGrafico == 'Semana') {
      keysAMostrar = sortedKeys.length > 7 ? sortedKeys.sublist(sortedKeys.length - 7) : sortedKeys;
    } else if (filtroGrafico == 'Mes') {
      keysAMostrar = sortedKeys.length > 30 ? sortedKeys.sublist(sortedKeys.length - 30) : sortedKeys;
    } else {
      keysAMostrar = sortedKeys.length > 60 ? sortedKeys.sublist(sortedKeys.length - 60) : sortedKeys;
    }
    
    // ✅ Calcular el valor máximo para ajustar el intervalo del eje Y
    double maxY = 0;
    if (spots.isNotEmpty) {
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    }
    
    // ✅ Determinar intervalo dinámico para evitar sobreposición
    double intervalo = 1;
    if (maxY > 20) {
      intervalo = 5;
    } else if (maxY > 10) {
      intervalo = 2;
    } else if (maxY > 5) {
      intervalo = 1;
    }
    
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso de Sesiones',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // ✅ BOTONES DE FILTRO
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _filtroBoton('Semana', primary, cardColor, textColor),
                const SizedBox(width: 8),
                _filtroBoton('Mes', primary, cardColor, textColor),
                const SizedBox(width: 8),
                _filtroBoton('General', primary, cardColor, textColor),
              ],
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
                        minY: 0,
                        maxY: maxY + 1, // ✅ Agregar margen superior
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: intervalo,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35, // ✅ Reducido para evitar sobreposición
                              interval: intervalo, // ✅ Intervalo dinámico
                              getTitlesWidget: (value, meta) {
                                if (value < 0 || value % intervalo != 0) return const SizedBox();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11, // ✅ Reducido
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: filtroGrafico == 'General' 
                                  ? (keysAMostrar.length / 10).ceilToDouble() // ✅ Mostrar menos etiquetas en General
                                  : (filtroGrafico == 'Mes' ? 5 : 1), // Cada 5 días en Mes, todos en Semana
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= keysAMostrar.length) {
                                  return const SizedBox();
                                }
                                
                                final fecha = DateTime.parse(keysAMostrar[index]);
                                
                                // ✅ Formato según el filtro
                                String label;
                                if (filtroGrafico == 'General') {
                                  label = '${fecha.day}/${fecha.month}';
                                } else {
                                  label = '${fecha.day}/${fecha.month}';
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: filtroGrafico == 'General' ? -0.5 : 0, // ✅ Rotar si es General
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 9, // ✅ Reducido
                                      ),
                                    ),
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
                            isCurved: true, // ✅ Curvas suaves
                            color: primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3, // ✅ Puntos más pequeños
                                  color: primary,
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: primary.withOpacity(0.15),
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
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ordenSeleccionado,
                        isExpanded: true,
                        icon: Icon(Icons.sort, color: primary),
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontSize: 14),
                        items: ['Más reciente', 'Más antiguo']
                            .map((orden) => DropdownMenuItem(value: orden, child: Text(orden)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            ordenSeleccionado = value!;
                            aplicarFiltros();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tipoSeleccionado,
                        isExpanded: true,
                        icon: Icon(Icons.filter_alt, color: primary),
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontSize: 14),
                        items: tiposFiltro // ✅ Usar la lista actualizada
                            .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            tipoSeleccionado = value!;
                            aplicarFiltros();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sesionesAMostrar.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No hay sesiones para mostrar',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16),
                  ),
                ),
              )
            else
              ...sesionesAMostrar.map((sesion) => _buildSesionItem(sesion, textColor, primary)),
            if (hayMas)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    onPressed: cargarMasSesiones,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Cargar más'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ Item de sesión actualizado con estados
  Widget _buildSesionItem(Sesion sesion, Color textColor, Color primary) {
    final fecha = '${sesion.fecha.day.toString().padLeft(2, '0')}/${sesion.fecha.month.toString().padLeft(2, '0')}/${sesion.fecha.year}';
    final hora = '${sesion.fecha.hour.toString().padLeft(2, '0')}:${sesion.fecha.minute.toString().padLeft(2, '0')}';
    
    // ✅ Determinar color y texto según el estado
    Color estadoColor;
    String estadoTexto;
    
    if (sesion.estado == 'finalizada') {
      estadoColor = Colors.green;
      estadoTexto = 'Finalizada';
    } else if (sesion.estado == 'incompleta') {
      estadoColor = Colors.orange;
      estadoTexto = 'Incompleta';
    } else {
      estadoColor = Colors.blue;
      estadoTexto = 'Programada';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primera fila: Icono, nombre y estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sesion.esRapida ? Colors.blue.withOpacity(0.2) : primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sesion.esRapida ? Icons.flash_on : Icons.event,
                  color: sesion.esRapida ? Colors.blue : primary,
                  size: 20,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  estadoTexto,
                  style: TextStyle(
                    color: estadoColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          // Segunda fila: Fecha y hora
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
