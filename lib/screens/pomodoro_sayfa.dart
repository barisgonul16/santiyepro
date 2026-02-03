import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme_colors.dart';

class PomodoroSayfaPage extends StatefulWidget {
  const PomodoroSayfaPage({super.key});

  @override
  State<PomodoroSayfaPage> createState() => _PomodoroSayfaPageState();
}

class _PomodoroSayfaPageState extends State<PomodoroSayfaPage> {
  int workTime = 25 * 60;
  int shortBreakTime = 5 * 60;
  int longBreakTime = 15 * 60;

  int _secondsRemaining = 25 * 60;
  Timer? _timer;
  bool _isRunning = false;
  String _mode = 'Çalışma'; 

  // ... implementation ...

  void _showSettingsDialog() {
    int tempWork = workTime ~/ 60;
    int tempShort = shortBreakTime ~/ 60;
    int tempLong = longBreakTime ~/ 60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Süre Ayarları (Dakika)', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingField('Çalışma', tempWork, (val) => tempWork = val),
            _buildSettingField('Kısa Mola', tempShort, (val) => tempShort = val),
            _buildSettingField('Uzun Mola', tempLong, (val) => tempLong = val),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                workTime = tempWork * 60;
                shortBreakTime = tempShort * 60;
                longBreakTime = tempLong * 60;
                _resetTimer();
              });
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingField(String label, int value, Function(int) onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
           Expanded(child: Text(label, style: TextStyle(color: Colors.white70))),
           SizedBox(
             width: 60,
             child: TextFormField(
               initialValue: value.toString(),
               keyboardType: TextInputType.number,
               style: TextStyle(color: Colors.white),
               onChanged: (val) => onChange(int.tryParse(val) ?? 1),
             ),
           ),
        ],
      ),
    );
  }

  // ... Update build method to include settings button ...
  @override
  Widget build(BuildContext context) {
    // ... existing variable definitions ...
    double progress = 1.0;
    int currentTotalTime = _mode == 'Çalışma' ? workTime : (_mode == 'Kısa Mola' ? shortBreakTime : longBreakTime);
    progress = currentTotalTime == 0 ? 0 : _secondsRemaining / currentTotalTime;

    Color timerColor;
    if (_mode == 'Çalışma') {
      timerColor = Colors.redAccent;
    } else if (_mode == 'Kısa Mola') {
      timerColor = Colors.greenAccent;
    } else {
      timerColor = Colors.blueAccent;
    }

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 400;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isMobile ? 'Pomodoro' : 'Pomodoro Zamanlayıcı',
                        style: TextStyle(
                            fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: Colors.white54),
                      onPressed: _showSettingsDialog,
                    )
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Mod Seçimi
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildModeButton('Çalışma', Colors.redAccent),
                _buildModeButton('Kısa Mola', Colors.greenAccent),
                _buildModeButton('Uzun Mola', Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 40),
            // Timer Dairesi
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200, // Slightly smaller to ensure fit
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    color: timerColor,
                    backgroundColor: Colors.white10,
                  ),
                ),
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Kontroller
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    _isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: ThemeColors.textPrimary(context),
                  ),
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                ),
                const SizedBox(width: 30),
                IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.refresh, color: Colors.white54),
                  onPressed: _resetTimer,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
  
  void _startTimer() {
    if (_timer != null) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _timer = null;
          _isRunning = false;
          _showTimeUpDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      if (_mode == 'Çalışma') {
        _secondsRemaining = workTime;
      } else if (_mode == 'Kısa Mola') {
        _secondsRemaining = shortBreakTime;
      } else {
        _secondsRemaining = longBreakTime;
      }
    });
  }

  void _setMode(String mode) {
    _pauseTimer();
    setState(() {
      _mode = mode;
      if (_mode == 'Çalışma') {
        _secondsRemaining = workTime;
      } else if (_mode == 'Kısa Mola') {
        _secondsRemaining = shortBreakTime;
      } else {
        _secondsRemaining = longBreakTime;
      }
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: const Text('Süre Doldu!', style: TextStyle(color: Colors.white)),
        content: Text('$_mode süresi tamamlandı.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildModeButton(String mode, Color color) {
    bool isSelected = _mode == mode;
    return OutlinedButton(
      onPressed: () => _setMode(mode),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isSelected ? color : Colors.white24,
          width: 2,
        ),
        backgroundColor: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: isSelected ? color : Colors.white54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
