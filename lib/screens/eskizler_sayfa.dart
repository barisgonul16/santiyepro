import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../theme/theme_colors.dart';

class EskizlerSayfaPage extends StatefulWidget {
  const EskizlerSayfaPage({super.key});

  @override
  State<EskizlerSayfaPage> createState() => _EskizlerSayfaPageState();
}

enum DrawingMode { freehand, line, rectangle, circle, eraser, select }

abstract class DrawingObject {
  void draw(Canvas canvas, Paint paint);
  bool isHit(Offset point);
  void move(Offset delta);
  List<Offset> getSnapPoints();
  
  Map<String, dynamic> toJson();
  
  static DrawingObject fromJson(Map<String, dynamic> json) {
    String type = json['type'];
    if (type == 'freehand') return FreehandObject.fromJson(json);
    if (type == 'line') return LineObject.fromJson(json);
    if (type == 'rect') return RectObject.fromJson(json);
    if (type == 'circle') return CircleObject.fromJson(json);
    throw Exception('Unknown type: $type');
  }
}

class FreehandObject extends DrawingObject {
  final List<Offset> points;
  final Paint paintStyle;

  FreehandObject(this.points, this.paintStyle);

  @override
  void draw(Canvas canvas, Paint paint) {
    if (points.isEmpty) return;
    for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], paintStyle);
    }
     if (points.length == 1) {
       canvas.drawPoints(ui.PointMode.points, [points[0]], paintStyle);
     }
  }

  @override
  bool isHit(Offset point) {
    for (final p in points) {
      if ((p - point).distance < 10.0) return true;
    }
    return false;
  }

  @override
  void move(Offset delta) {
    for (int i = 0; i < points.length; i++) {
      points[i] += delta;
    }
  }

  @override
  List<Offset> getSnapPoints() {
    if (points.isEmpty) return [];
    return [points.first, points.last];
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'freehand',
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'color': paintStyle.color.value,
    'strokeWidth': paintStyle.strokeWidth,
  };

  factory FreehandObject.fromJson(Map<String, dynamic> json) {
    List<Offset> points = (json['points'] as List)
        .map((p) => Offset(p['dx'], p['dy']))
        .toList();
    Paint paint = Paint()
      ..color = Color(json['color'])
      ..strokeWidth = json['strokeWidth']
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    return FreehandObject(points, paint);
  }
}

class LineObject extends DrawingObject {
  Offset start;
  Offset end;
  final Paint paintStyle;

  LineObject(this.start, this.end, this.paintStyle);

  @override
  void draw(Canvas canvas, Paint paint) {
    canvas.drawLine(start, end, paintStyle);
  }

  @override
  bool isHit(Offset point) {
    // Distance from point to line segment
    final p1 = start;
    final p2 = end;
    
    final double nom = ((p2.dy - p1.dy) * point.dx - (p2.dx - p1.dx) * point.dy + p2.dx * p1.dy - p2.dy * p1.dx).abs();
    final double den = math.sqrt(math.pow(p2.dy - p1.dy, 2) + math.pow(p2.dx - p1.dx, 2));
    final double dist = nom / den;
    
    // Check if point is within segments bounds (approx)
    if (dist > 10.0) return false;
    
    final minX = math.min(p1.dx, p2.dx) - 10;
    final maxX = math.max(p1.dx, p2.dx) + 10;
    final minY = math.min(p1.dy, p2.dy) - 10;
    final maxY = math.max(p1.dy, p2.dy) + 10;
    
    return point.dx >= minX && point.dx <= maxX && point.dy >= minY && point.dy <= maxY;
  }

  @override
  void move(Offset delta) {
    start += delta;
    end += delta;
  }

  @override
  List<Offset> getSnapPoints() {
    return [start, end, (start + end) / 2];
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'line',
    'start': {'dx': start.dx, 'dy': start.dy},
    'end': {'dx': end.dx, 'dy': end.dy},
    'color': paintStyle.color.value,
    'strokeWidth': paintStyle.strokeWidth,
  };

  factory LineObject.fromJson(Map<String, dynamic> json) {
    Paint paint = Paint()
      ..color = Color(json['color'])
      ..strokeWidth = json['strokeWidth']
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    return LineObject(
      Offset(json['start']['dx'], json['start']['dy']),
      Offset(json['end']['dx'], json['end']['dy']),
      paint,
    );
  }
}

