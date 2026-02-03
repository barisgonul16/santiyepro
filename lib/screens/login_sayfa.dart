import 'package:flutter/material.dart';
import 'dart:io';
import '../services/auth_service.dart';
import 'kayit_sayfa.dart';

class LoginSayfa extends StatefulWidget {
  const LoginSayfa({super.key});

  @override
  State<LoginSayfa> createState() => _LoginSayfaState();
}

class _LoginSayfaState extends State<LoginSayfa> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Uygulama Simgesi
                  Image.asset(
                    'assets/app_icon_no_bg.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.engineering, size: 80, color: Colors.blue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ŞantiyePro Giriş',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val!.isEmpty ? 'Bir e-posta girin' : null,
                    onChanged: (val) => setState(() => email = val.trim()),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue)),
                    ),
                    obscureText: true,
                    validator: (val) => val!.length < 6 ? 'Şifre en az 6 karakter olmalı' : null,
                    onChanged: (val) => setState(() => password = val),
                  ),
                  const SizedBox(height: 10),
                  
                  // Şifremi Unuttum
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text('Şifremi Unuttum', style: TextStyle(color: Colors.orangeAccent)),
                      onPressed: () async {
                        if (email.isEmpty || !email.contains('@')) {
                          setState(() => error = 'Lütfen geçerli bir e-posta adresi girin');
                          return;
                        }
                        setState(() => loading = true);
                        try {
                          await _auth.sendPasswordResetEmail(email);
                          setState(() {
                            loading = false;
                            error = 'Sıfırlama bağlantısı e-postanıza gönderildi';
                          });
                        } catch (e) {
                           setState(() {
                            loading = false;
                            final errorMsg = e.toString();
                            if (errorMsg.contains('user-not-found')) {
                              error = 'Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.';
                            } else {
                              error = 'Hata: E-posta formatı geçersiz veya bir sorun oluştu.';
                            }
                          });
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  loading 
                    ? const CircularProgressIndicator(color: Colors.blueAccent)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()){
                            setState(() => loading = true);
                            dynamic result = await _auth.signInWithEmail(email, password);
                            if (result == null && mounted) {
                              setState(() {
                                error = 'E-posta veya şifre hatalı.';
                                loading = false;
                              });
                            }
                          }
                        },
                        child: const Text('Giriş Yap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                  const SizedBox(height: 15),
                  Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13.0)),
                  
                  TextButton(
                    child: const Text('Hesabınız yok mu? Hemen Kayıt Olun', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                    onPressed: () {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const KayitSayfa()));
                    },
                  ),
                  
                  // Google ile Giriş
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('VEYA', style: TextStyle(color: Colors.white54)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_circle, color: Colors.white, size: 24),
                      label: const Text('Google ile Giriş Yap', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        setState(() => loading = true);
                        try {
                          dynamic result = await _auth.signInWithGoogle();
                          if (result == null) {
                            if (mounted) {
                              setState(() {
                                error = 'Google girişi iptal edildi veya başarısız.';
                                loading = false;
                              });
                            }
                          } else {
                            // Başarılı giriş
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              loading = false;
                              error = 'Google giriş hatası: $e';
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
