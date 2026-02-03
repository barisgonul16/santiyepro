import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_colors.dart';

class HaritalarSayfaPage extends StatefulWidget {
  final List<LocationItem> savedLocations;
  final Function(LocationItem) onAddLocation;
  final Function(int) onDeleteLocation;

  const HaritalarSayfaPage({
    super.key,
    required this.savedLocations,
    required this.onAddLocation,
    required this.onDeleteLocation,
  });

  @override
  State<HaritalarSayfaPage> createState() => _HaritalarSayfaPageState();
}

class LocationItem {
  String name;
  double latitude;
  double longitude;
  String type; // 'Ev', 'Şantiye', 'Diğer'

  LocationItem({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
      };

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      type: json['type'],
    );
  }
}

class _HaritalarSayfaPageState extends State<HaritalarSayfaPage> {
  void _addLocation() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedType = 'Diğer';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF333333),
            title: const Text('Yeni Konum Ekle', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Konum Adı',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                   DropdownButton<String>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF444444),
                    isExpanded: true,
                    style: TextStyle(color: Colors.white),
                    items: ['Ev', 'Şantiye', 'Diğer']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedType = val);
                      }
                    },
                   ),
                  const SizedBox(height: 10),
                   Row(
                     children: [
                       Expanded(
                         child: TextField(
                          controller: latController,
                          keyboardType: TextInputType.text,
                          style: TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Enlem (Lat)',
                            labelStyle: TextStyle(color: Colors.white70),
                            hintText: '40.123',
                            hintStyle: TextStyle(color: Colors.white24),
                          ),
                          onChanged: (value) {
                            // Google Maps koordinat formatını (Enlem, Boylam) akıllıca ayrıştır
                            // Virgül-boşluk (, ) veya çift boşluk ayrıştırıcıdır.
                            // Tek virgül decimal (ondalık) işareti olabilir (Örn: 40,123).
                            
                            List<String> parts = [];
                            if (value.contains(', ')) {
                              parts = value.split(', ');
                            } else if (value.contains('  ')) {
                              parts = value.split(RegExp(r' +'));
                            }
                            
                            if (parts.length >= 2) {
                              final latPart = parts[0].trim();
                              final lngPart = parts[1].trim();
                              
                              // Sayı formatına çevir (virgülü noktaya çevirerek kontrol et)
                              final latDouble = double.tryParse(latPart.replaceAll(',', '.'));
                              final lngDouble = double.tryParse(lngPart.replaceAll(',', '.'));
                              
                              if (latDouble != null && lngDouble != null) {
                                setDialogState(() {
                                  // Kullanıcının girdiği orijinal (virgüllü) hali de koruyabiliriz 
                                  // veya standart nokta formatına çekebiliriz.
                                  latController.text = latPart;
                                  lngController.text = lngPart;
                                });
                              }
                            }
                          },
                        ),
                       ),
                       const SizedBox(width: 15),
                       Expanded(
                         child: TextField(
                          controller: lngController,
                          keyboardType: TextInputType.text,
                          style: TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Boylam (Lng)',
                            labelStyle: TextStyle(color: Colors.white70),
                             hintText: '29.456',
                            hintStyle: TextStyle(color: Colors.white24),
                          ),
                        ),
                       ),
                     ],
                   ),
                  const SizedBox(height: 10),
                  const Text(
                    'İpucu: Google Maps\'te bir yere sağ tıklayıp koordinatları kopyalayabilirsiniz.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
               TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                   final name = nameController.text.trim();
                   final latStr = latController.text.trim().replaceAll(',', '.');
                   final lngStr = lngController.text.trim().replaceAll(',', '.');
                   
                   final lat = double.tryParse(latStr);
                   final lng = double.tryParse(lngStr);

                   if (name.isNotEmpty && lat != null && lng != null) {
                      widget.onAddLocation(LocationItem(
                           name: name,
                           latitude: lat,
                           longitude: lng,
                           type: selectedType,
                         ));
                      Navigator.pop(context);
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Lütfen geçerli değerler giriniz')),
                     );
                   }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _deleteLocation(int index) {
    widget.onDeleteLocation(index);
  }

  Future<void> _openNavigation(LocationItem item) async {
    final urlString = 'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}';
    final uri = Uri.parse(urlString);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harita açılamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
       color: const Color(0xFF1a1a1a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           LayoutBuilder(
             builder: (context, constraints) {
               final isMobile = constraints.maxWidth < 500;
               if (isMobile) {
                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                      'Konum ve Haritalar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                     ),
                     const SizedBox(height: 10),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                         onPressed: _addLocation,
                         icon: Icon(Icons.add_location_alt),
                         label: Text('Konum Ekle'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal,
                           foregroundColor: Colors.white,
                         ),
                       ),
                     ),
                   ],
                 );
               }
               return Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Flexible(
                     child: Text(
                      'Konum ve Haritalar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                     ),
                    ),
                   ElevatedButton.icon(
                     onPressed: _addLocation,
                     icon: Icon(Icons.add_location_alt),
                     label: Text('Konum Ekle'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.teal,
                       foregroundColor: Colors.white,
                     ),
                   ),
                 ],
               );
             },
           ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.savedLocations.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz kayıtlı bir konum yok.',
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.savedLocations.length,
                    itemBuilder: (context, index) {
                      final item = widget.savedLocations[index];
                      IconData icon;
                      Color color;
                      
                      switch (item.type) {
                        case 'Ev':
                          icon = Icons.home;
                          color = Colors.orangeAccent;
                          break;
                        case 'Şantiye':
                          icon = Icons.construction;
                          color = Colors.yellowAccent;
                          break;
                        default:
                          icon = Icons.place;
                          color = Colors.blueAccent;
                      }

                      return Card(
                         color: ThemeColors.cardBackground(context),
                         margin: const EdgeInsets.only(bottom: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: ListTile(
                           onTap: () => _openNavigation(item), // Make whole card tappable
                           leading: Container(
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: color.withOpacity(0.2),
                               shape: BoxShape.circle,
                             ),
                             child: Icon(icon, color: color),
                           ),
                           title: Text(
                             item.name,
                             style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
                           ),
                           subtitle: Text(
                             'Lat: ${item.latitude}, Lng: ${item.longitude}',
                             style: TextStyle(color: Colors.white54, fontSize: 12),
                           ),
                           trailing: IconButton(
                             icon: Icon(Icons.delete, color: Colors.redAccent),
                             onPressed: () => _deleteLocation(index),
                           ),
                         ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
