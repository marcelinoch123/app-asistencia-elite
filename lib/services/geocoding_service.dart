import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Busca una dirección y devuelve una lista de resultados con lat y lng.
  /// Cada resultado es un Map con: display_name, lat, lon
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'EliteAsistencia/1.0 (contacto@elite.com)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        print('Error geocoding: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      return data.map<Map<String, dynamic>>((item) {
        return {
          'display_name': item['display_name'] ?? '',
          'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
        };
      }).toList();
    } catch (e) {
      print('Error en searchAddress: $e');
      return [];
    }
  }
}