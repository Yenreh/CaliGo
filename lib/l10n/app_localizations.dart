import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get addCard;

  /// No description provided for @noCardsMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any saved cards.\nAdd your first card to get started.'**
  String get noCardsMessage;

  /// No description provided for @createFirstCard.
  ///
  /// In en, this message translates to:
  /// **'Create first card'**
  String get createFirstCard;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @balanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get balanceUnknown;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get lastUpdate;

  /// No description provided for @neverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Never updated'**
  String get neverUpdated;

  /// No description provided for @createCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Card'**
  String get createCardTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cardIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Card ID *'**
  String get cardIdLabel;

  /// No description provided for @cardIdPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter card ID'**
  String get cardIdPlaceholder;

  /// No description provided for @cardPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get cardPrefixLabel;

  /// No description provided for @cardPrefixPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional prefix'**
  String get cardPrefixPlaceholder;

  /// No description provided for @cardSuffixLabel.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get cardSuffixLabel;

  /// No description provided for @cardSuffixPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional suffix'**
  String get cardSuffixPlaceholder;

  /// No description provided for @cardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get cardNameLabel;

  /// No description provided for @cardNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Card name'**
  String get cardNamePlaceholder;

  /// No description provided for @cardPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get cardPositionLabel;

  /// No description provided for @cardPositionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Display position'**
  String get cardPositionPlaceholder;

  /// No description provided for @createCardButton.
  ///
  /// In en, this message translates to:
  /// **'Create Card'**
  String get createCardButton;

  /// No description provided for @creatingCard.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creatingCard;

  /// No description provided for @idRequired.
  ///
  /// In en, this message translates to:
  /// **'ID is required'**
  String get idRequired;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errorUnknown;

  /// No description provided for @errorApi.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorApi;

  /// No description provided for @editCard.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get editCard;

  /// No description provided for @deleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get deleteCard;

  /// No description provided for @editCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get editCardTitle;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @savingCard.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingCard;

  /// No description provided for @deleteCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get deleteCardTitle;

  /// No description provided for @deleteCardMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{cardName}\"? This action cannot be undone.'**
  String deleteCardMessage(String cardName);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deletingCard.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deletingCard;

  /// No description provided for @newCard.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get newCard;

  /// No description provided for @noCards.
  ///
  /// In en, this message translates to:
  /// **'No cards'**
  String get noCards;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow device settings'**
  String get themeSystemDesc;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLightDesc;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDarkDesc;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @farePrice.
  ///
  /// In en, this message translates to:
  /// **'Fare price'**
  String get farePrice;

  /// No description provided for @farePriceDesc.
  ///
  /// In en, this message translates to:
  /// **'Used to calculate how many fares your balance covers'**
  String get farePriceDesc;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @exportDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Back up cards, stops and settings'**
  String get exportDataDesc;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @importDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get importDataDesc;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to export'**
  String get nothingToExport;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import error'**
  String get importError;

  /// No description provided for @importedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} item{count, plural, =1{} other{s}} imported'**
  String importedItems(int count);

  /// No description provided for @noNewItemsImported.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to import'**
  String get noNewItemsImported;

  /// No description provided for @couldNotUpdateBalance.
  ///
  /// In en, this message translates to:
  /// **'Could not update balance'**
  String get couldNotUpdateBalance;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get name;

  /// No description provided for @fares.
  ///
  /// In en, this message translates to:
  /// **'{count} fare{count, plural, =1{} other{s}}'**
  String fares(int count);

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAgo(String time);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated: {datetime}'**
  String updatedAt(String datetime);

  /// No description provided for @updateBalance.
  ///
  /// In en, this message translates to:
  /// **'Update balance'**
  String get updateBalance;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cardIdExists.
  ///
  /// In en, this message translates to:
  /// **'A card with this ID already exists'**
  String get cardIdExists;

  /// No description provided for @createCardError.
  ///
  /// In en, this message translates to:
  /// **'Error creating card'**
  String get createCardError;

  /// No description provided for @saveChangesError.
  ///
  /// In en, this message translates to:
  /// **'Error saving changes'**
  String get saveChangesError;

  /// No description provided for @farePriceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Fare price updated'**
  String get farePriceUpdated;

  /// No description provided for @balanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Balance updated'**
  String get balanceUpdated;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @networkErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get networkErrorMessage;

  /// No description provided for @serverErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Balance service is unavailable. Try again later.'**
  String get serverErrorMessage;

  /// No description provided for @cardNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No balance information found for this card.'**
  String get cardNotFoundMessage;

  /// No description provided for @rateLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'Service query limit reached. Wait a few minutes and try again.'**
  String get rateLimitMessage;

  /// No description provided for @invalidCardMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid card number. It must have exactly 13 digits.'**
  String get invalidCardMessage;

  /// No description provided for @staleBalanceNotice.
  ///
  /// In en, this message translates to:
  /// **'Last known balance'**
  String get staleBalanceNotice;

  /// No description provided for @stops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stops;

  /// No description provided for @favoriteStops.
  ///
  /// In en, this message translates to:
  /// **'Favorite stops'**
  String get favoriteStops;

  /// No description provided for @addStop.
  ///
  /// In en, this message translates to:
  /// **'Add stop'**
  String get addStop;

  /// No description provided for @noFavoriteStops.
  ///
  /// In en, this message translates to:
  /// **'No saved stops'**
  String get noFavoriteStops;

  /// No description provided for @noFavoriteStopsMessage.
  ///
  /// In en, this message translates to:
  /// **'Save the stops you use and see the next buses here.'**
  String get noFavoriteStopsMessage;

  /// No description provided for @nearbyStops.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearbyStops;

  /// No description provided for @stationCatalog.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stationCatalog;

  /// No description provided for @searchStation.
  ///
  /// In en, this message translates to:
  /// **'Search station'**
  String get searchStation;

  /// No description provided for @noStopsNearby.
  ///
  /// In en, this message translates to:
  /// **'No stops within 300 m'**
  String get noStopsNearby;

  /// No description provided for @noBusesComing.
  ///
  /// In en, this message translates to:
  /// **'No buses coming'**
  String get noBusesComing;

  /// No description provided for @arrivingNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get arrivingNow;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @metersAway.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String metersAway(int meters);

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to find nearby stops.'**
  String get locationUnavailable;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Enable the location permission in system settings.'**
  String get locationDeniedForever;

  /// No description provided for @couldNotLoadArrivals.
  ///
  /// In en, this message translates to:
  /// **'Could not load arrivals'**
  String get couldNotLoadArrivals;

  /// No description provided for @stopSaved.
  ///
  /// In en, this message translates to:
  /// **'Stop saved'**
  String get stopSaved;

  /// No description provided for @stopAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'That stop is already saved'**
  String get stopAlreadySaved;

  /// No description provided for @removeStop.
  ///
  /// In en, this message translates to:
  /// **'Remove stop'**
  String get removeStop;

  /// No description provided for @mapTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// No description provided for @searchHere.
  ///
  /// In en, this message translates to:
  /// **'Search here'**
  String get searchHere;

  /// No description provided for @linesServing.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get linesServing;

  /// No description provided for @noLinesForStop.
  ///
  /// In en, this message translates to:
  /// **'No lines listed'**
  String get noLinesForStop;

  /// No description provided for @saveAsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Save as favorite'**
  String get saveAsFavorite;

  /// No description provided for @saveThisArea.
  ///
  /// In en, this message translates to:
  /// **'Save this area'**
  String get saveThisArea;

  /// No description provided for @areaName.
  ///
  /// In en, this message translates to:
  /// **'Area name'**
  String get areaName;

  /// No description provided for @mapHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map and search to see stops anywhere'**
  String get mapHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @homeScreen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get homeScreen;

  /// No description provided for @homeScreenDesc.
  ///
  /// In en, this message translates to:
  /// **'What to show when the app opens'**
  String get homeScreenDesc;

  /// No description provided for @homeCardsOnly.
  ///
  /// In en, this message translates to:
  /// **'Cards only'**
  String get homeCardsOnly;

  /// No description provided for @homeStopsOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorite stops only'**
  String get homeStopsOnly;

  /// No description provided for @homeBoth.
  ///
  /// In en, this message translates to:
  /// **'Cards and stops'**
  String get homeBoth;

  /// No description provided for @myCards.
  ///
  /// In en, this message translates to:
  /// **'My cards'**
  String get myCards;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @editStop.
  ///
  /// In en, this message translates to:
  /// **'Edit stop'**
  String get editStop;

  /// No description provided for @customNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom name'**
  String get customNameLabel;

  /// No description provided for @customNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty to use the real name'**
  String get customNameHint;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @stopDetails.
  ///
  /// In en, this message translates to:
  /// **'Stop details'**
  String get stopDetails;

  /// No description provided for @resetNorth.
  ///
  /// In en, this message translates to:
  /// **'Face north'**
  String get resetNorth;

  /// No description provided for @madeBy.
  ///
  /// In en, this message translates to:
  /// **'by Yenreh'**
  String get madeBy;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get licenses;

  /// No description provided for @stopNotReported.
  ///
  /// In en, this message translates to:
  /// **'This stop is no longer reported'**
  String get stopNotReported;

  /// No description provided for @relinkStop.
  ///
  /// In en, this message translates to:
  /// **'Link to another stop'**
  String get relinkStop;

  /// No description provided for @cache.
  ///
  /// In en, this message translates to:
  /// **'Cached data'**
  String get cache;

  /// No description provided for @cacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Stations, lines and stop positions'**
  String get cacheDesc;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cached data cleared'**
  String get cacheCleared;

  /// No description provided for @arrivalsUnknown.
  ///
  /// In en, this message translates to:
  /// **'No arrivals yet'**
  String get arrivalsUnknown;

  /// No description provided for @sortByProximity.
  ///
  /// In en, this message translates to:
  /// **'Closest stops first'**
  String get sortByProximity;

  /// No description provided for @sortByProximityDesc.
  ///
  /// In en, this message translates to:
  /// **'Uses the location when it is already available. Off, stops keep your own order: hold one and drag it to change it'**
  String get sortByProximityDesc;

  /// No description provided for @showOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show on home'**
  String get showOnHome;

  /// No description provided for @hideFromHome.
  ///
  /// In en, this message translates to:
  /// **'Hide from home'**
  String get hideFromHome;

  /// No description provided for @hiddenFromHome.
  ///
  /// In en, this message translates to:
  /// **'Not on home'**
  String get hiddenFromHome;

  /// No description provided for @darkMap.
  ///
  /// In en, this message translates to:
  /// **'Dark map'**
  String get darkMap;

  /// No description provided for @darkMapDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark tiles on the stops map, whatever the app theme'**
  String get darkMapDesc;

  /// No description provided for @findStops.
  ///
  /// In en, this message translates to:
  /// **'Find stops'**
  String get findStops;

  /// No description provided for @favoritesShort.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesShort;

  /// No description provided for @mapCredits.
  ///
  /// In en, this message translates to:
  /// **'Map credits'**
  String get mapCredits;

  /// No description provided for @updateArrivals.
  ///
  /// In en, this message translates to:
  /// **'Update arrivals'**
  String get updateArrivals;

  /// No description provided for @linesToShow.
  ///
  /// In en, this message translates to:
  /// **'Lines to show'**
  String get linesToShow;

  /// No description provided for @linesToShowHint.
  ///
  /// In en, this message translates to:
  /// **'With none chosen, every line shows'**
  String get linesToShowHint;

  /// No description provided for @noBusesOfLines.
  ///
  /// In en, this message translates to:
  /// **'None of these lines is coming'**
  String get noBusesOfLines;

  /// No description provided for @linesTab.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get linesTab;

  /// No description provided for @searchLine.
  ///
  /// In en, this message translates to:
  /// **'Search line'**
  String get searchLine;

  /// No description provided for @lineRunningNow.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get lineRunningNow;

  /// No description provided for @lineNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running now'**
  String get lineNotRunning;

  /// No description provided for @lineRuns.
  ///
  /// In en, this message translates to:
  /// **'Runs {start}–{end}'**
  String lineRuns(String start, String end);

  /// No description provided for @busesThisWay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No buses this way} =1{1 bus this way} other{{count} buses this way}}'**
  String busesThisWay(int count);

  /// No description provided for @towards.
  ///
  /// In en, this message translates to:
  /// **'To {stop}'**
  String towards(String stop);

  /// No description provided for @noLineRoute.
  ///
  /// In en, this message translates to:
  /// **'No route for this line'**
  String get noLineRoute;

  /// No description provided for @updateBusPositions.
  ///
  /// In en, this message translates to:
  /// **'Update bus positions'**
  String get updateBusPositions;

  /// No description provided for @unofficialNotice.
  ///
  /// In en, this message translates to:
  /// **'Unofficial app, not affiliated with Metro Cali. Arrivals, balances and routes come from its public services and may not be accurate.'**
  String get unofficialNotice;

  /// No description provided for @dataFrom.
  ///
  /// In en, this message translates to:
  /// **'Data: {source}'**
  String dataFrom(String source);

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version ({version})'**
  String upToDate(String version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download {version}'**
  String downloadUpdate(String version);

  /// No description provided for @updateInstallHint.
  ///
  /// In en, this message translates to:
  /// **'Open the downloaded file to install it over this version; your data stays.'**
  String get updateInstallHint;

  /// No description provided for @noReleasesYet.
  ///
  /// In en, this message translates to:
  /// **'No releases published yet'**
  String get noReleasesYet;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get updateCheckFailed;

  /// No description provided for @refreshBalancesOnOpen.
  ///
  /// In en, this message translates to:
  /// **'Refresh balances on opening'**
  String get refreshBalancesOnOpen;

  /// No description provided for @refreshBalancesOnOpenDesc.
  ///
  /// In en, this message translates to:
  /// **'Asks for every card\'s balance each time the app opens'**
  String get refreshBalancesOnOpenDesc;

  /// No description provided for @cardsShort.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cardsShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
