// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addCard => 'Add card';

  @override
  String get noCardsMessage =>
      'You don\'t have any saved cards.\nAdd your first card to get started.';

  @override
  String get createFirstCard => 'Create first card';

  @override
  String get refresh => 'Refresh';

  @override
  String get balance => 'Balance';

  @override
  String get balanceUnknown => 'Unknown';

  @override
  String get lastUpdate => 'Last update';

  @override
  String get neverUpdated => 'Never updated';

  @override
  String get createCardTitle => 'Create New Card';

  @override
  String get back => 'Back';

  @override
  String get cardIdLabel => 'Card ID *';

  @override
  String get cardIdPlaceholder => 'Enter card ID';

  @override
  String get cardPrefixLabel => 'Prefix';

  @override
  String get cardPrefixPlaceholder => 'Optional prefix';

  @override
  String get cardSuffixLabel => 'Suffix';

  @override
  String get cardSuffixPlaceholder => 'Optional suffix';

  @override
  String get cardNameLabel => 'Name *';

  @override
  String get cardNamePlaceholder => 'Card name';

  @override
  String get cardPositionLabel => 'Position';

  @override
  String get cardPositionPlaceholder => 'Display position';

  @override
  String get createCardButton => 'Create Card';

  @override
  String get creatingCard => 'Creating...';

  @override
  String get idRequired => 'ID is required';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get errorNetwork => 'Network error. Check your internet connection.';

  @override
  String get errorUnknown => 'An unknown error occurred';

  @override
  String get errorApi => 'Server error. Please try again later.';

  @override
  String get editCard => 'Edit card';

  @override
  String get deleteCard => 'Delete card';

  @override
  String get editCardTitle => 'Edit Card';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get savingCard => 'Saving...';

  @override
  String get deleteCardTitle => 'Delete Card';

  @override
  String deleteCardMessage(String cardName) {
    return 'Are you sure you want to delete \"$cardName\"? This action cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deletingCard => 'Deleting...';

  @override
  String get newCard => 'New card';

  @override
  String get noCards => 'No cards';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemDesc => 'Follow device settings';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightDesc => 'Light theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkDesc => 'Dark theme';

  @override
  String get fare => 'Fare';

  @override
  String get farePrice => 'Fare price';

  @override
  String get farePriceDesc =>
      'Used to calculate how many fares your balance covers';

  @override
  String get data => 'Data';

  @override
  String get exportData => 'Export data';

  @override
  String get exportDataDesc => 'Back up cards, stops and settings';

  @override
  String get importData => 'Import data';

  @override
  String get importDataDesc => 'Restore from a backup file';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get nothingToExport => 'There is nothing to export';

  @override
  String get importError => 'Import error';

  @override
  String importedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count item$_temp0 imported';
  }

  @override
  String get noNewItemsImported => 'Nothing new to import';

  @override
  String get couldNotUpdateBalance => 'Could not update balance';

  @override
  String get name => 'NAME';

  @override
  String fares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count fare$_temp0';
  }

  @override
  String updatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String updatedAt(String datetime) {
    return 'Updated: $datetime';
  }

  @override
  String get updateBalance => 'Update balance';

  @override
  String get edit => 'Edit';

  @override
  String get cardIdExists => 'A card with this ID already exists';

  @override
  String get createCardError => 'Error creating card';

  @override
  String get saveChangesError => 'Error saving changes';

  @override
  String get farePriceUpdated => 'Fare price updated';

  @override
  String get balanceUpdated => 'Balance updated';

  @override
  String get retry => 'Retry';

  @override
  String get networkErrorMessage =>
      'No connection. Check your internet and try again.';

  @override
  String get serverErrorMessage =>
      'Balance service is unavailable. Try again later.';

  @override
  String get cardNotFoundMessage =>
      'No balance information found for this card.';

  @override
  String get rateLimitMessage =>
      'Service query limit reached. Wait a few minutes and try again.';

  @override
  String get invalidCardMessage =>
      'Invalid card number. It must have exactly 13 digits.';

  @override
  String get staleBalanceNotice => 'Last known balance';

  @override
  String get stops => 'Stops';

  @override
  String get favoriteStops => 'Favorite stops';

  @override
  String get addStop => 'Add stop';

  @override
  String get noFavoriteStops => 'No saved stops';

  @override
  String get noFavoriteStopsMessage =>
      'Save the stops you use and see the next buses here.';

  @override
  String get nearbyStops => 'Near me';

  @override
  String get stationCatalog => 'Stations';

  @override
  String get searchStation => 'Search station';

  @override
  String get noStopsNearby => 'No stops within 300 m';

  @override
  String get noBusesComing => 'No buses coming';

  @override
  String get arrivingNow => 'Now';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String metersAway(int meters) {
    return '$meters m';
  }

  @override
  String get locationUnavailable => 'Turn on location to find nearby stops.';

  @override
  String get locationDeniedForever =>
      'Enable the location permission in system settings.';

  @override
  String get couldNotLoadArrivals => 'Could not load arrivals';

  @override
  String get stopSaved => 'Stop saved';

  @override
  String get stopAlreadySaved => 'That stop is already saved';

  @override
  String get removeStop => 'Remove stop';

  @override
  String get mapTab => 'Map';

  @override
  String get searchHere => 'Search here';

  @override
  String get linesServing => 'Lines';

  @override
  String get noLinesForStop => 'No lines listed';

  @override
  String get saveAsFavorite => 'Save as favorite';

  @override
  String get saveThisArea => 'Save this area';

  @override
  String get areaName => 'Area name';

  @override
  String get mapHint => 'Move the map and search to see stops anywhere';

  @override
  String get save => 'Save';

  @override
  String get homeScreen => 'Home screen';

  @override
  String get homeScreenDesc => 'What to show when the app opens';

  @override
  String get homeCardsOnly => 'Cards only';

  @override
  String get homeStopsOnly => 'Favorite stops only';

  @override
  String get homeBoth => 'Cards and stops';

  @override
  String get myCards => 'My cards';

  @override
  String get seeAll => 'See all';

  @override
  String get editStop => 'Edit stop';

  @override
  String get customNameLabel => 'Custom name';

  @override
  String get customNameHint => 'Leave it empty to use the real name';

  @override
  String get myLocation => 'My location';

  @override
  String get stopDetails => 'Stop details';

  @override
  String get resetNorth => 'Face north';

  @override
  String get madeBy => 'by Yenreh';

  @override
  String get licenses => 'Open source licenses';

  @override
  String get stopNotReported => 'This stop is no longer reported';

  @override
  String get relinkStop => 'Link to another stop';

  @override
  String get cache => 'Cached data';

  @override
  String get cacheDesc => 'Stations, lines and stop positions';

  @override
  String get clearCache => 'Clear';

  @override
  String get cacheCleared => 'Cached data cleared';

  @override
  String get arrivalsUnknown => 'No arrivals yet';

  @override
  String get sortByProximity => 'Closest stops first';

  @override
  String get sortByProximityDesc =>
      'Uses the location when it is already available. Off, stops keep your own order: hold one and drag it to change it';

  @override
  String get showOnHome => 'Show on home';

  @override
  String get hideFromHome => 'Hide from home';

  @override
  String get hiddenFromHome => 'Not on home';

  @override
  String get darkMap => 'Dark map';

  @override
  String get darkMapDesc =>
      'Dark tiles on the stops map, whatever the app theme';

  @override
  String get sharpMap => 'Sharp map';

  @override
  String get sharpMapDesc =>
      'Maps at the screen\'s full resolution. Off, they use less mobile data and look a little softer';

  @override
  String get findStops => 'Find stops';

  @override
  String get favoritesShort => 'Favorites';

  @override
  String get mapCredits => 'Map credits';

  @override
  String get updateArrivals => 'Update arrivals';

  @override
  String get linesToShow => 'Lines to show';

  @override
  String get linesToShowHint => 'With none chosen, every line shows';

  @override
  String get noBusesOfLines => 'None of these lines is coming';

  @override
  String get linesTab => 'Lines';

  @override
  String get searchLine => 'Search line';

  @override
  String get lineRunningNow => 'Running now';

  @override
  String get lineNotRunning => 'Not running now';

  @override
  String lineRuns(String start, String end) {
    return 'Runs $start–$end';
  }

  @override
  String busesThisWay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses this way',
      one: '1 bus this way',
      zero: 'No buses this way',
    );
    return '$_temp0';
  }

  @override
  String towards(String stop) {
    return 'To $stop';
  }

  @override
  String get noLineRoute => 'No route for this line';

  @override
  String get updateBusPositions => 'Update bus positions';

  @override
  String get unofficialNotice =>
      'Unofficial app, not affiliated with Metro Cali. Arrivals, balances and routes come from its public services and may not be accurate.';

  @override
  String dataFrom(String source) {
    return 'Data: $source';
  }

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String upToDate(String version) {
    return 'You have the latest version ($version)';
  }

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String downloadUpdate(String version) {
    return 'Download $version';
  }

  @override
  String get updateInstallHint =>
      'Open the downloaded file to install it over this version; your data stays.';

  @override
  String get noReleasesYet => 'No releases published yet';

  @override
  String get updateCheckFailed => 'Could not check for updates';

  @override
  String get refreshBalancesOnOpen => 'Refresh balances on opening';

  @override
  String get refreshBalancesOnOpenDesc =>
      'Asks for every card\'s balance each time the app opens';

  @override
  String get cardsShort => 'Cards';

  @override
  String get planTrip => 'Plan a trip';

  @override
  String get chooseOrigin => 'Where from?';

  @override
  String get chooseDestination => 'Where to?';

  @override
  String get swapPlaces => 'Swap origin and destination';

  @override
  String get pickOnMap => 'Pick on the map';

  @override
  String get usePoint => 'Use this point';

  @override
  String get pointOnMap => 'Point on the map';

  @override
  String nearStop(String stop) {
    return 'Near $stop';
  }

  @override
  String get searchPlace => 'Search a station, stop or address';

  @override
  String searchAsAddress(String text) {
    return 'Search “$text” as an address or place';
  }

  @override
  String get addressesSection => 'Addresses and places';

  @override
  String get addressCrossing => 'Crossing of its two streets, approximate';

  @override
  String get addressNearStop => 'MIO stop at that crossing, approximate';

  @override
  String get addressNotFound =>
      'Nothing found. Try a crossing, such as “Calle 5 con Carrera 38”, or pick the point on the map.';

  @override
  String get stopsSection => 'Stops';

  @override
  String loadingRoutes(int done, int total) {
    return 'Loading MIO routes ($done/$total)';
  }

  @override
  String get planHint =>
      'Choose where you leave from and where you are going to see how to get there.';

  @override
  String get noTripFound =>
      'No MIO trip found between these two places at this time.';

  @override
  String get tripEstimateNote =>
      'Live times from MIO. Anything marked ~ is approximate: no bus on its way confirms it, so the line\'s usual figures are used.';

  @override
  String arriveAround(String time) {
    return 'Arrive ~$time';
  }

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
      zero: 'Direct',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m on foot';
  }

  @override
  String nextBusNow(String line) {
    return '$line arriving';
  }

  @override
  String stepWalkTo(int minutes, String stop) {
    return 'Walk $minutes min to $stop';
  }

  @override
  String stepWalkToDestination(int minutes) {
    return 'Walk $minutes min to your destination';
  }

  @override
  String stepRide(String lines, String towards) {
    return 'Take $lines towards $towards';
  }

  @override
  String stepGetOff(String stop) {
    return 'Get off at $stop';
  }

  @override
  String get couldNotLocate => 'Could not get your location';

  @override
  String get openInGoogleMaps => 'Open this search in Google Maps';

  @override
  String get goHere => 'Go here';

  @override
  String get updateLocation => 'Update my location';

  @override
  String get lineChoiceHint =>
      'Any of these lines will do; tap one to see its route';

  @override
  String get refreshTimes => 'Update times';

  @override
  String get liveUnavailable =>
      'No live MIO data for some stretches: those times are approximate.';

  @override
  String arriveAt(String time) {
    return 'Arrive $time';
  }

  @override
  String busLeavesAt(String line, String time, int minutes) {
    return '$line at $time (in $minutes min)';
  }

  @override
  String noLiveBus(int minutes) {
    return 'No live bus · about $minutes min wait';
  }

  @override
  String leavesAt(String time) {
    return 'Leaves $time';
  }

  @override
  String waitAbout(int minutes) {
    return 'Wait ~$minutes min';
  }

  @override
  String stopsCount(int stops) {
    String _temp0 = intl.Intl.pluralLogic(
      stops,
      locale: localeName,
      other: '$stops stops',
      one: '1 stop',
    );
    return '$_temp0';
  }
}
