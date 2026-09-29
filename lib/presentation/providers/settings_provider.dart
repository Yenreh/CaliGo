import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

/// Theme mode options
enum AppThemeMode {
  system,
  light,
  dark,
}

/// What the home screen shows
enum HomeContent {
  cards,
  stops,
  both,
}

/// Settings state
class SettingsState {
  final AppThemeMode themeMode;
  final int farePrice;
  final HomeContent homeContent;

  /// Put the favorite stops closest to the device first; off keeps the
  /// order they were saved in
  final bool sortStopsByProximity;

  /// Ask for every balance when the app opens
  final bool refreshBalancesOnOpen;

  /// Dark map tiles, chosen apart from the app theme: dark tiles are
  /// harder to read, so the map stays light unless asked
  final bool darkMap;

  /// Map tiles at the screen's full resolution; off saves mobile data
  final bool sharpMap;
  final bool isLoading;

  static const int defaultFarePrice = 3500;

  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.farePrice = defaultFarePrice,
    this.homeContent = HomeContent.cards,
    this.sortStopsByProximity = true,
    this.darkMap = false,
    this.sharpMap = true,
    this.refreshBalancesOnOpen = true,
    this.isLoading = true,
  });

  SettingsState copyWith({
    AppThemeMode? themeMode,
    int? farePrice,
    HomeContent? homeContent,
    bool? sortStopsByProximity,
    bool? darkMap,
    bool? sharpMap,
    bool? refreshBalancesOnOpen,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      farePrice: farePrice ?? this.farePrice,
      homeContent: homeContent ?? this.homeContent,
      sortStopsByProximity: sortStopsByProximity ?? this.sortStopsByProximity,
      darkMap: darkMap ?? this.darkMap,
      sharpMap: sharpMap ?? this.sharpMap,
      refreshBalancesOnOpen:
          refreshBalancesOnOpen ?? this.refreshBalancesOnOpen,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get showsCards => homeContent != HomeContent.stops;
  bool get showsStops => homeContent != HomeContent.cards;

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'farePrice': farePrice,
        'homeContent': homeContent.index,
        'sortStopsByProximity': sortStopsByProximity,
        'darkMap': darkMap,
        'sharpMap': sharpMap,
        'refreshBalancesOnOpen': refreshBalancesOnOpen,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    return SettingsState(
      themeMode: AppThemeMode.values[json['themeMode'] as int? ?? 0],
      farePrice: json['farePrice'] as int? ?? defaultFarePrice,
      homeContent:
          HomeContent.values[json['homeContent'] as int? ?? 0],
      sortStopsByProximity: json['sortStopsByProximity'] as bool? ?? true,
      darkMap: json['darkMap'] as bool? ?? false,
      sharpMap: json['sharpMap'] as bool? ?? true,
      refreshBalancesOnOpen: json['refreshBalancesOnOpen'] as bool? ?? true,
      isLoading: false,
    );
  }
}

/// Settings notifier
class SettingsNotifier extends Notifier<SettingsState> {
  static const _fileName = 'settings.json';

  @override
  SettingsState build() {
    Future.microtask(() => _loadSettings());
    return const SettingsState();
  }

  Future<File> get _settingsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        state = SettingsState.fromJson(json);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _settingsFile;
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (e) {
      // Silent fail
    }
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setFarePrice(int price) {
    if (price > 0) {
      state = state.copyWith(farePrice: price);
      _saveSettings();
    }
  }

  /// Apply the settings found in a backup
  Future<void> importSettings(Map<String, dynamic> json) async {
    state = SettingsState.fromJson(json);
    await _saveSettings();
  }

  void setHomeContent(HomeContent content) {
    state = state.copyWith(homeContent: content);
    _saveSettings();
  }

  void setRefreshBalancesOnOpen(bool enabled) {
    state = state.copyWith(refreshBalancesOnOpen: enabled);
    _saveSettings();
  }

  void setDarkMap(bool enabled) {
    state = state.copyWith(darkMap: enabled);
    _saveSettings();
  }

  void setSharpMap(bool enabled) {
    state = state.copyWith(sharpMap: enabled);
    _saveSettings();
  }

  void setSortStopsByProximity(bool enabled) {
    state = state.copyWith(sortStopsByProximity: enabled);
    _saveSettings();
  }

  /// Calculate how many fares the balance can cover
  int calculateFares(double? balance) {
    if (balance == null || balance <= 0) return 0;
    return (balance / state.farePrice).floor();
  }
}

/// Settings provider
final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
