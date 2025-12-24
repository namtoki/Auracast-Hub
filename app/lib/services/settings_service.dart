import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'api_service.dart';

/// Service for managing user settings locally and syncing with AWS.
class SettingsService {
  static const String _localFileName = 'user_settings.json';

  final ApiService _apiService;
  UserSettings? _currentSettings;
  bool _isInitialized = false;

  SettingsService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Current user settings.
  UserSettings? get currentSettings => _currentSettings;

  /// Whether settings are loaded.
  bool get isInitialized => _isInitialized;

  /// Initialize settings service for a user.
  Future<void> initialize(String userId) async {
    try {
      // Try to load from cloud first
      _currentSettings = await _apiService.getUserSettings(userId);

      if (_currentSettings != null) {
        // Cache locally
        await _saveLocal(_currentSettings!);
      } else {
        // Try to load from local cache
        _currentSettings = await _loadLocal(userId);

        if (_currentSettings == null) {
          // Create default settings
          _currentSettings = UserSettings(
            userId: userId,
            lastUpdated: DateTime.now(),
          );
          await saveSettings(_currentSettings!);
        }
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback to local storage
      _currentSettings = await _loadLocal(userId);

      if (_currentSettings == null) {
        _currentSettings = UserSettings(
          userId: userId,
          lastUpdated: DateTime.now(),
        );
      }

      _isInitialized = true;
      debugPrint('Settings loaded from local cache: $e');
    }
  }

  /// Save settings to both local and cloud storage.
  Future<void> saveSettings(UserSettings settings) async {
    final updatedSettings = settings.copyWith(
      lastUpdated: DateTime.now(),
    );

    _currentSettings = updatedSettings;

    // Save locally first (fast)
    await _saveLocal(updatedSettings);

    // Then sync to cloud (can fail)
    try {
      await _apiService.saveUserSettings(updatedSettings);
    } catch (e) {
      debugPrint('Failed to sync settings to cloud: $e');
    }
  }

  /// Update a specific setting.
  Future<void> updateSetting({
    String? preferredDeviceName,
    AudioChannel? defaultChannel,
    int? bufferSizeMs,
    bool? autoCalibrate,
    bool? showAdvancedOptions,
    DeviceProfile? deviceProfile,
  }) async {
    if (_currentSettings == null) {
      throw StateError('Settings not initialized');
    }

    final updated = _currentSettings!.copyWith(
      preferredDeviceName: preferredDeviceName,
      defaultChannel: defaultChannel,
      bufferSizeMs: bufferSizeMs,
      autoCalibrate: autoCalibrate,
      showAdvancedOptions: showAdvancedOptions,
      deviceProfile: deviceProfile,
    );

    await saveSettings(updated);
  }

  /// Update device profile with new measurements.
  Future<void> updateDeviceProfile(DeviceProfile profile) async {
    await updateSetting(deviceProfile: profile);
  }

  Future<File> _getLocalFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${userId}_$_localFileName');
  }

  Future<void> _saveLocal(UserSettings settings) async {
    try {
      final file = await _getLocalFile(settings.userId);
      final json = jsonEncode(settings.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Failed to save settings locally: $e');
    }
  }

  Future<UserSettings?> _loadLocal(String userId) async {
    try {
      final file = await _getLocalFile(userId);
      if (await file.exists()) {
        final json = await file.readAsString();
        return UserSettings.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Failed to load local settings: $e');
    }
    return null;
  }

  /// Clear all settings.
  Future<void> clear() async {
    if (_currentSettings == null) return;

    try {
      final file = await _getLocalFile(_currentSettings!.userId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    _currentSettings = null;
    _isInitialized = false;
  }
}
