import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_client.dart';

class StorageService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String contractsBucket = 'employee_contracts';

  /// Sube un contrato en formato de bytes al bucket privado de contratos
  /// Devuelve el path relativo guardado en Storage o null si falla.
  Future<String?> uploadContract({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final cleanName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/contrato_${timestamp}_$cleanName';

      await _supabase.storage.from(contractsBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return path;
    } catch (e) {
      print('Error al subir contrato en StorageService: $e');
      return null;
    }
  }

  /// Genera una URL firmada de corta duración (por defecto 1 hora = 3600 seg)
  /// para permitir al administrador visualizar o descargar el contrato privado.
  Future<String?> getSignedContractUrl(
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      final signedUrl = await _supabase.storage
          .from(contractsBucket)
          .createSignedUrl(path, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      print('Error al obtener URL firmada de contrato: $e');
      return null;
    }
  }

  /// Elimina el archivo de contrato del Storage
  Future<bool> deleteContract(String path) async {
    try {
      await _supabase.storage.from(contractsBucket).remove([path]);
      return true;
    } catch (e) {
      print('Error al eliminar contrato de Storage: $e');
      return false;
    }
  }

  /// Abre la URL en el visor externo o navegador del dispositivo
  Future<bool> openContractUrl(String signedUrl) async {
    try {
      final uri = Uri.parse(signedUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error al abrir URL del contrato: $e');
      return false;
    }
  }
}
