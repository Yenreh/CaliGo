# CaliGo

Una aplicación Flutter para consultar tarjetas, paradas y líneas del MIO,
el sistema de transporte masivo de Cali.

> App no oficial, sin relación con Metro Cali S.A. Los datos vienen de sus
> servicios públicos ([metrocali.gov.co](https://www.metrocali.gov.co)) y
> pueden no ser exactos. Sin fines comerciales.

## Características

- **Gestión de Tarjetas**: Crear, ver, editar y eliminar tarjetas de transporte
- **Consulta de Saldo**: Desde el servicio público de Metrocali
- **Paradas Favoritas**: Tablero con los próximos buses de cada parada guardada
- **Mapa**: Buscar paradas en cualquier punto de la ciudad, sobre mapas de CARTO
- **Líneas**: Recorrido de cada línea, sus buses en vivo y su horario
- **Almacenamiento Local**: Persistencia usando SQLite (sqflite)
- **Soporte Multilenguaje**: Español e Inglés
- **Diseño**: estilo "lab report" compartido con NetSpeedDiag y las extensiones
- **Dark Mode**: Tema oscuro automático según el sistema

## Stack Tecnológico

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Base de Datos**: SQLite (sqflite)
- **Networking**: http package
- **Mapas**: flutter_map sobre teselas de OpenStreetMap
- **Ubicación**: geolocator
- **Navegación**: go_router
- **Tipografías**: Google Fonts (Inter)

## Estructura del Proyecto

```
lib/
├── core/                    # Utilidades compartidas
│   ├── theme/               # Tema y estilos
│   └── utils/               # Utilidades
├── data/                    # Data Layer
│   ├── datasources/         # Fuentes de datos
│   ├── models/              # DTOs
│   └── repositories/        # Implementaciones
├── domain/                  # Domain Layer
│   ├── entities/            # Entidades
│   └── repositories/        # Interfaces
├── presentation/            # Presentation Layer
│   ├── providers/           # Riverpod providers
│   ├── screens/             # Pantallas
│   ├── widgets/             # Componentes
│   └── routes/              # Navegación
├── l10n/                    # Localización
└── main.dart                # Entry point
```

## Instalación

1. Asegúrate de tener Flutter instalado
2. Clona el repositorio
3. Ejecuta `flutter pub get`
4. Ejecuta `flutter run`

## Comandos

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Compilar APK
flutter build apk

# Compilar para iOS
flutter build ios
```

## Datos

Todos los datos vienen de servicios públicos de Metro Cali S.A., que
permite reutilizar su información con fines informativos y no comerciales,
citando la fuente con un enlace a [metrocali.gov.co](https://www.metrocali.gov.co).
Qué servicios se consultan y cómo, en [docs/api.md](docs/api.md).

## Licencia

CaliGo es software libre bajo la [GNU GPL v3 o posterior](LICENSE):
cualquiera puede usarlo, estudiarlo, modificarlo y redistribuirlo, siempre
que conserve este aviso y que lo que publique con este código siga siendo
libre, con su fuente disponible bajo la misma licencia.

```
CaliGo
Copyright (C) 2026 Yenreh

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

Las fuentes (Fraunces, IBM Plex Sans y Mono) tienen su propia licencia OFL,
en `assets/fonts`. Los mapas son de © OpenStreetMap y © CARTO, y los datos
de transporte pertenecen a Metrocali.
