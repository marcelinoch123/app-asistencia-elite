import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/custom_drawer.dart';

class ClientsAdmin extends StatefulWidget {
  const ClientsAdmin({super.key});

  @override
  State<ClientsAdmin> createState() => _ClientsAdminState();
}

class _ClientsAdminState extends State<ClientsAdmin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
  }

  Future<void> _loadClients() async {
    if (!mounted) return;
    await context.read<AttendanceProvider>().fetchClients();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final clients = provider.clients;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FF),
      drawer: const CustomDrawer(isAdmin: true),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D1C2F)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Gestion de Clientes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF001229),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2744),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Cliente'),
        onPressed: () => _showClientDialog(context, null),
      ),
      body: provider.isClientsLoading
          ? const Center(child: CircularProgressIndicator())
          : clients.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    return _buildClientCard(clients[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business, size: 80, color: Color(0xFFD5E3FD)),
          const SizedBox(height: 16),
          const Text(
            'No hay clientes registrados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44474D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona "Nuevo Cliente" para empezar',
            style: TextStyle(fontSize: 14, color: Color(0xFF74777E)),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final name = client['name'] ?? 'Sin nombre';
    final service = client['service'] ?? '';
    final address = client['address'] ?? 'Sin direccion';
    final lat = client['location_lat'] ?? 0;
    final lng = client['location_lng'] ?? 0;
    final radius = client['radius_meters'] ?? 500;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2744),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF001229),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0051D5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF0051D5)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF001229),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (lat != 0.0 || lng != 0.0) ...[
                  Text(
                    'Coordenadas: $lat, $lng',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF44474D)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Radio permitido: ${radius}m',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF44474D)),
                  ),
                ] else ...[
                  const Text(
                    'Sin coordenadas: los empleados podrán marcar desde cualquier lugar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0051D5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showClientDialog(context, client),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0051D5),
                    side: const BorderSide(color: Color(0xFF0051D5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(client),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBA1A1A),
                    side: const BorderSide(color: Color(0xFFBA1A1A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClientDialog(BuildContext context, Map<String, dynamic>? client) {
    final isEditing = client != null;
    final nameCtrl = TextEditingController(text: isEditing ? client['name']?.toString() ?? '' : '');
    final serviceCtrl = TextEditingController(text: isEditing ? client['service']?.toString() ?? '' : '');
    final addressCtrl = TextEditingController(text: isEditing ? client['address']?.toString() ?? '' : '');
    final radiusCtrl = TextEditingController(text: isEditing ? (client['radius_meters']?.toString() ?? '500') : '500');

    double lat = isEditing ? (client['location_lat'] as num?)?.toDouble() ?? 0.0 : 0.0;
    double lng = isEditing ? (client['location_lng'] as num?)?.toDouble() ?? 0.0 : 0.0;

    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.add_circle,
                color: const Color(0xFF0F2744),
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente',
                      hintText: 'Ej: Kolping los Chacos',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: serviceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servicio',
                      hintText: 'Ej: Limpieza, Seguridad, Jardineria',
                      prefixIcon: Icon(Icons.work),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Buscar direccion',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF44474D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Ej: Mall Ventura Santa Cruz Bolivia',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) async {
                            if (value.trim().isEmpty) return;
                            setDialogState(() => isSearching = true);
                            final results = await GeocodingService.searchAddress(value);
                            setDialogState(() {
                              searchResults = results;
                              isSearching = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (addressCtrl.text.trim().isEmpty) return;
                          setDialogState(() => isSearching = true);
                          final results = await GeocodingService.searchAddress(addressCtrl.text);
                          setDialogState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0051D5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        child: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE6EEFF)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (_, i) {
                          final r = searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, color: Color(0xFF0051D5), size: 20),
                            title: Text(
                              r['display_name'],
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setDialogState(() {
                                addressCtrl.text = r['display_name'];
                                lat = r['lat'];
                                lng = r['lon'];
                                searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (lat == 0.0 && lng == 0.0)
                          ? const Color(0xFFFFF7ED)
                          : const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(8),
                      border: (lat == 0.0 && lng == 0.0)
                          ? Border.all(color: const Color(0xFFFDBA74))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (lat == 0.0 && lng == 0.0)
                                  ? Icons.info_outline
                                  : Icons.location_on,
                              size: 16,
                              color: (lat == 0.0 && lng == 0.0)
                                  ? const Color(0xFFC2410C)
                                  : const Color(0xFF0051D5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (lat == 0.0 && lng == 0.0)
                                  ? 'Aviso de ubicación'
                                  : 'Coordenadas seleccionadas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (lat == 0.0 && lng == 0.0)
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF44474D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (lat == 0.0 && lng == 0.0)
                          const Text(
                            'Sin coordenadas: los empleados podrán marcar desde cualquier lugar',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else ...[
                          Text(
                            'Lat: ${lat.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF001229)),
                          ),
                          Text(
                            'Lng: ${lng.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF001229)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (lat != 0.0 || lng != 0.0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            lat = 0.0;
                            lng = 0.0;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text(
                          'Quitar coordenadas',
                          style: TextStyle(fontSize: 11, color: Color(0xFFBA1A1A)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: radiusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radio permitido (metros)',
                      hintText: 'Ej: 500',
                      prefixIcon: Icon(Icons.radar),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Ingresa el nombre del cliente')),
                  );
                  return;
                }

                final provider = context.read<AttendanceProvider>();
                final radius = int.tryParse(radiusCtrl.text) ?? 500;

                bool success;
                if (isEditing) {
                  success = await provider.updateClient(
                    clientId: client['id'],
                    name: nameCtrl.text.trim(),
                    service: serviceCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    lat: lat,
                    lng: lng,
                    radius: radius,
                  );
                } else {
                  success = await provider.createClient(
                    name: nameCtrl.text.trim(),
                    service: serviceCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    lat: lat,
                    lng: lng,
                    radius: radius,
                  );
                }

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? (lat == 0.0 && lng == 0.0
                              ? (isEditing
                                  ? 'Cliente actualizado. Sin coordenadas: los empleados podrán marcar desde cualquier lugar.'
                                  : 'Cliente creado. Sin coordenadas: los empleados podrán marcar desde cualquier lugar.')
                              : (isEditing ? 'Cliente actualizado' : 'Cliente creado'))
                          : 'Error al guardar'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2744),
              ),
              child: Text(isEditing ? 'Guardar cambios' : 'Crear cliente'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Cliente'),
        content: Text('Seguro que quieres eliminar "${client['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await context
                  .read<AttendanceProvider>()
                  .deleteClient(client['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Cliente eliminado'
                        : 'Error al eliminar'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}