class RectObject extends DrawingObject {
  Rect rect;
  final Paint paintStyle;

  RectObject(this.rect, this.paintStyle);

  @override
  void draw(Canvas canvas, Paint paint) {
    canvas.drawRect(rect, paintStyle);
  }

  @override
  bool isHit(Offset point) {
    // Check borders or inside? Let's stick to inside/borders simply with hit test
    return rect.inflate(10).contains(point);
  }

  @override
  void move(Offset delta) {
    rect = rect.shift(delta);
  }

  @override
  List<Offset> getSnapPoints() {
    return [
      rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight,
      rect.center,
      rect.centerLeft, rect.centerRight, rect.topCenter, rect.bottomCenter
    ];
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'rect',
    'left': rect.left,
    'top': rect.top,
    'width': rect.width,
    'height': rect.height,
    'color': paintStyle.color.value,
    'strokeWidth': paintStyle.strokeWidth,
  };

  factory RectObject.fromJson(Map<String, dynamic> json) {
    Paint paint = Paint()
      ..color = Color(json['color'])
      ..strokeWidth = json['strokeWidth']
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    return RectObject(
      Rect.fromLTWH(json['left'], json['top'], json['width'], json['height']),
      paint,
    );
  }
}

class CircleObject extends DrawingObject {
  Offset center;
  final double radius;
  final Paint paintStyle;

  CircleObject(this.center, this.radius, this.paintStyle);

  @override
  void draw(Canvas canvas, Paint paint) {
    canvas.drawCircle(center, radius, paintStyle);
  }

  @override
  bool isHit(Offset point) {
    final dist = (point - center).distance;
    return (dist - radius).abs() < 10.0; // Close to circumference
  }

  @override
  void move(Offset delta) {
    center += delta;
  }

  @override
  List<Offset> getSnapPoints() {
    return [
      center,
      center + Offset(radius, 0),
      center + Offset(-radius, 0),
      center + Offset(0, radius),
      center + Offset(0, -radius),
    ];
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'circle',
    'center': {'dx': center.dx, 'dy': center.dy},
    'radius': radius,
    'color': paintStyle.color.value,
    'strokeWidth': paintStyle.strokeWidth,
  };

  factory CircleObject.fromJson(Map<String, dynamic> json) {
    Paint paint = Paint()
      ..color = Color(json['color'])
      ..strokeWidth = json['strokeWidth']
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    return CircleObject(
      Offset(json['center']['dx'], json['center']['dy']),
      json['radius'],
      paint,
    );
  }
}


class _EskizlerSayfaPageState extends State<EskizlerSayfaPage> {
  final StorageService _storageService = StorageService();
  List<DrawingObject> objects = [];
  Color selectedColor = Colors.white;
  double strokeWidth = 2.0;
  DrawingMode currentMode = DrawingMode.freehand;

  // Temporary drawing state
  Offset? startPoint;
  List<Offset> currentFreehandPoints = [];
  Offset? currentEndPoint;
  
  // Selection & Move
  DrawingObject? selectedObject;
  Offset? lastPanPosition; // To calculate delta for move
  
  // Undo/Redo
  List<List<DrawingObject>> history = [];

  // Mouse/Cursor
  Offset mousePosition = Offset.zero;
  bool isHovering = false;

  // Saved Sketches
  Map<String, List<dynamic>> savedSketches = {};

  // Visual feedback for snapping
  Offset? currentSnapHighlight;

  @override
  void initState() {
    super.initState();
    _loadSketches();
  }

  Future<void> _loadSketches() async {
    final sketches = await _storageService.loadSketches();
    setState(() {
      savedSketches = sketches;
    });
  }

  void _saveToHistory() {
    // Deep copy objects list? 
    // Since objects are mutable (we added move), we need to clone them to preserve history state.
    // Our json storage serializes them, so we can use that for deep copy or implement clone.
    // Using JSON for deep copy is easiest for now without boilerplate clone methods.
    final deepCopy = objects.map((e) => DrawingObject.fromJson(e.toJson())).toList();
    history.add(deepCopy);
  }

