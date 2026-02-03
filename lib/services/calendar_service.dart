
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/hatirlatici.dart';


import 'dart:io';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<List<Hatirlatici>> fetchCalendarReminders() async {
    List<Hatirlatici> calendarReminders = [];

    // Windows'ta çalışmaz, sadece mobil
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint("Calendar is not supported on this platform: ${Platform.operatingSystem}");
      return [];
    }

    try {
      // İzin kontrolü
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      debugPrint("Calendar hasPermissions: isSuccess=${permissionsGranted.isSuccess}, data=${permissionsGranted.data}");
      
      if (permissionsGranted.isSuccess && (permissionsGranted.data == null || !permissionsGranted.data!)) {
        debugPrint("Requesting calendar permissions...");
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        debugPrint("Permission request result: isSuccess=${permissionsGranted.isSuccess}, data=${permissionsGranted.data}");
        
        if (!permissionsGranted.isSuccess || permissionsGranted.data == null || !permissionsGranted.data!) {
          debugPrint("Calendar permission denied");
          return [];
        }
      }

      // Takvimleri al
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      debugPrint("Retrieved calendars: isSuccess=${calendarsResult.isSuccess}, count=${calendarsResult.data?.length ?? 0}");
      
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
        debugPrint("No calendars found");
        return [];
      }

      // Takvim isimlerini logla
      for (var cal in calendarsResult.data!) {
        debugPrint("  Calendar: ${cal.name} (id: ${cal.id}, accountName: ${cal.accountName})");
      }

      // Geniş tarih aralığı - bugünden 30 gün öncesi ve 60 gün sonrası
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final endDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 60));
      
      final startTZ = tz.TZDateTime.from(startDate, tz.local);
      final endTZ = tz.TZDateTime.from(endDate, tz.local);
      debugPrint("Fetching events from $startTZ to $endTZ (local timezone: ${tz.local.name})");

      for (var calendar in calendarsResult.data!) {
        debugPrint("Checking calendar: ${calendar.name} (id: ${calendar.id}, isReadOnly: ${calendar.isReadOnly})");
        
        try {
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: startTZ, endDate: endTZ),
          );

          debugPrint("  Calendar '${calendar.name}': isSuccess=${eventsResult.isSuccess}, count=${eventsResult.data?.length ?? 0}");
          
          if (!eventsResult.isSuccess) {
            debugPrint("  Calendar '${calendar.name}' error: ${eventsResult.errors}");
          }

          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (var event in eventsResult.data!) {
              debugPrint("    Event: ${event.title}, start: ${event.start}, allDay: ${event.allDay}");
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
          debugPrint("  Calendar '${calendar.name}' exception: $calError");
        }
      }
      
      debugPrint("Total calendar reminders fetched: ${calendarReminders.length}");
    } catch (e, stackTrace) {
      debugPrint("Calendar fetch error: $e");
      debugPrint("Stack trace: $stackTrace");
    }

    return calendarReminders;
  }
}
