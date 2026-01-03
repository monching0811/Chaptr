import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingBackground { white, sepia, black }

enum AiTone { creative, formal, dramatic }

enum AiHelpLevel { full, grammar }

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 1.0;
  ReadingBackground _readingBackground = ReadingBackground.white;
  bool _autoSaveDrafts = true;

  // Granular push notification settings
  bool _pushNewChapterReminders = true;
  bool _pushStoryLikes = true;
  bool _pushComments = true;

  String _language = 'en';
  AiTone _aiTone = AiTone.creative;
  AiHelpLevel _aiHelpLevel = AiHelpLevel.full;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  ReadingBackground get readingBackground => _readingBackground;
  bool get autoSaveDrafts => _autoSaveDrafts;

  // Push getters
  bool get pushNewChapterReminders => _pushNewChapterReminders;
  bool get pushStoryLikes => _pushStoryLikes;
  bool get pushComments => _pushComments;

  String get language => _language;
  AiTone get aiTone => _aiTone;
  AiHelpLevel get aiHelpLevel => _aiHelpLevel;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    _fontSize = prefs.getDouble('fontSize') ?? 1.0;
    _readingBackground =
        ReadingBackground.values[prefs.getInt('readingBackground') ?? 0];
    _autoSaveDrafts = prefs.getBool('autoSaveDrafts') ?? true;

    // Load granular push settings
    _pushNewChapterReminders = prefs.getBool('pushNewChapterReminders') ?? true;
    _pushStoryLikes = prefs.getBool('pushStoryLikes') ?? true;
    _pushComments = prefs.getBool('pushComments') ?? true;

    _language = prefs.getString('language') ?? 'en';
    _aiTone = AiTone.values[prefs.getInt('aiTone') ?? 0];
    _aiHelpLevel = AiHelpLevel.values[prefs.getInt('aiHelpLevel') ?? 0];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    notifyListeners();
  }

  Future<void> setReadingBackground(ReadingBackground background) async {
    _readingBackground = background;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readingBackground', background.index);
    notifyListeners();
  }

  Future<void> setAutoSaveDrafts(bool value) async {
    _autoSaveDrafts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSaveDrafts', value);
    notifyListeners();
  }

  // Push setters
  Future<void> setPushNewChapterReminders(bool value) async {
    _pushNewChapterReminders = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushNewChapterReminders', value);
    notifyListeners();
  }

  Future<void> setPushStoryLikes(bool value) async {
    _pushStoryLikes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushStoryLikes', value);
    notifyListeners();
  }

  Future<void> setPushComments(bool value) async {
    _pushComments = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushComments', value);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    notifyListeners();
  }

  Future<void> setAiTone(AiTone tone) async {
    _aiTone = tone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aiTone', tone.index);
    notifyListeners();
  }

  Future<void> setAiHelpLevel(AiHelpLevel level) async {
    _aiHelpLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aiHelpLevel', level.index);
    notifyListeners();
  }
}
