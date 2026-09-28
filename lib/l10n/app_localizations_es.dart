// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get addCard => 'Agregar tarjeta';

  @override
  String get noCardsMessage =>
      'No tienes tarjetas guardadas.\nAgrega tu primera tarjeta para comenzar.';

  @override
  String get createFirstCard => 'Crear primera tarjeta';

  @override
  String get refresh => 'Actualizar';

  @override
  String get balance => 'Saldo';

  @override
  String get balanceUnknown => 'Desconocido';

  @override
  String get lastUpdate => 'Ultima actualizacion';

  @override
  String get neverUpdated => 'Nunca actualizado';

  @override
  String get createCardTitle => 'Crear Nueva Tarjeta';

  @override
  String get back => 'Atras';

  @override
  String get cardIdLabel => 'ID de Tarjeta *';

  @override
  String get cardIdPlaceholder => 'Ingresa el ID de la tarjeta';

  @override
  String get cardPrefixLabel => 'Prefijo';

  @override
  String get cardPrefixPlaceholder => 'Prefijo opcional';

  @override
  String get cardSuffixLabel => 'Sufijo';

  @override
  String get cardSuffixPlaceholder => 'Sufijo opcional';

  @override
  String get cardNameLabel => 'Nombre *';

  @override
  String get cardNamePlaceholder => 'Nombre de la tarjeta';

  @override
  String get cardPositionLabel => 'Posicion';

  @override
  String get cardPositionPlaceholder => 'Posicion de visualizacion';

  @override
  String get createCardButton => 'Crear Tarjeta';

  @override
  String get creatingCard => 'Creando...';

  @override
  String get idRequired => 'El ID es obligatorio';

  @override
  String get nameRequired => 'El nombre es obligatorio';

  @override
  String get errorNetwork => 'Error de conexion. Verifica tu internet.';

  @override
  String get errorUnknown => 'Ha ocurrido un error desconocido';

  @override
  String get errorApi => 'Error del servidor. Intentalo mas tarde.';

  @override
  String get editCard => 'Editar tarjeta';

  @override
  String get deleteCard => 'Eliminar tarjeta';

  @override
  String get editCardTitle => 'Editar Tarjeta';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get savingCard => 'Guardando...';

  @override
  String get deleteCardTitle => 'Eliminar Tarjeta';

  @override
  String deleteCardMessage(String cardName) {
    return 'Estas seguro de que quieres eliminar \"$cardName\"? Esta accion no se puede deshacer.';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deletingCard => 'Eliminando...';

  @override
  String get newCard => 'Nueva tarjeta';

  @override
  String get noCards => 'Sin tarjetas';

  @override
  String get settings => 'Configuracion';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeSystemDesc => 'Seguir configuracion del dispositivo';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeLightDesc => 'Tema claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeDarkDesc => 'Tema oscuro';

  @override
  String get fare => 'Pasaje';

  @override
  String get farePrice => 'Valor del pasaje';

  @override
  String get farePriceDesc =>
      'Se usa para calcular cuantos pasajes te alcanza el saldo';

  @override
  String get data => 'Datos';

  @override
  String get exportData => 'Exportar datos';

  @override
  String get exportDataDesc => 'Copia de tarjetas, paradas y ajustes';

  @override
  String get importData => 'Importar datos';

  @override
  String get importDataDesc => 'Restaurar desde un archivo';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Version';

  @override
  String get nothingToExport => 'No hay datos para exportar';

  @override
  String get importError => 'Error al importar';

  @override
  String importedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count elemento$_temp0 importado$_temp1';
  }

  @override
  String get noNewItemsImported => 'No hay nada nuevo para importar';

  @override
  String get couldNotUpdateBalance => 'No se pudo actualizar el saldo';

  @override
  String get name => 'NOMBRE';

  @override
  String fares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count pasaje$_temp0';
  }

  @override
  String updatedAgo(String time) {
    return 'Actualizado $time';
  }

  @override
  String updatedAt(String datetime) {
    return 'Actualizado: $datetime';
  }

  @override
  String get updateBalance => 'Actualizar saldo';

  @override
  String get edit => 'Editar';

  @override
  String get cardIdExists => 'Ya existe una tarjeta con este ID';

  @override
  String get createCardError => 'Error al crear la tarjeta';

  @override
  String get saveChangesError => 'Error al guardar los cambios';

  @override
  String get farePriceUpdated => 'Valor del pasaje actualizado';

  @override
  String get balanceUpdated => 'Saldo actualizado';

  @override
  String get retry => 'Reintentar';

  @override
  String get networkErrorMessage =>
      'Sin conexión. Revisa tu internet e inténtalo de nuevo.';

  @override
  String get serverErrorMessage =>
      'El servicio de saldos no está disponible. Intenta más tarde.';

  @override
  String get cardNotFoundMessage =>
      'No se encontró información de saldo para esta tarjeta.';

  @override
  String get rateLimitMessage =>
      'Límite de consultas del servicio alcanzado. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get invalidCardMessage =>
      'Número de tarjeta inválido. Debe tener exactamente 13 dígitos.';

  @override
  String get staleBalanceNotice => 'Último saldo conocido';

  @override
  String get stops => 'Paradas';

  @override
  String get favoriteStops => 'Paradas favoritas';

  @override
  String get addStop => 'Agregar parada';

  @override
  String get noFavoriteStops => 'Sin paradas guardadas';

  @override
  String get noFavoriteStopsMessage =>
      'Guarda las paradas que usas y mira aquí los próximos buses.';

  @override
  String get nearbyStops => 'Cerca de mí';

  @override
  String get stationCatalog => 'Estaciones';

  @override
  String get searchStation => 'Buscar estación';

  @override
  String get noStopsNearby => 'No hay paradas a menos de 300 m';

  @override
  String get noBusesComing => 'Sin buses próximos';

  @override
  String get arrivingNow => 'Ya';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String metersAway(int meters) {
    return '$meters m';
  }

  @override
  String get locationUnavailable =>
      'Activa la ubicación para encontrar paradas cercanas.';

  @override
  String get locationDeniedForever =>
      'Habilita el permiso de ubicación en los ajustes del sistema.';

  @override
  String get couldNotLoadArrivals => 'No se pudieron cargar las llegadas';

  @override
  String get stopSaved => 'Parada guardada';

  @override
  String get stopAlreadySaved => 'Esa parada ya está guardada';

  @override
  String get removeStop => 'Quitar parada';

  @override
  String get mapTab => 'Mapa';

  @override
  String get searchHere => 'Buscar aquí';

  @override
  String get linesServing => 'Rutas';

  @override
  String get noLinesForStop => 'Sin rutas registradas';

  @override
  String get saveAsFavorite => 'Guardar como favorita';

  @override
  String get saveThisArea => 'Guardar esta zona';

  @override
  String get areaName => 'Nombre de la zona';

  @override
  String get mapHint =>
      'Mueve el mapa y busca para ver paradas en cualquier lugar';

  @override
  String get save => 'Guardar';

  @override
  String get homeScreen => 'Pantalla de inicio';

  @override
  String get homeScreenDesc => 'Qué mostrar al abrir la app';

  @override
  String get homeCardsOnly => 'Solo tarjetas';

  @override
  String get homeStopsOnly => 'Solo paradas favoritas';

  @override
  String get homeBoth => 'Tarjetas y paradas';

  @override
  String get myCards => 'Mis tarjetas';

  @override
  String get seeAll => 'Ver todas';

  @override
  String get editStop => 'Editar parada';

  @override
  String get customNameLabel => 'Nombre personalizado';

  @override
  String get customNameHint => 'Déjalo vacío para usar el nombre real';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get stopDetails => 'Detalles de la parada';

  @override
  String get resetNorth => 'Orientar al norte';

  @override
  String get madeBy => 'by Yenreh';

  @override
  String get licenses => 'Licencias de código abierto';

  @override
  String get stopNotReported => 'El servicio ya no reporta esta parada';

  @override
  String get relinkStop => 'Vincular a otra parada';

  @override
  String get cache => 'Datos en caché';

  @override
  String get cacheDesc => 'Estaciones, rutas y posiciones de paradas';

  @override
  String get clearCache => 'Borrar';

  @override
  String get cacheCleared => 'Caché borrada';

  @override
  String get arrivalsUnknown => 'Sin datos de llegadas';

  @override
  String get sortByProximity => 'Paradas más cercanas primero';

  @override
  String get sortByProximityDesc =>
      'Usa la ubicación si ya está disponible. Apagado, las paradas siguen tu orden: mantén pulsada una y arrástrala para cambiarlo';

  @override
  String get showOnHome => 'Mostrar en inicio';

  @override
  String get hideFromHome => 'Ocultar del inicio';

  @override
  String get hiddenFromHome => 'No aparece en inicio';

  @override
  String get darkMap => 'Mapa oscuro';

  @override
  String get darkMapDesc =>
      'Mapa de paradas con fondo oscuro, sin importar el tema de la app';

  @override
  String get findStops => 'Buscar paradas';

  @override
  String get favoritesShort => 'Favoritos';

  @override
  String get mapCredits => 'Créditos del mapa';

  @override
  String get updateArrivals => 'Actualizar llegadas';

  @override
  String get linesToShow => 'Líneas a mostrar';

  @override
  String get linesToShowHint => 'Sin ninguna elegida se muestran todas';

  @override
  String get noBusesOfLines => 'No viene ninguna de estas líneas';

  @override
  String get linesTab => 'Líneas';

  @override
  String get searchLine => 'Buscar línea';

  @override
  String get lineRunningNow => 'Operando ahora';

  @override
  String get lineNotRunning => 'No opera ahora';

  @override
  String lineRuns(String start, String end) {
    return 'Opera $start–$end';
  }

  @override
  String busesThisWay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses en este sentido',
      one: '1 bus en este sentido',
      zero: 'Ningún bus en este sentido',
    );
    return '$_temp0';
  }

  @override
  String towards(String stop) {
    return 'Hacia $stop';
  }

  @override
  String get noLineRoute => 'No hay recorrido para esta línea';

  @override
  String get updateBusPositions => 'Actualizar posición de los buses';

  @override
  String get unofficialNotice =>
      'App no oficial, sin relación con Metro Cali. Las llegadas, saldos y rutas vienen de sus servicios públicos y pueden no ser exactos.';

  @override
  String dataFrom(String source) {
    return 'Datos: $source';
  }

  @override
  String get checkUpdates => 'Buscar actualizaciones';

  @override
  String upToDate(String version) {
    return 'Tienes la última versión ($version)';
  }

  @override
  String updateAvailable(String version) {
    return 'Está disponible la versión $version';
  }

  @override
  String downloadUpdate(String version) {
    return 'Descargar $version';
  }

  @override
  String get updateInstallHint =>
      'Abre el archivo descargado para instalarlo sobre esta versión; tus datos se conservan.';

  @override
  String get noReleasesYet => 'Aún no hay versiones publicadas';

  @override
  String get updateCheckFailed => 'No se pudo buscar actualizaciones';

  @override
  String get refreshBalancesOnOpen => 'Actualizar saldos al abrir';

  @override
  String get refreshBalancesOnOpenDesc =>
      'Consulta el saldo de cada tarjeta al abrir la app, o al volver a ella tras 5 minutos o más';
}
