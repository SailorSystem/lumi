import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/sesion_service.dart';
import '../../core/services/tema_service.dart';
import '../../core/services/usuario_service.dart';
import '../../core/models/sesion.dart';
import '../../core/models/usuario.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/connectivity_service.dart';
import '../../widgets/no_connection_dialog.dart';
import '../../core/models/tema.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  StatsScreenState createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  bool loading = true;
  int? userId;
  
  // Sesiones
  List<Sesion> todasSesiones = [];
  List<Sesion> sesionesFiltradas = [];

  List<Map<String, dynamic>> todosTemas = [];
  List<int> temasSeleccionados = [];

  // ✅ Estadísticas actualizadas
  int totalFinalizadas = 0;
  int totalIncompletas = 0;
  int totalRapidas = 0;
  int totalSesiones = 0;
  
  // 🆕 Nuevas métricas
  int tiempoTotalMinutos = 0;
  int promedioSesionMinutos = 0;
  int racha = 0;
  int mejorRacha = 0;
  Map<String, int> temasEstadisticas = {}; // Tema más usado
  String temaMasUsado = 'N/A';
  
  // Filtros
  String ordenSeleccionado = 'Más reciente';
  String tipoSeleccionado = 'Todas';
  String filtroGrafico = 'Semana';
  
  // 🆕 Vista seleccionada (tabs)
  int _selectedTab = 0;
  late TabController _tabController;

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadStats() async {
    print('🔄 Iniciando carga de estadísticas...');

    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('user_id');

      if (userId == null) {
        try {
          final usuarios = await UsuarioService.getTodos();
          if (usuarios.isNotEmpty) {
            userId = usuarios.first.idUsuario;
            await prefs.setInt('user_id', userId!);
          }
        } catch (e) {
          print('❌ Error obteniendo usuarios: $e');
        }
      }

      if (userId == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      final conectado = await ConnectivityService.verificarConexion();
      if (!conectado) {
        if (mounted) {
          await showNoConnectionDialog(
            context,
            message: 'No se pudieron cargar las estadísticas. Revisa tu conexión.',
          );
        }
        setState(() {
          loading = false;
          todasSesiones = [];
          sesionesFiltradas = [];
        });
        return;
      }

      // Limpiar datos
      todasSesiones = [];
      totalSesiones = 0;
      totalFinalizadas = 0;
      totalIncompletas = 0;
      totalRapidas = 0;
      todosTemas = [];
      tiempoTotalMinutos = 0;
      promedioSesionMinutos = 0;

      // Cargar temas
      try {
        final temas = await ConnectivityService.ejecutarConReintento(
          operacion: () => TemaService.obtenerTemasPorUsuario(userId!),
          intentosMaximos: 3,
        ) ?? [];

        todosTemas = temas.cast<Tema>().map((t) => {
          'id_tema': t.idTema,
          'nombre': t.nombre,
          'color': t.color,
        }).toList();
      } catch (e) {
        print('❌ Error cargando temas: $e');
        todosTemas = [];
      }

      // Cargar sesiones
      try {
        final response = await ConnectivityService.ejecutarConReintento(
          operacion: () => Supabase.instance.client
              .from('sesiones')
              .select()
              .eq('id_usuario', userId!)
              .order('fecha', ascending: false),
          intentosMaximos: 3,
        );

        if (response != null) {
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
            } catch (e) {
              print('❌ Error parseando sesión: $e');
            }
          }
        }
      } catch (e) {
        print('❌ Error Supabase: $e');
        todasSesiones = [];
      }

      // Calcular estadísticas básicas
      totalSesiones = todasSesiones.length;
      totalFinalizadas = todasSesiones.where((s) => s.estado == 'finalizada').length;
      totalIncompletas = todasSesiones.where((s) => s.estado == 'incompleta').length;
      totalRapidas = todasSesiones.where((s) => s.esRapida).length;

      // 🆕 Calcular métricas avanzadas
      _calcularMetricas();

      aplicarFiltros();
    } catch (e) {
      print('❌ ERROR GENERAL cargando stats: $e');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // 🆕 Método para calcular métricas avanzadas
  void _calcularMetricas() {
    // Tiempo total y promedio
    int tiempoTotalSegundos = 0;
    int sesionesConDuracion = 0;
    
    for (var sesion in todasSesiones) {
      if (sesion.duracionTotal != null && sesion.duracionTotal! > 0) {
        tiempoTotalSegundos += sesion.duracionTotal!;
        sesionesConDuracion++;
      }
    }
    
    tiempoTotalMinutos = (tiempoTotalSegundos / 60).round();
    promedioSesionMinutos = sesionesConDuracion > 0 
        ? (tiempoTotalSegundos / sesionesConDuracion / 60).round() 
        : 0;

    // Calcular racha actual y mejor racha
    _calcularRachas();

    // Calcular tema más usado
    _calcularTemaMasUsado();
  }

  // 🆕 Calcular rachas de días consecutivos
  void _calcularRachas() {
    if (todasSesiones.isEmpty) {
      racha = 0;
      mejorRacha = 0;
      return;
    }

    final sesionesOrdenadas = todasSesiones
        .where((s) => s.estado == 'finalizada')
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (sesionesOrdenadas.isEmpty) {
      racha = 0;
      mejorRacha = 0;
      return;
    }

    Set<String> diasUnicos = {};
    for (var sesion in sesionesOrdenadas) {
      final dia = '${sesion.fecha.year}-${sesion.fecha.month}-${sesion.fecha.day}';
      diasUnicos.add(dia);
    }

    final diasOrdenados = diasUnicos.toList()..sort((a, b) => b.compareTo(a));
    
    // Calcular racha actual
    final hoy = DateTime.now();
    final hoyStr = '${hoy.year}-${hoy.month}-${hoy.day}';
    final ayerStr = '${hoy.subtract(const Duration(days: 1)).year}-${hoy.subtract(const Duration(days: 1)).month}-${hoy.subtract(const Duration(days: 1)).day}';
    
    racha = 0;
    if (diasOrdenados.first == hoyStr || diasOrdenados.first == ayerStr) {
      DateTime diaActual = diasOrdenados.first == hoyStr 
          ? hoy 
          : hoy.subtract(const Duration(days: 1));
      
      for (var dia in diasOrdenados) {
        final diaEsperado = '${diaActual.year}-${diaActual.month}-${diaActual.day}';
        if (dia == diaEsperado) {
          racha++;
          diaActual = diaActual.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Calcular mejor racha
    mejorRacha = 0;
    int rachaTemp = 1;
    
    for (int i = 0; i < diasOrdenados.length - 1; i++) {
      final diaActual = DateTime.parse(diasOrdenados[i]);
      final diaSiguiente = DateTime.parse(diasOrdenados[i + 1]);
      
      if (diaActual.difference(diaSiguiente).inDays == 1) {
        rachaTemp++;
      } else {
        if (rachaTemp > mejorRacha) mejorRacha = rachaTemp;
        rachaTemp = 1;
      }
    }
    if (rachaTemp > mejorRacha) mejorRacha = rachaTemp;
  }

  // 🆕 Calcular tema más usado
  void _calcularTemaMasUsado() {
    temasEstadisticas = {};
    
    for (var sesion in todasSesiones) {
      if (sesion.idTema != null) {
        temasEstadisticas[sesion.idTema.toString()] = 
            (temasEstadisticas[sesion.idTema.toString()] ?? 0) + 1;
      }
    }

    if (temasEstadisticas.isEmpty) {
      temaMasUsado = 'N/A';
      return;
    }

    final idTemaMasUsado = temasEstadisticas.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final tema = todosTemas.firstWhere(
      (t) => t['id_tema'].toString() == idTemaMasUsado,
      orElse: () => {'nombre': 'Desconocido'},
    );

    temaMasUsado = tema['nombre'] as String;
  }

  void aplicarFiltros() {
    List<Sesion> temp;
    if (temasSeleccionados.isEmpty) {
      temp = List<Sesion>.from(todasSesiones);
    } else {
      temp = todasSesiones.where((s) {
        if (s.idTema == null) return false;
        return temasSeleccionados.contains(s.idTema);
      }).toList();
    }

    if (tipoSeleccionado == 'Todas') {
      sesionesFiltradas = temp;
    } else if (tipoSeleccionado == 'Finalizadas') {
      sesionesFiltradas = temp.where((s) => s.estado == 'finalizada').toList();
    } else if (tipoSeleccionado == 'Incompletas') {
      sesionesFiltradas = temp.where((s) => s.estado == 'incompleta').toList();
    } else if (tipoSeleccionado == 'Rápidas') {
      sesionesFiltradas = temp.where((s) => s.esRapida).toList();
    }

    if (ordenSeleccionado == 'Más reciente') {
      sesionesFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));
    } else if (ordenSeleccionado == 'Más antiguo') {
      sesionesFiltradas.sort((a, b) => a.fecha.compareTo(b.fecha));
    }

    totalSesiones = sesionesFiltradas.length;
    totalFinalizadas = sesionesFiltradas.where((s) => s.estado == 'finalizada').length;
    totalIncompletas = sesionesFiltradas.where((s) => s.estado == 'incompleta').length;
    totalRapidas = sesionesFiltradas.where((s) => s.esRapida).length;

    sesionesVisibles = sesionesPorPagina;
  }

  Future<void> _mostrarModalTemas(Color cardColor, Color textColor, Color primary) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filtrar por tema',
                          style: TextStyle(
                            color: primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (temasSeleccionados.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                temasSeleccionados.clear();
                              });
                            },
                            child: Text('Limpiar', style: TextStyle(color: primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (todosTemas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No hay temas creados',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: todosTemas.length,
                          itemBuilder: (context, index) {
                            final tema = todosTemas[index];
                            final int idTema = tema['id_tema'] as int;
                            final String nombre = tema['nombre'] ?? 'Tema';
                            final int? colorValue = tema['color'] is int
                                ? tema['color']
                                : int.tryParse(tema['color']?.toString() ?? '');

                            final Color temaColor = colorValue != null 
                                ? Color(colorValue) 
                                : primary;

                            final bool isSelected = temasSeleccionados.contains(idTema);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    isSelected
                                        ? temasSeleccionados.remove(idTema)
                                        : temasSeleccionados.add(idTema);
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? temaColor.withOpacity(0.2)
                                        : primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? temaColor : primary.withOpacity(0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: temaColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          nombre,
                                          style: TextStyle(
                                            fontWeight: isSelected 
                                                ? FontWeight.w600 
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle, color: temaColor),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            aplicarFiltros();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          temasSeleccionados.isEmpty
                              ? 'Mostrar todas las sesiones'
                              : 'Aplicar filtro (${temasSeleccionados.length} ${temasSeleccionados.length == 1 ? 'tema' : 'temas'})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void cargarMasSesiones() {
    setState(() {
      sesionesVisibles += sesionesPorPagina;
    });
  }

  List<FlSpot> obtenerDatosGrafico() {
    if (sesionesFiltradas.isEmpty) return [];
    
    final ahora = DateTime.now();
    DateTime fechaInicio;
    
    if (filtroGrafico == 'Semana') {
      fechaInicio = ahora.subtract(const Duration(days: 7));
    } else if (filtroGrafico == 'Mes') {
      fechaInicio = ahora.subtract(const Duration(days: 30));
    } else {
      fechaInicio = DateTime(2000);
    }
    
    final sesionesPorFecha = sesionesFiltradas
        .where((s) => s.fecha.isAfter(fechaInicio))
        .toList();
    
    if (sesionesPorFecha.isEmpty) return [];
    
    Map<String, int> sesionesPorDia = {};
    
    for (var sesion in sesionesPorFecha) {
      String key = '${sesion.fecha.year}-${sesion.fecha.month.toString().padLeft(2, '0')}-${sesion.fecha.day.toString().padLeft(2, '0')}';
      sesionesPorDia[key] = (sesionesPorDia[key] ?? 0) + 1;
    }
    
    var sortedKeys = sesionesPorDia.keys.toList()..sort();
    
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
      keysAMostrar = sortedKeys.length > 60 
          ? sortedKeys.sublist(sortedKeys.length - 60) 
          : sortedKeys;
    }
    
    List<FlSpot> spots = [];
    for (int i = 0; i < keysAMostrar.length; i++) {
      spots.add(FlSpot(i.toDouble(), sesionesPorDia[keysAMostrar[i]]!.toDouble()));
    }
    
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: textColor.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Progreso'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadStats,
        child: TabBarView(
          controller: _tabController,
          children: [
            // 🆕 Tab 1: Resumen expandido
            _buildResumenTab(cardColor, textColor, primary),
            
            // 🆕 Tab 2: Gráficos y progreso
            _buildProgresoTab(cardColor, textColor, primary),
            
            // 🆕 Tab 3: Historial
            _buildHistorialTab(cardColor, textColor, primary),
          ],
        ),
      ),
    );
  }

  // 🆕 Tab de resumen con métricas avanzadas
  Widget _buildResumenTab(Color cardColor, Color textColor, Color primary) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card de métricas principales
          _buildMetricasCard(cardColor, textColor, primary),
          
          const SizedBox(height: 16),
          
          // Card de rachas
          _buildRachasCard(cardColor, textColor, primary),
          
          const SizedBox(height: 16),
          
          // Card de tiempo de uso
          _buildTiempoUsoCard(cardColor, textColor, primary),
          
          const SizedBox(height: 16),
          
          // Card de tema más usado
          _buildTemaMasUsadoCard(cardColor, textColor, primary),
        ],
      ),
    );
  }

  // 🆕 Tab de progreso con gráficos
  Widget _buildProgresoTab(Color cardColor, Color textColor, Color primary) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGraficoCard(cardColor, textColor, primary),
          
          const SizedBox(height: 16),
          
          // 🆕 Distribución por estado
          _buildDistribucionEstadosCard(cardColor, textColor, primary),
        ],
      ),
    );
  }

  // 🆕 Tab de historial
  Widget _buildHistorialTab(Color cardColor, Color textColor, Color primary) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHistorialSection(cardColor, textColor, primary),
        ],
      ),
    );
  }

  // 🆕 Card de métricas principales
  Widget _buildMetricasCard(Color cardColor, Color textColor, Color primary) {
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
                  'Métricas Generales',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: temasSeleccionados.isEmpty ? primary : Colors.green,
                  ),
                  tooltip: 'Filtrar por tema',
                  onPressed: () => _mostrarModalTemas(cardColor, textColor, primary),
                ),
              ],
            ),
            
            if (temasSeleccionados.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: temasSeleccionados.map((idTema) {
                    final tema = todosTemas.firstWhere(
                      (t) => t['id_tema'] == idTema,
                      orElse: () => {'nombre': 'Tema $idTema', 'color': primary.value},
                    );

                    return Chip(
                      label: Text(tema['nombre'] as String),
                      backgroundColor: Color(tema['color'] as int).withOpacity(0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          temasSeleccionados.remove(idTema);
                          aplicarFiltros();
                        });
                      },
                    );
                  }).toList(),
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

  // 🆕 Card de rachas
  Widget _buildRachasCard(Color cardColor, Color textColor, Color primary) {
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
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Rachas',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Racha Actual',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$racha',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          racha == 1 ? 'día' : 'días',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepOrange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Mejor Racha',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$mejorRacha',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          mejorRacha == 1 ? 'día' : 'días',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (racha > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          racha >= 7
                              ? '¡Increíble! Llevas $racha días seguidos 🎉'
                              : '¡Sigue así! Ya llevas $racha ${racha == 1 ? 'día' : 'días'}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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

  // 🆕 Card de tiempo de uso
  Widget _buildTiempoUsoCard(Color cardColor, Color textColor, Color primary) {
    final horas = tiempoTotalMinutos ~/ 60;
    final minutos = tiempoTotalMinutos % 60;
    
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
              children: [
                Icon(Icons.access_time, color: Colors.purple, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Tiempo de Estudio',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _tiempoItem(
                    'Tiempo Total',
                    horas > 0 ? '$horas h $minutos min' : '$minutos min',
                    Colors.purple,
                    textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tiempoItem(
                    'Promedio',
                    '$promedioSesionMinutos min',
                    Colors.deepPurple,
                    textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiempoItem(String label, String value, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
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
        ],
      ),
    );
  }

  // 🆕 Card de tema más usado
  Widget _buildTemaMasUsadoCard(Color cardColor, Color textColor, Color primary) {
    final tema = todosTemas.firstWhere(
      (t) => t['nombre'] == temaMasUsado,
      orElse: () => {'color': primary.value},
    );
    
    final temaColor = Color(tema['color'] as int);
    final cantidadSesiones = temasEstadisticas[tema['id_tema']?.toString()] ?? 0;
    
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
              children: [
                Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Tema Favorito',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: temaColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: temaColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: temaColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temaMasUsado,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$cantidadSesiones ${cantidadSesiones == 1 ? 'sesión' : 'sesiones'}',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Card de distribución por estados (gráfico de torta)
  Widget _buildDistribucionEstadosCard(Color cardColor, Color textColor, Color primary) {
    final totalSesionesGrafico = totalFinalizadas + totalIncompletas;
    
    if (totalSesionesGrafico == 0) {
      return const SizedBox.shrink();
    }
    
    final porcentajeFinalizadas = (totalFinalizadas / totalSesionesGrafico * 100).round();
    final porcentajeIncompletas = 100 - porcentajeFinalizadas;
    
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
              'Distribución de Sesiones',
              style: TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _distribucionItem(
                  'Finalizadas',
                  '$porcentajeFinalizadas%',
                  Colors.green,
                  textColor,
                ),
                _distribucionItem(
                  'Incompletas',
                  '$porcentajeIncompletas%',
                  Colors.orange,
                  textColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _distribucionItem(String label, String value, Color color, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 4,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    
    final ahora = DateTime.now();
    DateTime fechaInicio;
    
    if (filtroGrafico == 'Semana') {
      fechaInicio = ahora.subtract(const Duration(days: 7));
    } else if (filtroGrafico == 'Mes') {
      fechaInicio = ahora.subtract(const Duration(days: 30));
    } else {
      fechaInicio = DateTime(2000);
    }
    
    final sesionesPorFecha = sesionesFiltradas
        .where((s) => s.fecha.isAfter(fechaInicio))
        .toList();
    
    Map<String, int> sesionesPorDia = {};
    for (var sesion in sesionesPorFecha) {
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
    
    double maxY = 0;
    if (spots.isNotEmpty) {
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    }
    
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
            Text(
              'Progreso de Sesiones',
              style: TextStyle(
                color: primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
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
                        maxY: maxY + 1,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: intervalo,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: intervalo,
                              getTitlesWidget: (value, meta) {
                                if (value < 0 || value % intervalo != 0) return const SizedBox();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11,
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
                                  ? (keysAMostrar.length / 10).ceilToDouble()
                                  : (filtroGrafico == 'Mes' ? 5 : 1),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= keysAMostrar.length) {
                                  return const SizedBox();
                                }
                                
                                final fecha = DateTime.parse(keysAMostrar[index]);
                                String label = '${fecha.day}/${fecha.month}';
                                
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: filtroGrafico == 'General' ? -0.5 : 0,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 9,
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
                            isCurved: true,
                            color: primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
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
                        items: tiposFiltro
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

  Widget _buildSesionItem(Sesion sesion, Color textColor, Color primary) {
    final fecha = '${sesion.fecha.day.toString().padLeft(2, '0')}/${sesion.fecha.month.toString().padLeft(2, '0')}/${sesion.fecha.year}';
    final hora = '${sesion.fecha.hour.toString().padLeft(2, '0')}:${sesion.fecha.minute.toString().padLeft(2, '0')}';
    
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