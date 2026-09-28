import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../config/supabase_client.dart';
import '../../widgets/custom_drawer.dart';

class EmployeeMapItem {
  final String userId;
  final String fullName;
  final String email;
  final double lat;
  final double lng;
  final DateTime? lastUpdate;
  final String? clientName;
  final String? shiftName;

  EmployeeMapItem({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.lat,
    required this.lng,
    this.lastUpdate,
    this.clientName,
    this.shiftName,
  });
}

class ClientMapItem {
  final String clientId;
  final String name;
  final double lat;
  final double lng;

  ClientMapItem({
    required this.clientId,
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class MapAdmin extends StatefulWidget {
  const MapAdmin({super.key});

  @override
  State<MapAdmin> createState() => _MapAdminState();
}

class _MapAdminState extends State<MapAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;

  // Centro por defecto: Santa Cruz de la Sierra, Bolivia
  static const LatLng _defaultLocation = LatLng(-17.7833, -63.1821);

  bool _isLoading = true;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  List<EmployeeMapItem> _employees = [];
  List<ClientMapItem> _clients = [];
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresco cada 30 segundos
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await Future.wait([
        // 0: Asignaciones de hoy
        SupabaseConfig.client
            .from('shift_assignments')
            .select('user_id, client_id, assigned_date, shift_id')
            .eq('assigned_date', todayStr),
        // 1: Ubicaciones en vivo
        SupabaseConfig.client
            .from('live_locations')
            .select('user_id, lat, lng, last_update'),
        // 2: Usuarios
        SupabaseConfig.client
            .from('users')
            .select('id, full_name, name, email'),
        // 3: Clientes
        SupabaseConfig.client
            .from('clients')
            .select('id, name, location_lat, location_lng'),
        // 4: Turnos
        SupabaseConfig.client
            .from('shifts')
            .select('id, name'),
      ]);

      final assignmentsData = List<Map<String, dynamic>>.from(results[0]);
      final liveLocationsData = List<Map<String, dynamic>>.from(results[1]);
      final usersData = List<Map<String, dynamic>>.from(results[2]);
      final clientsData = List<Map<String, dynamic>>.from(results[3]);
      final shiftsData = List<Map<String, dynamic>>.from(results[4]);

      final Map<String, Map<String, dynamic>> usersMap = {
        for (final u in usersData) u['id']?.toString() ?? '': u
      };
      final Map<String, Map<String, dynamic>> clientsMap = {
        for (final c in clientsData) c['id']?.toString() ?? '': c
      };
      final Map<String, Map<String, dynamic>> shiftsMap = {
        for (final s in shiftsData) s['id']?.toString() ?? '': s
      };
      final Map<String, Map<String, dynamic>> liveLocMap = {
        for (final l in liveLocationsData) l['user_id']?.toString() ?? '': l
      };

      // 1. Filtrar empleados asignados hoy que tengan ubicación activa en live_locations
      final Map<String, EmployeeMapItem> activeEmployees = {};
      final Set<String> assignedClientIds = {};

      for (final sa in assignmentsData) {
        final uId = sa['user_id']?.toString() ?? '';
        final cId = sa['client_id']?.toString();
        if (cId != null && cId.isNotEmpty) {
          assignedClientIds.add(cId);
        }

        if (uId.isEmpty) continue;
        final loc = liveLocMap[uId];
        if (loc != null && loc['lat'] != null && loc['lng'] != null) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();

          // Evitar coordenadas 0,0 inválidas
          if (lat != 0.0 && lng != 0.0) {
            final user = usersMap[uId];
            final client = clientsMap[cId ?? ''];
            final shift = shiftsMap[sa['shift_id']?.toString() ?? ''];

            DateTime? lastUpdate;
            if (loc['last_update'] != null) {
              lastUpdate = DateTime.tryParse(loc['last_update'].toString())?.toLocal();
            }

            activeEmployees[uId] = EmployeeMapItem(
              userId: uId,
              fullName: user?['full_name']?.toString() ??
                  user?['name']?.toString() ??
                  'Empleado',
              email: user?['email']?.toString() ?? '',
              lat: lat,
              lng: lng,
              lastUpdate: lastUpdate,
              clientName: client?['name']?.toString(),
              shiftName: shift?['name']?.toString(),
            );
          }
        }
      }

      // 2. Clientes (Empresas) asignadas hoy que tengan coordenadas configuradas
      final List<ClientMapItem> clientItems = [];
      for (final cId in assignedClientIds) {
        final c = clientsMap[cId];
        if (c != null) {
          final lat = (c['location_lat'] as num?)?.toDouble();
          final lng = (c['location_lng'] as num?)?.toDouble();
          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            clientItems.add(ClientMapItem(
              clientId: cId,
              name: c['name']?.toString() ?? 'Empresa',
              lat: lat,
              lng: lng,
            ));
          }
        }
      }

