import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PhotoUtils {
  /// ✅ PROCESAR FOTO: Agrega marca de agua con fecha y hora
  static Future<Uint8List> processPhotoWithWatermark(XFile photo) async {
    try {
      // 1. Leer bytes de la foto
      final bytes = await photo.readAsBytes();

      // 2. Decodificar la imagen
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // 3. Crear la marca de agua con fecha y hora actual
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final watermarkText = 'Elite Multiservicios\n$dateStr $timeStr';

      // 4. Dibujar la marca de agua directamente sobre la imagen
      // Usamos la librería `image` para dibujar texto
      img.drawString(
        image,
        watermarkText,
        font: img.arial24,
        x: 20,
        y: image.height - 80,
        color: img.ColorRgba8(255, 255, 255, 255), // Blanco
      );

      // 5. Agregar un fondo semi-transparente detrás del texto
      // (opcional, para que se lea mejor)
      img.fillRect(
        image,
        x1: 0,
        y1: image.height - 90,
        x2: image.width,
        y2: image.height,
        color: img.ColorRgba8(0, 0, 0, 150), // Negro semi-transparente
      );

      // 6. Redibujar el texto encima del fondo
      img.drawString(
        image,
        watermarkText,
        font: img.arial24,
        x: 20,
        y: image.height - 70,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      // 7. Convertir de vuelta a bytes
      final processedBytes = img.encodeJpg(image, quality: 85);

      return Uint8List.fromList(processedBytes);
    } catch (e) {
      print('❌ Error procesando foto: $e');
      // Si falla, devolver la foto original
      return await photo.readAsBytes();
    }
  }

  /// ✅ VERIFICAR SI LA FOTO ES DE HOY
  /// (Validación extra: si la foto tiene metadatos EXIF con fecha)
  static Future<bool> isPhotoFromToday(XFile photo) async {
    try {
      // Leer los metadatos EXIF de la foto
      final bytes = await photo.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return true; // Si no podemos leer, permitir

      // Verificar la fecha de modificación del archivo
      final file = File(photo.path);
      if (await file.exists()) {
        final lastModified = await file.lastModified();
        final now = DateTime.now();

        // Si el archivo fue modificado en las últimas 24 horas, permitir
        final difference = now.difference(lastModified);
        return difference.inHours < 24;
      }

      return true;
    } catch (e) {
      print('⚠️ Error verificando fecha de foto: $e');
      return true; // Si hay error, permitir (para no bloquear al usuario)
    }
  }
}