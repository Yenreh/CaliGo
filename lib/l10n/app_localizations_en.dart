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
}
