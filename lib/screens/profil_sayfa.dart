import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/theme_colors.dart';
import '../services/storage_service.dart';
import 'login_sayfa.dart';

class ProfilSayfa extends StatefulWidget {
  const ProfilSayfa({super.key});

  @override
  State<ProfilSayfa> createState() => _ProfilSayfaState();
}

class _ProfilSayfaState extends State<ProfilSayfa> {
  final AuthService _auth = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;
  
  late TextEditingController _nameController;
  DateTime? _birthDate;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _auth.getUserData();
      if (data != null && mounted) {
        setState(() {
          if (data['birthDate'] != null) {
            _birthDate = DateTime.parse(data['birthDate']);
          }
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    
    bool success = true;
    String message = 'Profil başarıyla güncellendi';

    try {
      if (_nameController.text != (user?.displayName ?? '')) {
        bool nameResult = await _auth.updateDisplayName(_nameController.text);
        if (!nameResult) {
          success = false;
          message = 'İsim güncellenirken hata oluştu';
        }
      }

      if (_birthDate != null) {
        bool birthResult = await _auth.updateExtraInfo(_birthDate!);
        if (!birthResult) {
          success = false;
          message = 'Doğum tarihi güncellenirken hata oluştu';
        }
      }

      if (_passwordController.text.isNotEmpty) {
        if (_passwordController.text != _confirmPasswordController.text) {
          success = false;
          message = 'Şifreler eşleşmiyor';
        } else if (_passwordController.text.length < 6) {
          success = false;
          message = 'Yeni şifre en az 6 karakter olmalıdır';
        } else {
          bool passResult = await _auth.updatePassword(_passwordController.text);
          if (!passResult) {
            success = false;
            message = 'Şifre güncellenirken hata oluştu (Tekrar giriş yapmanız gerekebilir)';
          }
        }
      }
    } catch (e) {
      success = false;
      message = 'Bilinmeyen bir hata oluştu: ${e.toString()}';
    }

    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: success ? Colors.green : Colors.red, duration: const Duration(seconds: 3)),
      );
      if (success && _passwordController.text.isNotEmpty) {
        _passwordController.clear();
        _confirmPasswordController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: Text('Profil Bilgileri', style: TextStyle(color: ThemeColors.textPrimary(context))),
        backgroundColor: ThemeColors.headerBackground(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              user?.email ?? 'E-posta bulunamadı',
              style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 16),
            ),
            const SizedBox(height: 30),
            
            // İsim Güncelleme
            TextField(
              controller: _nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'İsim Soyisim',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.badge, color: Colors.blueAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 20),

            // Doğum Tarihi Güncelleme
            TextFormField(
              readOnly: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Doğum Tarihi',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    _birthDate = pickedDate;
                  });
                }
              },
              controller: TextEditingController(text: _birthDate == null ? "" : "${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}"),
            ),
            const SizedBox(height: 20),
            
            // Şifre Güncelleme
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Yeni Şifre (Boş bırakın değiştirmemek için)',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Şifre Onay
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Yeni Şifre Tekrar',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
              ),
            ),
            
            const SizedBox(height: 40),
            
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  onPressed: _updateProfile,
                  icon: Icon(Icons.save),
                  label: const Text('Değişiklikleri Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
            const SizedBox(height: 20),
            
            OutlinedButton.icon(
              onPressed: () async {
                final bool? confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Çıkış Yap'),
                    content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet')),
                    ],
                  ),
                );
                if (confirm == true) {
                  // Verileri temizle
                  await StorageService().clearLocalData();
                  await _auth.signOut();
                  // Doğrudan Login sayfasına yönlendir
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginSayfa()),
                      (route) => false,
                    );
                  }
                }
              },
              icon: Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
