import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const width = 1024;
  const height = 1024;
  final image = img.Image(width: width, height: height);

  // 1. Fondo azul corporativo #0F2744
  final bgColor = img.ColorRgba8(15, 39, 68, 255);
  final white = img.ColorRgba8(255, 255, 255, 255);
  img.fill(image, color: bgColor);

  // Parámetros:
  // Altura: Y = 282 a Y = 742 (460px)
  // Grosor de trazo: 76px
  const halfStroke = 38;
  const topY = 282;
  const botY = 742;

  // --- LETRA A (X centro: 330) ---
  const apexX = 330.0;
  const leftBaseX = 175.0;
  const rightBaseX = 485.0;

  for (int y = topY; y <= botY; y++) {
    final t = (y - topY) / (botY - topY);
    final cxLeft = apexX + (leftBaseX - apexX) * t;
    final cxRight = apexX + (rightBaseX - apexX) * t;

    // Pierna izquierda
    img.fillRect(
      image,
      x1: (cxLeft - halfStroke).round(),
      y1: y,
      x2: (cxLeft + halfStroke).round(),
      y2: y + 1,
      color: white,
    );

    // Pierna derecha
    img.fillRect(
      image,
      x1: (cxRight - halfStroke).round(),
      y1: y,
      x2: (cxRight + halfStroke).round(),
      y2: y + 1,
      color: white,
    );

    // Travesaño central de la A
    if (y >= 520 && y <= 520 + (halfStroke * 2)) {
      img.fillRect(
        image,
        x1: cxLeft.round(),
        y1: y,
        x2: cxRight.round(),
        y2: y + 1,
        color: white,
      );
    }
  }

  // --- LETRA E (X: 550 a 840) ---
  const eLeft = 550;
  const eRight = 840;
  const eStroke = halfStroke * 2;

  // Columna vertical
  img.fillRect(image, x1: eLeft, y1: topY, x2: eLeft + eStroke, y2: botY, color: white);

  // Barra superior
  img.fillRect(image, x1: eLeft, y1: topY, x2: eRight, y2: topY + eStroke, color: white);

  // Barra media
  final midY = (topY + botY - eStroke) ~/ 2;
  img.fillRect(image, x1: eLeft, y1: midY, x2: eRight - 35, y2: midY + eStroke, color: white);

  // Barra inferior
  img.fillRect(image, x1: eLeft, y1: botY - eStroke, x2: eRight, y2: botY, color: white);

  // Guardar imagen en assets/images/app_icon.png
  final outDir = Directory('assets/images');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final pngBytes = img.encodePng(image);
  final outFile = File('assets/images/app_icon.png');
  outFile.writeAsBytesSync(pngBytes);
  print('Ícono generado exitosamente en: ${outFile.path} (${pngBytes.length} bytes)');
}