  void _undo() {
    if (history.isNotEmpty) {
      setState(() {
        objects = history.removeLast();
        selectedObject = null; // Clear selection on undo
      });
    }
  }

  void _clear() {
    _saveToHistory();
    setState(() {
      objects.clear();
      selectedObject = null;
    });
  }
  
  // Line Drawing Snap
  Offset _applyLineSnapping(Offset start, Offset end) {
    if (currentMode != DrawingMode.line) return end;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx); 
    final angleDegrees = angle * 180 / math.pi;

    // Threshold for snapping
    const threshold = 5.0;

    // Horizontal (0 or 180/-180)
    if (angleDegrees.abs() < threshold || (180 - angleDegrees.abs()) < threshold) {
      return Offset(end.dx, start.dy);
    }

    // Vertical (90 or -90)
    if ((90 - angleDegrees.abs()).abs() < threshold) {
      return Offset(start.dx, end.dy);
    }
    
    return end;
  }

  // Object Snapping (Moving)
  Offset _snapObjectToOthers(DrawingObject movingObj, Offset delta) {
    // 1. Proposed move
    movingObj.move(delta); 
    // We move it first, check snap, then adjust.
    // If we adjust, we apply extra move.

    final movingPoints = movingObj.getSnapPoints();
    
    Offset bestCorrection = Offset.zero;
    double minDistance = 15.0; // Snap threshold
    Offset? snapPosition;

    for (var other in objects) {
      if (other == movingObj) continue;
      
      final otherPoints = other.getSnapPoints();
      
      for (var mp in movingPoints) {
        for (var op in otherPoints) {
          final dist = (mp - op).distance;
          if (dist < minDistance) {
            minDistance = dist;
            bestCorrection = op - mp; // Vector to snap mp to op
            snapPosition = op;
          }
        }
      }
    }
    
    if (bestCorrection != Offset.zero) {
      movingObj.move(bestCorrection);
      setState(() {
        currentSnapHighlight = snapPosition;
      });
      return delta + bestCorrection;
    } else {
      setState(() {
        currentSnapHighlight = null;
      });
      return delta;
    }
  }
  
  Future<void> _saveCurrentSketch() async {
    String? sketchName;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: Text('Çizimi Kaydet', style: TextStyle(color: ThemeColors.textPrimary(context))),
          content: TextField(
            controller: controller,
            style: TextStyle(color: ThemeColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Çizim Adı',
              hintStyle: TextStyle(color: ThemeColors.textTertiary(context)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                sketchName = controller.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (sketchName != null && sketchName!.isNotEmpty) {
      final jsonList = objects.map((e) => e.toJson()).toList();
      savedSketches[sketchName!] = jsonList;
      await _storageService.saveSketches(savedSketches);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$sketchName kaydedildi.')),
        );
      }
    }
  }

  Future<void> _showLoadSketchDialog() async {
    if (savedSketches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıtlı çizim bulunamadı.')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ThemeColors.cardBackground(context),
          title: Text('Çizim Yükle', style: TextStyle(color: ThemeColors.textPrimary(context))),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: savedSketches.keys.length,
              itemBuilder: (context, index) {
                final name = savedSketches.keys.elementAt(index);
                return ListTile(
                  title: Text(name, style: TextStyle(color: ThemeColors.textPrimary(context))),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      setState(() {
                        savedSketches.remove(name);
                      });
                      await _storageService.saveSketches(savedSketches);
                      Navigator.pop(context); 
                    },
                  ),
                  onTap: () {
                    final List<dynamic> jsonList = savedSketches[name]!;
                    setState(() {
                      _clear();
                      objects = jsonList.map((j) => DrawingObject.fromJson(j)).toList();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }
  
  Paint _getPaint(bool isEraser) {
    return Paint()
      ..color = isEraser ? Colors.black : selectedColor
      ..isAntiAlias = true
      ..strokeWidth = isEraser ? strokeWidth * 5 : strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          _buildToolbar(),
          const SizedBox(height: 5),
          Expanded(
            child: Stack(
              children: [
                // Canvas Area
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black, // Canvas background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeColors.border(context)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MouseRegion(
                      cursor: currentMode == DrawingMode.eraser ? SystemMouseCursors.none 
                             : currentMode == DrawingMode.select ? SystemMouseCursors.click 
                             : SystemMouseCursors.basic,
                      onHover: (event) {
                         setState(() {
                           mousePosition = event.localPosition;
                           isHovering = true;
                         });
                      },
                      onExit: (event) {
                        setState(() {
                          isHovering = false;
                        });
                      },
                      child: GestureDetector(
                        onPanStart: (details) {
                           _saveToHistory();
                           setState(() {
                             startPoint = details.localPosition;
                             currentEndPoint = details.localPosition; // Init
                             lastPanPosition = details.localPosition;
                             
                             if (currentMode == DrawingMode.select) {
                               // Find object hit (reverse search to verify top-most first)
                               selectedObject = null; // Deselect first
                               for (var i = objects.length - 1; i >= 0; i--) {
                                 if (objects[i].isHit(details.localPosition)) {
                                   selectedObject = objects[i];
                                   break;
                                 }
                               }
                             } else if (currentMode == DrawingMode.freehand || currentMode == DrawingMode.eraser) {
                               currentFreehandPoints = [details.localPosition];
                               selectedObject = null;
                             } else {
                               selectedObject = null;
                             }
                           });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            mousePosition = details.localPosition;
                            
                            if (currentMode == DrawingMode.select && selectedObject != null && lastPanPosition != null) {
                              final delta = details.localPosition - lastPanPosition!;
                              // Snap logic here
                              _snapObjectToOthers(selectedObject!, delta);
                              lastPanPosition = details.localPosition;
                            } else {
                              // Drawing logic
                              lastPanPosition = details.localPosition;
                               
                              // Snapping Logic apply only if Line mode
                              if (currentMode == DrawingMode.line && startPoint != null) {
                                currentEndPoint = _applyLineSnapping(startPoint!, details.localPosition);
                              } else {
                                currentEndPoint = details.localPosition;
                              }
                              
                              if (currentMode == DrawingMode.freehand || currentMode == DrawingMode.eraser) {
                                currentFreehandPoints.add(details.localPosition);
                              }
                            }
                          });
                        },
                        onPanEnd: (details) {
                           setState(() {
                             currentSnapHighlight = null; // Clear snap visual
                             if (currentMode == DrawingMode.select) {
                               lastPanPosition = null;
                               return;
                             }

                             final paint = _getPaint(currentMode == DrawingMode.eraser);
                             
                             if (currentMode == DrawingMode.freehand || currentMode == DrawingMode.eraser) {
                               objects.add(FreehandObject(List.from(currentFreehandPoints), paint));
                               currentFreehandPoints.clear();
                             } else if (currentMode == DrawingMode.line && startPoint != null && currentEndPoint != null) {
                               objects.add(LineObject(startPoint!, currentEndPoint!, paint));
                             } else if (currentMode == DrawingMode.rectangle && startPoint != null && currentEndPoint != null) {
                               objects.add(RectObject(Rect.fromPoints(startPoint!, currentEndPoint!), paint));
                             } else if (currentMode == DrawingMode.circle && startPoint != null && currentEndPoint != null) {
                               final radius = (currentEndPoint! - startPoint!).distance;
                               objects.add(CircleObject(startPoint!, radius, paint));
                             }
                             
                             startPoint = null;
                             currentEndPoint = null;
                             lastPanPosition = null;
                           });
                        },
                        child: CustomPaint(
                          painter: _DrawingPainter(
                            objects: objects,
                            currentMode: currentMode,
                            startPoint: startPoint,
                            currentEndPoint: currentEndPoint,
                            currentFreehandPoints: currentFreehandPoints,
                            previewPaint: _getPaint(currentMode == DrawingMode.eraser),
                            selectedObject: selectedObject,
                            snapHighlight: currentSnapHighlight,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Eraser Cursor Overlay
                if (currentMode == DrawingMode.eraser && isHovering)
                  Positioned(
                    left: mousePosition.dx - (strokeWidth * 2.5),
                    top: mousePosition.dy - (strokeWidth * 2.5),
                    child: IgnorePointer(
                      child: Container(
                        width: strokeWidth * 5,
                        height: strokeWidth * 5,
                        decoration: BoxDecoration(
                          color: Colors.pink.withOpacity(0.5), // Dusty pink
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.pinkAccent, width: 1),
                          boxShadow: [
                             BoxShadow(color: Colors.pink.withOpacity(0.3), blurRadius: 4),
                          ]
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ThemeColors.cardBackground(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ThemeColors.border(context)),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Tools
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Color Picker (Single color, opens submenu)
                _buildColorPickerPopup(),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: ThemeColors.border(context)),
                
                // 2. Move (DrawMode.select)
                _buildToolButton(Icons.open_with, DrawingMode.select, 'Taşı'),
                
                // 3. Drawing Tools Submenu
                _buildDrawingToolsPopup(),
                
                // 4. Eraser
                _buildToolButton(Icons.cleaning_services, DrawingMode.eraser, 'Silgi'),
                
                Container(width: 1, height: 24, color: ThemeColors.border(context)),
                const SizedBox(width: 8),

                // 5. Undo
                IconButton(
                  icon: Icon(Icons.undo, color: ThemeColors.textPrimary(context), size: 20),
                  onPressed: _undo,
                  tooltip: 'Geri Al',
                ),

                // 6. Delete
                IconButton(
                  icon: Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                  onPressed: _clear,
                  tooltip: 'Temizle',
                ),

                // 7. Save
                IconButton(
                  icon: Icon(Icons.save, color: Colors.tealAccent, size: 20),
                  onPressed: _saveCurrentSketch,
                  tooltip: 'Kaydet',
                ),

                // 8. Select from Saved
                IconButton(
                  icon: Icon(Icons.folder_open, color: Colors.orangeAccent, size: 20),
                  onPressed: _showLoadSketchDialog,
                  tooltip: 'Kayıtlılardan Seç',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          Container(height: 1, width: double.infinity, color: ThemeColors.border(context)),
          const SizedBox(height: 10),

          // Row 2: Stroke Width Slider
          Row(
            children: [
              Icon(Icons.line_weight, color: ThemeColors.textSecondary(context), size: 16),
              const SizedBox(width: 10),
              Text('Kalınlık Seçme:', style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    min: 1.0,
                    max: 20.0,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.white10,
                    value: strokeWidth,
                    onChanged: (val) => setState(() => strokeWidth = val),
                  ),
                ),
              ),
              Text(strokeWidth.round().toString(), style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerPopup() {
    final colors = [Colors.white, Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple, Colors.orange];
    
    return PopupMenuButton<Color>(
      onSelected: (color) {
        setState(() {
          selectedColor = color;
          if (currentMode == DrawingMode.eraser) currentMode = DrawingMode.freehand;
        });
      },
      color: ThemeColors.cardBackground(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => colors.map((color) => PopupMenuItem<Color>(
        value: color,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        ),
      )).toList(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selectedColor,
          shape: BoxShape.circle,
          border: Border.all(color: ThemeColors.textPrimary(context), width: 2),
          boxShadow: [BoxShadow(color: selectedColor.withOpacity(0.4), blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildDrawingToolsPopup() {
    final tools = [
      {'mode': DrawingMode.freehand, 'icon': Icons.edit, 'label': 'Kalem (Elle)'},
      {'mode': DrawingMode.line, 'icon': Icons.minimize, 'label': 'Düz Çizgi'},
      {'mode': DrawingMode.rectangle, 'icon': Icons.crop_square, 'label': 'Kare'},
      {'mode': DrawingMode.circle, 'icon': Icons.circle_outlined, 'label': 'Yuvarlak'},
    ];

    // Find current tool icon
    IconData currentToolIcon = Icons.edit;
    for (var tool in tools) {
      if (tool['mode'] == currentMode) {
        currentToolIcon = tool['icon'] as IconData;
      }
    }

    return PopupMenuButton<DrawingMode>(
      onSelected: (mode) => setState(() => currentMode = mode),
      color: ThemeColors.cardBackground(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => tools.map((tool) => PopupMenuItem<DrawingMode>(
        value: tool['mode'] as DrawingMode,
        child: Row(
          children: [
            Icon(tool['icon'] as IconData, color: ThemeColors.textPrimary(context), size: 20),
            const SizedBox(width: 10),
            Text(tool['label'] as String, style: TextStyle(color: Colors.white)),
          ],
        ),
      )).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          currentToolIcon, 
          color: (currentMode == DrawingMode.freehand || currentMode == DrawingMode.line || 
                  currentMode == DrawingMode.rectangle || currentMode == DrawingMode.circle) 
                 ? Colors.orange : Colors.white70,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildToolButton(IconData icon, DrawingMode mode, String tooltip) {
    bool isSelected = currentMode == mode;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.orange : Colors.white70, size: 22),
      tooltip: tooltip,
      onPressed: () => setState(() => currentMode = mode),
    );
  }

  Widget _buildColorButton(Color color) {
    bool isSelected = selectedColor == color && currentMode != DrawingMode.eraser;
    return GestureDetector(
      onTap: () => setState(() {
        selectedColor = color;
        if (currentMode == DrawingMode.eraser) currentMode = DrawingMode.freehand;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: ThemeColors.textPrimary(context), width: 2) : null,
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingObject> objects;
  final DrawingMode currentMode;
  final Offset? startPoint;
  final Offset? currentEndPoint;
  final List<Offset> currentFreehandPoints;
  final Paint previewPaint;
  final DrawingObject? selectedObject;
  final Offset? snapHighlight;

  _DrawingPainter({
    required this.objects,
    required this.currentMode,
    this.startPoint,
    this.currentEndPoint,
    required this.currentFreehandPoints,
    required this.previewPaint,
    this.selectedObject,
    this.snapHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Saved Objects
    for (var obj in objects) {
      obj.draw(canvas, Paint()); // Paint style is embedded in object
      
      // Highlight selected
      if (selectedObject == obj) {
        // Draw selection halo/box
        // Since we don't have easy bounding box for all, let's just draw it again with highlight glow
        // Or better, draw selection indicators.
        // For simplicity, re-draw with a thick semi-transparent white line underneath? No, objects have their own draw.
        // Let's draw a bounding rect if possible or just rely on user knowing.
        // Drawing a red box around selected object for now would be good but requires bounding box logic.
        // Let's add a simple marker at the "center" or draw points.
      }
    }
    
    // Draw selection highlight overlay
    if (selectedObject != null) {
      Paint highlightPaint = Paint()
        ..color = Colors.blue.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
        
       // This is expensive to redraw specifically for highlight using same draw logic,
       // but generic selection highlight is hard without bounds.
       // Let's just assume selection is visible by context.
       // Actually, let's draw snap points of selected object to indicate selection + snap readiness.
       for (var p in selectedObject!.getSnapPoints()) {
         canvas.drawCircle(p, 4, Paint()..color = Colors.blue);
       }
    }
    
    // Snap Highlight
    if (snapHighlight != null) {
      canvas.drawCircle(snapHighlight!, 6, Paint()..color = Colors.greenAccent);
      canvas.drawLine(
        snapHighlight! - const Offset(10, 0), 
        snapHighlight! + const Offset(10, 0), 
        Paint()..color = Colors.greenAccent ..strokeWidth = 2);
       canvas.drawLine(
        snapHighlight! - const Offset(0, 10), 
        snapHighlight! + const Offset(0, 10), 
        Paint()..color = Colors.greenAccent ..strokeWidth = 2);
    }

    // Draw Preview (Current Action)
    if (startPoint == null || currentEndPoint == null) return;
    
    if (currentMode == DrawingMode.freehand || currentMode == DrawingMode.eraser) {
      if (currentFreehandPoints.isNotEmpty) {
        for (int i = 0; i < currentFreehandPoints.length - 1; i++) {
           canvas.drawLine(currentFreehandPoints[i], currentFreehandPoints[i+1], previewPaint);
        }
      }
    } else if (currentMode == DrawingMode.line) {
       canvas.drawLine(startPoint!, currentEndPoint!, previewPaint);
    } else if (currentMode == DrawingMode.rectangle) {
       canvas.drawRect(Rect.fromPoints(startPoint!, currentEndPoint!), previewPaint);
    } else if (currentMode == DrawingMode.circle) {
       final radius = (currentEndPoint! - startPoint!).distance;
       canvas.drawCircle(startPoint!, radius, previewPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
