import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _craneEntrance;
  late Animation<double> _symbolDrop;
  late Animation<double> _symbolSwing;
  late Animation<Offset> _symbolFlight;
  late Animation<double> _symbolOpacity;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 4000), // Süre 4 saniyeye çıkarıldı
      vsync: this,
    );

    // 1. Vinç girişi (%0 - %15)
    _craneEntrance = Tween<double>(begin: -300, end: 0).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOutCubic),
    ));

    // 2. Sembolün inişi (%15 - %30)
    _symbolDrop = Tween<double>(begin: -400, end: 0).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.30, curve: Curves.elasticOut),
    ));
    
    // 3. Fırlatma öncesi sallanma (%30 - %60)
    // 2-3 kez hızla sallanır
    _symbolSwing = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.30, 0.60, curve: Curves.easeInOut),
    ));

    // 4. Fırlatma (%60 - %90)
    _symbolFlight = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(400, -200), // Sağ üstteki binaya doğru
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.60, 0.90, curve: Curves.easeOutSine),
    ));

    _symbolOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
    ));

    _mainController.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF0D2B1D); 
    const Color lightGreen = Color(0xFF1A4D33);
    const Color buildingColor = Color(0xFF081C13);
    const Color symbolColor = Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: lightGreen,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: lightGreen,
        child: Stack(
          children: [
            // Arka Plan Binalar (Siluet)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 200),
                painter: BuildingPainter(color: buildingColor),
              ),
            ),

            // Ana Animasyon Alanı
            Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  // Sallanma hesaplama (Sinüs dalgası: 4 tam tur)
                  final double t = (_mainController.value - 0.30) / 0.30;
                  final double swing = _mainController.value >= 0.30 && _mainController.value <= 0.60
                      ? math.sin(t * 4 * math.pi) * 0.4
                      : 0.0;

                  // Fırlatma anında vince asılı değil, uçuyor
                  final bool isFlying = _mainController.value > 0.60;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vinç
                      Transform.translate(
                        offset: Offset(_craneEntrance.value - 100, 0),
                        child: CustomPaint(
                          size: const Size(300, 500),
                          painter: CranePainter(color: Colors.white70),
                        ),
                      ),
                      
                      // Sembol ($ / Ş sembolü olarak tasvir edildi)
                      if (!isFlying)
                        Positioned(
                          top: 150,
                          child: Transform.translate(
                            offset: Offset(_craneEntrance.value + 60 - 100, _symbolDrop.value),
                            child: Transform.rotate(
                              angle: swing,
                              alignment: Alignment.topCenter,
                              child: Column(
                                children: [
                                  Container(width: 2, height: 100, color: Colors.white30),
                                  const Text('\$', style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: symbolColor)),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Uçan Sembol
                      if (isFlying)
                        Positioned(
                          top: 150,
                          child: Transform.translate(
                            offset: Offset(_craneEntrance.value + 60 - 100 + _symbolFlight.value.dx, _symbolFlight.value.dy),
                            child: Opacity(
                              opacity: _symbolOpacity.value,
                              child: const Text('\$', style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: symbolColor)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Alt Yazı ve Yükleniyor Göstergesi
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: _mainController.value > 0.1 ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'ŞantiyePro',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 28,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          letterSpacing: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BuildingPainter extends CustomPainter {
  final Color color;
  BuildingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.7);
    path.lineTo(40, size.height * 0.7);
    path.lineTo(40, size.height * 0.4);
    path.lineTo(80, size.height * 0.4);
    path.lineTo(80, size.height * 0.8);
    path.lineTo(120, size.height * 0.8);
    path.lineTo(120, size.height * 0.2);
    path.lineTo(180, size.height * 0.2);
    path.lineTo(180, size.height * 0.6);
    path.lineTo(240, size.height * 0.6);
    path.lineTo(240, size.height * 0.3);
    path.lineTo(280, size.height * 0.3);
    path.lineTo(280, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Diğer tarafa da binalar
    final path2 = Path();
    path2.moveTo(size.width, size.height);
    path2.lineTo(size.width, size.height * 0.5);
    path2.lineTo(size.width - 60, size.height * 0.5);
    path2.lineTo(size.width - 60, size.height * 0.2);
    path2.lineTo(size.width - 120, size.height * 0.2);
    path2.lineTo(size.width - 120, size.height * 0.6);
    path2.lineTo(size.width - 200, size.height * 0.6);
    path2.lineTo(size.width - 200, size.height);
    path2.close();
    
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CranePainter extends CustomPainter {
  final Color color;
  CranePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;

    canvas.drawRect(Rect.fromLTWH(40, 0, 15, size.height), paint); // Kule
    canvas.drawRect(Rect.fromLTWH(0, 50, size.width * 0.8, 15), paint); // Kol
    canvas.drawRect(Rect.fromLTWH(55, 50, 20, 20), paint); // Kabin
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
