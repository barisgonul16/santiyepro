
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/hatirlatici.dart';


import 'dart:io';
import 'app_log.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<List<Hatirlatici>> fetchCalendarReminders() async {
    List<Hatirlatici> calendarReminders = [];

    // Windows'ta çalışmaz, sadece mobil
    if (!Platform.isAndroid && !Platform.isIOS) {
      appLog("Calendar is not supported on this platform: ${Platform.operatingSystem}");
      return [];
    }

    try {
      // İzin kontrolü
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      appLog("Calendar hasPermissions: isSuccess=${permissionsGranted.isSuccess}, data=${permissionsGranted.data}");
      
      if (permissionsGranted.isSuccess && (permissionsGranted.data == null || !permissionsGranted.data!)) {
        appLog("Requesting calendar permissions...");
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        appLog("Permission request result: isSuccess=${permissionsGranted.isSuccess}, data=${permissionsGranted.data}");
        
        if (!permissionsGranted.isSuccess || permissionsGranted.data == null || !permissionsGranted.data!) {
          appLog("Calendar permission denied");
          return [];
        }
      }

      // Takvimleri al
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      appLog("Retrieved calendars: isSuccess=${calendarsResult.isSuccess}, count=${calendarsResult.data?.length ?? 0}");
      
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
        appLog("No calendars found");
        return [];
      }

      // Takvim isimlerini logla
      for (var cal in calendarsResult.data!) {
        appLog("  Calendar: ${cal.name} (id: ${cal.id}, accountName: ${cal.accountName})");
      }

      // Geniş tarih aralığı - bugünden 30 gün öncesi ve 60 gün sonrası
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final endDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 60));
      
      final startTZ = tz.TZDateTime.from(startDate, tz.local);
      final endTZ = tz.TZDateTime.from(endDate, tz.local);
      appLog("Fetching events from $startTZ to $endTZ (local timezone: ${tz.local.name})");

      for (var calendar in calendarsResult.data!) {
        appLog("Checking calendar: ${calendar.name} (id: ${calendar.id}, isReadOnly: ${calendar.isReadOnly})");
        
        try {
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: startTZ, endDate: endTZ),
          );

          appLog("  Calendar '${calendar.name}': isSuccess=${eventsResult.isSuccess}, count=${eventsResult.data?.length ?? 0}");
          
          if (!eventsResult.isSuccess) {
            appLog("  Calendar '${calendar.name}' error: ${eventsResult.errors}");
          }

          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (var event in eventsResult.data!) {
              appLog("    Event: ${event.title}, start: ${event.start}, allDay: ${event.allDay}");
              if (event.start != null) {
                calendarReminders.add(Hatirlatici(
                  id: 'cal_${event.eventId}',
                  baslik: event.title ?? 'Başlıksız',
                  aciklama: event.description ?? 'Takvimden aktarıldı',
                  tarih: DateTime(event.start!.year, event.start!.month, event.start!.day),
                  saat: TimeOfDay(hour: event.start!.hour, minute: event.start!.minute),
                  tamamlandi: false,
                ));
              }
            }
          }
        } catch (calError) {
          appLog("  Calendar '${calendar.name}' exception: $calError");
        }
      }
      
      appLog("Total calendar reminders fetched: ${calendarReminders.length}");
    } catch (e, stackTrace) {
      appLog("Calendar fetch error: $e");
      appLog("Stack trace: $stackTrace");
    }

    return calendarReminders;
  }
}
