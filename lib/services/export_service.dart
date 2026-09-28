import 'package:excel/excel.dart';
import '../models/report_detail_model.dart';
import '../models/user_model.dart';
import '../utils/file_saver.dart';

class ExportService {
  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lun';
      case DateTime.tuesday:
        return 'Mar';
      case DateTime.wednesday:
        return 'Mié';
      case DateTime.thursday:
        return 'Jue';
      case DateTime.friday:
        return 'Vie';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '';
    }
  }

  /// Genera y descarga/comparte el archivo Excel (.xlsx) para el empleado y período especificado.
  static Future<void> exportMonthlyReportToExcel({
    required UserModel employee,
    required int month,
    required int year,
    required Map<String, dynamic> summary,
    required List<DailyReportDetail> dailyDetails,
  }) async {
    final excel = Excel.createExcel();

    // Renombrar la hoja por defecto o crear 'Reporte Mensual'
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Reporte Mensual');
    final sheet = excel['Reporte Mensual'];

    // Estilos principales
    final titleBannerStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: '#0F2744'.excelColor,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final subBannerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: '#0F2744'.excelColor,
      backgroundColorHex: '#E2E8F0'.excelColor,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final metaLabelStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: '#334155'.excelColor,
      backgroundColorHex: '#F8FAFC'.excelColor,
      verticalAlign: VerticalAlign.Center,
    );

    final metaValueStyle = CellStyle(
      fontSize: 10,
      fontColorHex: '#0F172A'.excelColor,
      backgroundColorHex: ExcelColor.white,
      verticalAlign: VerticalAlign.Center,
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: '#0F2744'.excelColor,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: '#001229'.excelColor),
    );

    final borderThin = Border(borderStyle: BorderStyle.Thin, borderColorHex: '#CBD5E1'.excelColor);

    final dataCellCenter = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    final dataCellLeft = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    final dataCellRight = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    final summaryHeaderStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: '#1E293B'.excelColor,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final summaryLabelStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: '#1E293B'.excelColor,
      backgroundColorHex: '#F1F5F9'.excelColor,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    final summaryValueStyle = CellStyle(
      fontSize: 10,
      fontColorHex: '#0F172A'.excelColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    final summaryGrandTotalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: '#991B1B'.excelColor,
      backgroundColorHex: '#FEE2E2'.excelColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    // Ajustar anchos de columnas
    sheet.setColumnWidth(0, 13.0); // Fecha
    sheet.setColumnWidth(1, 7.0);  // Día
    sheet.setColumnWidth(2, 17.0); // Turno Asignado
    sheet.setColumnWidth(3, 14.0); // Hora Check-in
    sheet.setColumnWidth(4, 28.0); // Coordenadas
    sheet.setColumnWidth(5, 15.0); // Estado
    sheet.setColumnWidth(6, 14.0); // Min. Tardanza
    sheet.setColumnWidth(7, 16.0); // Descuento (Bs)

    // ==========================================
    // 1. ENCABEZADO INSTITUCIONAL Y METADATOS
    // ==========================================
    // Fila 0: Banner título
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('ELITE MULTISERVICIOS S.R.L.'),
      cellStyle: titleBannerStyle,
    );
    for (int c = 1; c <= 7; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        null,
        cellStyle: titleBannerStyle,
      );
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0),
    );
    sheet.setRowHeight(0, 26.0);

    // Fila 1: Subtítulo
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      TextCellValue('REPORTE MENSUAL DE ASISTENCIA Y CONTROL DE DESCUENTOS'),
      cellStyle: subBannerStyle,
    );
    for (int c = 1; c <= 7; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
        null,
        cellStyle: subBannerStyle,
      );
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1),
    );
    sheet.setRowHeight(1, 20.0);

    // Fecha generación (UTC - 4h para Bolivia)
    final nowBolivia = DateTime.now().toUtc().subtract(const Duration(hours: 4));
    final genDateStr =
        '${nowBolivia.year}-${nowBolivia.month.toString().padLeft(2, '0')}-${nowBolivia.day.toString().padLeft(2, '0')} '
        '${nowBolivia.hour.toString().padLeft(2, '0')}:${nowBolivia.minute.toString().padLeft(2, '0')}';
    final monthName = (month >= 1 && month <= 12) ? _monthNames[month - 1] : '$month';
    final cargoStr = '${employee.department} (${employee.employeeType == 'office' ? 'Oficina' : 'Campo'})';

    // Fila 3: Colaborador y Cargo
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3), TextCellValue('Empleado:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3), TextCellValue(employee.fullName), cellStyle: metaValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3), TextCellValue('Cargo / Depto:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3), TextCellValue(cargoStr), cellStyle: metaValueStyle);

    // Fila 4: CI y Período
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4), TextCellValue('CI:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4), TextCellValue('N/D'), cellStyle: metaValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4), TextCellValue('Período:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 4), TextCellValue('$monthName $year'), cellStyle: metaValueStyle);

    // Fila 5: Generación y Correo
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5), TextCellValue('Fecha Generación:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5), TextCellValue(genDateStr), cellStyle: metaValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 5), TextCellValue('Correo:'), cellStyle: metaLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 5), TextCellValue(employee.email), cellStyle: metaValueStyle);

    // ==========================================
    // 2. TABLA DIARIA DE ASISTENCIAS
    // ==========================================
    const int tableStartRow = 7;
    final headers = [
      'Fecha',
      'Día',
      'Turno Asignado',
      'Hora Entrada',
      'Coordenadas Logueo',
      'Estado',
      'Min. Tardanza',
      'Descuento (Bs)',
    ];

    for (int c = 0; c < headers.length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: tableStartRow),
        TextCellValue(headers[c]),
        cellStyle: tableHeaderStyle,
      );
    }
    sheet.setRowHeight(tableStartRow, 22.0);

    int currentRow = tableStartRow + 1;
    for (final detail in dailyDetails) {
      final dayName = _getDayName(detail.date.weekday);

      // Estilo de estado según la regla
      ExcelColor statusBg = ExcelColor.white;
      ExcelColor statusFg = ExcelColor.black;
      if (detail.status == 'Presente') {
        statusBg = '#ECFDF5'.excelColor;
        statusFg = '#065F46'.excelColor;
      } else if (detail.status == 'Tarde' || detail.status == 'Tardanza') {
        statusBg = '#FEF3C7'.excelColor;
        statusFg = '#92400E'.excelColor;
      } else if (detail.status == 'Falta') {
        statusBg = '#FEE2E2'.excelColor;
        statusFg = '#991B1B'.excelColor;
      } else if (detail.status == 'Permiso') {
        statusBg = '#DDE9FF'.excelColor;
        statusFg = '#0051D5'.excelColor;
      } else if (detail.status == 'Domingo' || detail.status == 'Sin turno') {
        statusBg = '#F1F5F9'.excelColor;
        statusFg = '#64748B'.excelColor;
      }

      final statusStyle = CellStyle(
        bold: detail.status == 'Falta' || detail.status == 'Tarde',
        fontSize: 10,
        fontColorHex: statusFg,
        backgroundColorHex: statusBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borderThin,
        rightBorder: borderThin,
        topBorder: borderThin,
        bottomBorder: borderThin,
      );

      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue(detail.dateStr), cellStyle: dataCellCenter);
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), TextCellValue(dayName), cellStyle: dataCellCenter);
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow), TextCellValue(detail.shiftSchedule), cellStyle: dataCellCenter);
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow), TextCellValue(detail.checkIn), cellStyle: dataCellCenter);
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue(detail.coordinates), cellStyle: dataCellLeft);
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow), TextCellValue(detail.status), cellStyle: statusStyle);
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
        detail.lateMinutes > 0 ? IntCellValue(detail.lateMinutes) : TextCellValue('0'),
        cellStyle: dataCellCenter,
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
        DoubleCellValue(detail.discount),
        cellStyle: dataCellRight,
      );

      sheet.setRowHeight(currentRow, 18.0);
      currentRow++;
    }

    // ==========================================
    // 3. RESUMEN AL FINAL Y TOTALES
    // ==========================================
    currentRow++; // Espaciador

    // Encabezado del resumen
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      TextCellValue('RESUMEN MENSUAL Y LIQUIDACIÓN'),
      cellStyle: summaryHeaderStyle,
    );
    for (int c = 1; c <= 7; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow),
        null,
        cellStyle: summaryHeaderStyle,
      );
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
    );
    sheet.setRowHeight(currentRow, 22.0);
    currentRow++;

    // Extraer métricas desde el resumen
    final totalAbsences = (summary['total_absences'] as num?)?.toInt() ?? 0;
    final totalAbsenceFee = (summary['total_absence_fee'] as num?)?.toDouble() ?? (totalAbsences * 200.0);
    final totalLateMinutes = (summary['total_late_minutes'] as num?)?.toInt() ?? 0;
    final totalLateFee = (summary['total_late_fee'] as num?)?.toDouble() ?? 0.0;
    final totalToleranceMinutes = (summary['total_tolerance_minutes'] as num?)?.toInt() ?? 0;
    final totalAccumulatedFee = (summary['total_accumulated_fee'] as num?)?.toDouble() ?? 0.0;
    final totalEarlyLeaveMinutes = (summary['total_early_leave_minutes'] as num?)?.toInt() ?? 0;
    final grandTotalFee = (summary['grand_total_fee'] as num?)?.toDouble() ?? (totalLateFee + totalAccumulatedFee + totalAbsenceFee);

    final presentDaysCount = dailyDetails.where((d) => d.status == 'Presente' || d.status == 'Tarde' || d.status == 'Tardanza').length;
    final permissionsCount = dailyDetails.where((d) => d.status == 'Permiso').length;

    // Fila Resumen 1: Asistencias y Faltas
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('Total Asistencias:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), IntCellValue(presentDaysCount), cellStyle: summaryValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Total Faltas:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
      TextCellValue('$totalAbsences (Bs. ${totalAbsenceFee.toStringAsFixed(2)})'),
      cellStyle: summaryValueStyle,
    );
    currentRow++;

    // Fila Resumen 2: Tardanzas
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('Minutos Tardanza:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), TextCellValue('$totalLateMinutes min'), cellStyle: summaryValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Descuento Tardanzas:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow), DoubleCellValue(totalLateFee), cellStyle: summaryValueStyle);
    currentRow++;

    // Fila Resumen 3: Tolerancias y Penalidad
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('Tolerancia Usada:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), TextCellValue('$totalToleranceMinutes min'), cellStyle: summaryValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Penalidad Tolerancia (>=60m):'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow), DoubleCellValue(totalAccumulatedFee), cellStyle: summaryValueStyle);
    currentRow++;

    // Fila Resumen 4: Permisos y Salidas Anticipadas
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('Total Permisos:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), IntCellValue(permissionsCount), cellStyle: summaryValueStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Salidas Anticipadas:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow), TextCellValue('$totalEarlyLeaveMinutes min'), cellStyle: summaryValueStyle);
    currentRow++;

    final sueldoInputStyle = CellStyle(
      fontSize: 10,
      fontColorHex: '#0F172A'.excelColor,
      backgroundColorHex: '#FEF9C3'.excelColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borderThin,
      rightBorder: borderThin,
      topBorder: borderThin,
      bottomBorder: borderThin,
    );

    // Fila Resumen 5: Total Descuento y Sueldo Base
    final int excelDescuentoRowNum = currentRow + 1;
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('TOTAL DESCUENTO (Bs):'), cellStyle: summaryGrandTotalStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow), DoubleCellValue(grandTotalFee), cellStyle: summaryGrandTotalStyle);
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Sueldo Base (Bs):'), cellStyle: summaryLabelStyle);
    // Dejar la celda de Sueldo Base vacía lista para que el administrador ingrese el valor
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow), null, cellStyle: sueldoInputStyle);
    currentRow++;

    // Fila Resumen 6: Total a Pagar con fórmula segura (sin error #¡VALOR!)
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow), TextCellValue('TOTAL A PAGAR (Bs):'), cellStyle: summaryLabelStyle);
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
      FormulaCellValue('IF(ISNUMBER(F$excelDescuentoRowNum), F$excelDescuentoRowNum - B$excelDescuentoRowNum, "Ingrese Sueldo")'),
      cellStyle: summaryValueStyle,
    );
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow), TextCellValue('Observación:'), cellStyle: summaryLabelStyle);
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
      TextCellValue('Ingresar sueldo en celda F$excelDescuentoRowNum para liquidar'),
      cellStyle: summaryValueStyle,
    );

    // ==========================================
    // 4. GUARDAR Y LANZAR ARCHIVO
    // ==========================================
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final sanitizedName = employee.fullName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = 'Reporte_${sanitizedName}_${monthName}_$year.xlsx';
      await saveAndLaunchFile(fileBytes, fileName);
    }
  }
}
