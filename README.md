# App de Control de Asistencia - Elite Multiservicios

Aplicación desarrollada en Flutter para la gestión de asistencia, turnos y cálculo de nómina del personal.

## Stack Tecnológico
- **Frontend:** Flutter (Dart)
- **Backend / Base de Datos:** Supabase (PostgreSQL)
- **Reportes:** Generación de archivos Excel (`.xlsx`)

## Características Principales
- Registro de entrada y salida.
- Gestión de empleados (contratos, bajas).
- Asignación de turnos y visualización en mapa.
- Cálculo automático de tardanzas, faltas y tolerancias.
- Generación de resúmenes mensuales de descuentos.

##  Retos Técnicos Resueltos
- **Manejo de fechas:** Implementé normalización de fechas en las consultas a Supabase para evitar errores de cálculo en días con turnos asignados.
- **Lógica de negocio:** Desarrollo de la lógica para calcular multas por tardanza y faltas, excluyendo domingos y días sin turno.
- **Exportación de datos:** Integración de la librería `excel` para generar reportes con fórmulas y coordenadas de logueo.

## Autor
Juan Antonio Barja S - Estudiante de Ingeniería de Sistemas.
