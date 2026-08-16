import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class WeatherService {
  Future<void> checkWeatherAndNotify(String cityName) async {
    if (cityName.isEmpty) return;

    try {
      // 1. Check if a notification was already sent today to satisfy "günde 1 kere"
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10); // "YYYY-MM-DD"
      final lastNotificationDate = prefs.getString('last_weather_notification_date');
      
      if (lastNotificationDate == todayStr) {
        debugPrint("LOG: Weather notification already sent today ($todayStr). Skipping check.");
        return;
      }

      // 2. Geocode city name to lat/lon using Open-Meteo Geocoding API
      final geocodeUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}&count=1&language=tr&format=json'
      );
      final geocodeResponse = await http.get(geocodeUrl).timeout(const Duration(seconds: 10));
      
      double latitude = 40.1885; // Fallback Bursa latitude
      double longitude = 29.0610; // Fallback Bursa longitude
      String foundCityName = cityName;

      if (geocodeResponse.statusCode == 200) {
        final geocodeData = jsonDecode(geocodeResponse.body);
        if (geocodeData['results'] != null && (geocodeData['results'] as List).isNotEmpty) {
          final firstResult = geocodeData['results'][0];
          latitude = (firstResult['latitude'] as num).toDouble();
          longitude = (firstResult['longitude'] as num).toDouble();
          foundCityName = firstResult['name'] ?? cityName;
        }
      }

      // 3. Fetch 7-day forecast for the coordinates from Open-Meteo Forecast API
      final forecastUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&daily=precipitation_probability_max&timezone=auto&forecast_days=7'
      );
      final forecastResponse = await http.get(forecastUrl).timeout(const Duration(seconds: 10));

      if (forecastResponse.statusCode == 200) {
        final forecastData = jsonDecode(forecastResponse.body);
        final dailyData = forecastData['daily'];
        if (dailyData != null && dailyData['precipitation_probability_max'] != null) {
          final List<dynamic> probabilities = dailyData['precipitation_probability_max'];
          
          bool hasHighRainProbability = false;
          int maxProb = 0;
          
          for (var prob in probabilities) {
            if (prob != null) {
              final val = (prob as num).toInt();
              if (val > maxProb) {
                maxProb = val;
              }
              if (val >= 70) { // "%70 üzeri" (70 and above)
                hasHighRainProbability = true;
              }
            }
          }

          if (hasHighRainProbability) {
            // Trigger local notification
            await NotificationService().showInstantNotification(
              "Yağmur Uyarısı ($foundCityName)",
              "Önümüzdeki 7 gün içinde yağmur ihtimali %$maxProb seviyesine ulaşacaktır!"
            );
            
            // Save notification date so we only notify once per day
            await prefs.setString('last_weather_notification_date', todayStr);
          }
        }
      }
    } catch (e) {
      debugPrint("LOG: Weather check error: $e");
    }
  }
}
