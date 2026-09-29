import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';

class CreateEmployeeAdmin extends StatefulWidget {
  const CreateEmployeeAdmin({super.key});

  @override
  State<CreateEmployeeAdmin> createState() => _CreateEmployeeAdminState();
}

class _CreateEmployeeAdminState extends State<CreateEmployeeAdmin> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _ciController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _departmentController = TextEditingController(text: 'General');

  String _selectedRole = 'employee';
  String _selectedEmployeeType = 'field';
  String? _selectedClientId;

  Uint8List? _contractBytes;
  String? _contractFilename;
  int? _contractSize;

  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().fetchClients();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ciController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _pickContractFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();

        // Validación de tamaño máximo: 10 MB
        const maxSizeBytes = 10 * 1024 * 1024;
        if (bytes.length > maxSizeBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El archivo excede el tamaño máximo permitido (10 MB).'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _contractBytes = bytes;
          _contractFilename = file.name;
          _contractSize = bytes.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeContractFile() {
    setState(() {
      _contractBytes = null;
      _contractFilename = null;
      _contractSize = null;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final attProv = context.read<AttendanceProvider>();
    final result = await attProv.createEmployeeWithEdgeFunction(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text.trim(),
      ci: _ciController.text.trim(),
      role: _selectedRole,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      department: _departmentController.text.trim().isEmpty ? 'General' : _departmentController.text.trim(),
      clientId: _selectedClientId,
      employeeType: _selectedEmployeeType,
      contractBytes: _contractBytes,
      contractFilename: _contractFilename,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empleado creado exitosamente'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final errorMsg = result['error'] ?? 'No se pudo crear el empleado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final clients = attProv.clients;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuevo Empleado',
          style: TextStyle(color: Color(0xFF0F2744), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F2744)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos Personales y de Cuenta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2744),
                ),
              ),
              const SizedBox(height: 16),

              // Nombre completo
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo *',
                  hintText: 'Ej. Juan Pérez Gómez',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el nombre completo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // CI y Teléfono en fila
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ciController,
                      decoration: InputDecoration(
                        labelText: 'C.I. *',
                        hintText: 'Ej. 7894561 LP',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingresa el C.I.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Teléfono',
                        hintText: 'Ej. 71234567',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico *',
                  hintText: 'empleado@empresa.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un correo electrónico';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Contraseña temporal
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña Temporal *',
                  hintText: 'Mínimo 8 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa una contraseña';
                  }
                  if (val.trim().length < 8) {
                    return 'Debe tener al menos 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Dirección
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Dirección de Domicilio',
                  hintText: 'Ej. Av. América #123, Cochabamba',
                  prefixIcon: const Icon(Icons.home_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Cargo y Asignación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2744),
                ),
              ),
              const SizedBox(height: 16),

              // Rol y Tipo de Empleado
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Rol en Sistema',
                        prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'employee', child: Text('Empleado')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedEmployeeType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Trabajo',
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'field', child: Text('Campo')),
                        DropdownMenuItem(value: 'office', child: Text('Oficina')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedEmployeeType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Departamento
              TextFormField(
                controller: _departmentController,
                decoration: InputDecoration(
                  labelText: 'Departamento / Área',
                  hintText: 'Ej. Limpieza, Seguridad, Mensajería',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Cliente asignado
              DropdownButtonFormField<String?>(
                value: _selectedClientId,
                decoration: InputDecoration(
                  labelText: 'Cliente o Empresa Asignada (Opcional)',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin cliente asignado'),
                  ),
                  ...clients.map((c) => DropdownMenuItem<String?>(
                        value: c['id']?.toString(),
                        child: Text(
                          c['name']?.toString() ?? 'Cliente',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedClientId = val),
              ),
              const SizedBox(height: 24),

              // Contrato de Trabajo
              const Text(
                'Contrato Laboral (Documento)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2744),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Adjunta el archivo del contrato (PDF, Word o imagen, máx. 10 MB). Se guardará de forma segura en un almacenamiento privado accesible solo por administradores.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),

              if (_contractBytes == null)
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickContractFile,
                  icon: const Icon(Icons.upload_file, color: Color(0xFF0051D5)),
                  label: const Text('Subir Contrato'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFF0051D5), width: 1.5),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Color(0xFF0051D5), size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _contractFilename ?? 'Contrato',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F2744),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_contractSize != null)
                              Text(
                                _formatFileSize(_contractSize!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Quitar archivo',
                        onPressed: _isSaving ? null : _removeContractFile,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Botones de acción
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitForm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(
                    _isSaving ? 'Creando Empleado...' : 'Crear Empleado',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2744),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