      // 3. Generar Marcadores
      final Set<Marker> newMarkers = {};

      // Marcadores de Empresas (Azul)
      for (final client in clientItems) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('client_${client.clientId}'),
            position: LatLng(client.lat, client.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: client.name,
              snippet: 'Empresa asignada',
            ),
          ),
        );
      }

      // Marcadores de Empleados (Verde)
      for (final emp in activeEmployees.values) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('emp_${emp.userId}'),
            position: LatLng(emp.lat, emp.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: emp.fullName,
              snippet: 'Últ. act: ${_formatRelativeTime(emp.lastUpdate)}',
            ),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _employees = activeEmployees.values.toList();
          _clients = clientItems;
          _markers = newMarkers;
          _isLoading = false;
        });

        // Si es la primera carga y hay empleados, centrar en el primero
        if (!silent && _employees.isNotEmpty && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_employees.first.lat, _employees.first.lng),
              14,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar mapa: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _centerOnAdminLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa el GPS de tu dispositivo')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la ubicación: $e')),
      );
    }
  }

  void _focusEmployee(EmployeeMapItem emp) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(emp.lat, emp.lng), 16),
    );
    _mapController?.showMarkerInfoWindow(MarkerId('emp_${emp.userId}'));
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Desconocida';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Hace unos segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(isAdmin: true),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D1C2F)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Mapa en Tiempo Real',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F2744)),
            tooltip: 'Actualizar',
            onPressed: () => _loadData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Banner de error si ocurrió una falla
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Cargando inicial
          if (_isLoading && _errorMessage == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Actualizando ubicaciones...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF001229)),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Leyenda rápida superior
          Positioned(
            top: _isLoading ? 64 : 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text('Empleado (${_employees.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF0051D5)),
                      const SizedBox(width: 4),
                      Text('Empresa (${_clients.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Botón flotante para centrar en Admin GPS
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0051D5),
              tooltip: 'Mi ubicación',
              onPressed: _centerOnAdminLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // 5. Panel Inferior Deslizable (Lista de empleados o Estado Vacío)
          _buildDraggablePanel(),
        ],
      ),
    );
  }

  Widget _buildDraggablePanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.65,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // Barra de arrastre
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabecera del panel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Empleados en Turno Hoy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF001229),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_employees.length} activos',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Estado vacío o Lista de empleados
              if (_employees.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 42,
                        color: const Color(0xFF64748B).withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No hay empleados con ubicación activa. Los empleados deben estar logueados para aparecer aquí.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._employees.map((emp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF10B981), size: 20),
                      ),
                      title: Text(
                        emp.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001229),
                        ),
                      ),
                      subtitle: Text(
                        '${emp.shiftName ?? "Turno"} • ${emp.clientName ?? "Sin cliente"}\nAct: ${_formatRelativeTime(emp.lastUpdate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.my_location, color: Color(0xFF0051D5), size: 20),
                        tooltip: 'Ver en mapa',
                        onPressed: () => _focusEmployee(emp),
                      ),
                      onTap: () => _focusEmployee(emp),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
