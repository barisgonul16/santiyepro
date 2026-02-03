import 'dart:io';
import 'package:flutter/material.dart';
import '../models/proje.dart';
import '../models/gunluk_kayit.dart';
import '../models/hatirlatici.dart';
import '../services/notification_service.dart';
import '../theme/theme_colors.dart';

class TakvimSayfaPage extends StatefulWidget {
  final List<Proje> projeler;
  final Map<String, List<GunlukKayit>> projeGunlukKayitlari;

  const TakvimSayfaPage({
    super.key,
    required this.projeler,
    required this.projeGunlukKayitlari,
  });

  @override
  State<TakvimSayfaPage> createState() => _TakvimSayfaPageState();
}

class _TakvimSayfaPageState extends State<TakvimSayfaPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  late Map<String, Color> _projectColors;

  @override
  void initState() {
    super.initState();
    _assignProjectColors();
  }

  @override
  void didUpdateWidget(covariant TakvimSayfaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assignProjectColors();
  }

  void _assignProjectColors() {
    _projectColors = {};
    final palette = [
      const Color(0xFF448AFF), // Blue
      const Color(0xFF69F0AE), // Green
      const Color(0xFFFF5252), // Red
      const Color(0xFFFFAB40), // Orange
      const Color(0xFFE040FB), // Purple
      const Color(0xFF40C4FF), // Light Blue
      const Color(0xFFFFD740), // Amber
      const Color(0xFFFF4081), // Pink
    ];
    
    int index = 0;
    final sortedProjects = List<Proje>.from(widget.projeler)..sort((a, b) => a.id.compareTo(b.id));
    for (var proje in sortedProjects) {
       _projectColors[proje.id] = palette[index % palette.length];
       index++;
    }
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = _focusedDay.year;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: ThemeColors.cardBackground(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: ThemeColors.icon(context)),
                          onPressed: () => setDialogState(() => tempYear--),
                        ),
                        Text(
                          "$tempYear",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ThemeColors.textPrimary(context)),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: ThemeColors.icon(context)),
                          onPressed: () => setDialogState(() => tempYear++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Month Grid
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(12, (index) {
                        final monthIndex = index + 1;
                        final isSelected = monthIndex == _focusedDay.month && tempYear == _focusedDay.year;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _focusedDay = DateTime(tempYear, monthIndex, 1);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 120) / 4, // 3 columns approx
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2962FF) : ThemeColors.divider(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _monthNameFull(monthIndex),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : ThemeColors.textSecondary(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12, 
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime? lastUpdate;
    for (var p in widget.projeler) {
       if (p.sonGuncelleme != null) {
         if (lastUpdate == null || p.sonGuncelleme!.isAfter(lastUpdate!)) {
           lastUpdate = p.sonGuncelleme;
         }
       }
    }

    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final dayOffset = firstDayOfMonth.weekday - 1; 

    final activeProjects = widget.projeler.where((p) => p.durum == 'Devam Ediyor').toList();

    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER (Fixed) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: LayoutBuilder( // Wrap header in LayoutBuilder
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showMonthYearPicker,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "${_monthNameFull(_focusedDay.month)}",
                                      style: TextStyle(
                                        fontSize: isMobile ? 20 : (Platform.isWindows ? 24 : 22), 
                                        fontWeight: FontWeight.bold, 
                                        color: ThemeColors.textPrimary(context),
                                        letterSpacing: 0.5
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(Icons.arrow_drop_down, color: ThemeColors.textSecondary(context)),
                                  ],
                                ),
                                Text(
                                  "${_focusedDay.year}",
                                  style: TextStyle(
                                    fontSize: Platform.isWindows ? 16 : 14,
                                    fontWeight: FontWeight.w300, 
                                    color: ThemeColors.textSecondary(context)
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile) ...[ // Hide "Bugün" button on very small screens or make it icon only
                            const SizedBox(width: 15),
                            InkWell(
                              onTap: () {
                                setState(() {
                                   _focusedDay = DateTime.now();
                                   _selectedDay = DateTime.now();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                                ),
                                child: const Text(
                                  "Bugün",
                                  style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          ] else ...[
                             const SizedBox(width: 10),
                             IconButton(
                               onPressed: () {
                                 setState(() {
                                   _focusedDay = DateTime.now();
                                   _selectedDay = DateTime.now();
                                 });
                               }, 
                               icon: Icon(Icons.today, color: Colors.blueAccent),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             )
                          ]
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                               color: ThemeColors.cardBackground(context),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: ThemeColors.border(context))
                             ),
                             child: Row(
                               children: [
                                 Icon(Icons.access_time, size: 12, color: Colors.greenAccent.withOpacity(0.8)),
                                 const SizedBox(width: 4),
                                 Text(
                                    lastUpdate != null 
                                     ? "${lastUpdate.hour.toString().padLeft(2,'0')}:${lastUpdate.minute.toString().padLeft(2,'0')}"
                                     : "--:--",
                                    style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 12),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 2),
                           Text(
                             "Son Güncelleme",
                             style: TextStyle(fontSize: 8, color: ThemeColors.textTertiary(context)),
                           )
                        ],
                      )
                    ],
                  );
                }
              ),
            ),
            
            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeColors.background(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: CustomScrollView(
                  slivers: [
                    // Month Nav & Days Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 5, 10, 0), // Reduced top padding
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left, color: ThemeColors.textSecondary(context), size: 24), // Smaller icon
                                  onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
                                ),
                                // Week Days
                                Expanded(
                                  child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceAround,
                                     children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'].map((d) => Text(
                                       d, 
                                       style: TextStyle(
                                         color: (d == 'Ct' || d == 'Pz') ? const Color(0xFFFF5252) : ThemeColors.textSecondary(context),
                                         fontWeight: FontWeight.bold,
                                         fontSize: Platform.isWindows ? 13 : 11
                                       )
                                     )).toList(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.chevron_right, color: ThemeColors.textSecondary(context), size: 24), // Smaller icon
                                  onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5), // Reduced gap
                          ],
                        ),
                      ),
                    ),

                    // Calendar Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: Platform.isWindows ? 2.0 : 0.85, 
                          mainAxisSpacing: Platform.isWindows ? 2 : 3, 
                          crossAxisSpacing: Platform.isWindows ? 2 : 3, 
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < dayOffset) return const SizedBox.shrink();
                            final day = index - dayOffset + 1;
                            final date = DateTime(_focusedDay.year, _focusedDay.month, day);
                            return _buildDayCell(date, activeProjects);
                          },
                          childCount: daysInMonth + dayOffset,
                        ),
                      ),
                    ),

                    // Divider & Details Header
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 15),
                          const Divider(color: Colors.white12, thickness: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  "${_selectedDay.day} ${_monthNameFull(_selectedDay.month)}",
                                  style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const Spacer(),
                                Text("Günlük Durum", style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details List
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      sliver: _buildDetailsSliverList(activeProjects),
                    ),
                    
                    // Extra padding at bottom
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, List<Proje> activeProjects) {
    bool isSelected = DateUtils.isSameDay(date, _selectedDay);
    bool isToday = DateUtils.isSameDay(date, DateTime.now());
    bool isFuture = date.isAfter(DateTime.now()) && !isToday;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF2962FF) 
              : (isToday ? ThemeColors.cardBackground(context) : Colors.transparent),
          borderRadius: BorderRadius.circular(10), 
          border: isToday && !isSelected ? Border.all(color: ThemeColors.border(context)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${date.day}",
              style: TextStyle(
                color: isSelected ? Colors.white : (isToday ? Colors.blueAccent : ThemeColors.textPrimary(context)),
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w400,
                fontSize: Platform.isWindows ? 18 : 18, 
              ),
            ),
            // Project Indicators
            if (activeProjects.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: activeProjects.map((proje) {
                   final color = _projectColors[proje.id] ?? Colors.grey;
                   final logs = widget.projeGunlukKayitlari[proje.id] ?? [];
                   final hasLog = logs.any((k) => DateUtils.isSameDay(k.tarih, date));
                   
                   if (isFuture) return const SizedBox.shrink(); 
  
                   return Container(
                     width: 10, 
                     height: 10,
                     decoration: BoxDecoration(
                       color: hasLog ? color : null, 
                       shape: BoxShape.circle,
                       border: hasLog ? null : Border.all(color: Colors.white30, width: 1.5), 
                     ),
                   );
                }).toList(),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSliverList(List<Proje> activeProjects) {
    if (activeProjects.isEmpty) {
       return SliverToBoxAdapter(
         child: Center(child: Text("Aktif proje yok.", style: TextStyle(color: ThemeColors.textTertiary(context)))),
       );
    }
    
    final isFuture = _selectedDay.isAfter(DateTime.now()) && !DateUtils.isSameDay(_selectedDay, DateTime.now());
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final proje = activeProjects[index];
          final color = _projectColors[proje.id] ?? Colors.grey;
          final logs = widget.projeGunlukKayitlari[proje.id] ?? [];
          final hasLog = logs.any((k) => DateUtils.isSameDay(k.tarih, _selectedDay));

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ThemeColors.cardBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))
                    ]
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    proje.ad,
                    style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                if (isFuture)
                  Row(
                    children: const [
                      Text("Planlandı", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      SizedBox(width: 6),
                      Icon(Icons.event_outlined, color: Colors.white38, size: 18),
                    ],
                  )
                else if (hasLog)
                  Row(
                    children: [
                      Text("Rapor Tamam", style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 12)),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                    ],
                  )
                else
                  Row(
                    children: [
                      Text("Eksik", style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 12)),
                      const SizedBox(width: 6),
                      const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                    ],
                  )
              ],
            ),
          );
        },
        childCount: activeProjects.length,
      ),
    );
  }

  String _monthNameFull(int month) {
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month];
  }
}
