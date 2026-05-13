import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoginMode = true;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isAdmin = false;
  String _currentUsername = "";

  // Form Kontrolcüleri
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Profil Güncelleme Kontrolcüleri
  final _newUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();

  // Yorumlar Listesi
  List<dynamic> _myComments = [];
  bool _isLoadingComments = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null) {
      setState(() {
        _isLoggedIn = true;
        _currentUsername = savedUsername;
        _newUsernameController.text = savedUsername;
        _isAdmin = prefs.getBool('is_admin') ?? false;
      });
      _fetchMyComments();
    }
  }

  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      _isLoginMode
          ? 'http://10.0.2.2:5000/api/login'
          : 'http://10.0.2.2:5000/api/register',
    );
    final bodyData = _isLoginMode
        ? {
            'username': _usernameController.text,
            'password': _passwordController.text,
          }
        : {
            'username': _usernameController.text,
            'email': _emailController.text,
            'password': _passwordController.text,
          };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _usernameController.text);
        await prefs.setBool('is_admin', data['is_admin'] ?? false);

        setState(() {
          _isLoggedIn = true;
          _currentUsername = _usernameController.text;
          _newUsernameController.text = _currentUsername;
          _isAdmin = data['is_admin'] ?? false;
          _isLoading = false;
        });
        _fetchMyComments();
      } else {
        _showError("İşlem başarısız. Bilgilerinizi kontrol edin.");
      }
    } catch (e) {
      _showError("Sunucuya bağlanılamadı.");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    setState(() {
      _isLoggedIn = false;
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
      _myComments.clear();
    });
  }

  // --- 2. PROFİL GÜNCELLEME İŞLEMİ ---
  Future<void> _updateProfile() async {
    FocusScope.of(context).unfocus(); // Klavyeyi kapat
    final url = Uri.parse('http://10.0.2.2:5000/api/profile/update');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'current_username': _currentUsername,
          'new_username': _newUsernameController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // İsim değiştiyse hafızayı güncelle
        if (data['new_username'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', data['new_username']);
          setState(() {
            _currentUsername = data['new_username'];
          });
        }
        _newPasswordController.clear(); // Şifre kutusunu temizle
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil güncellendi!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(data['error'] ?? "Güncelleme başarısız.");
      }
    } catch (e) {
      _showError("Bağlantı hatası.");
    }
  }

  // --- 3. KENDİ YORUMLARINI ÇEKME VE SİLME ---
  Future<void> _fetchMyComments() async {
    setState(() => _isLoadingComments = true);
    final url = Uri.parse('http://10.0.2.2:5000/api/profile/comments');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': _currentUsername}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _myComments = json.decode(response.body);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/comments/$commentId');
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': _currentUsername}),
      );
      if (response.statusCode == 200) {
        _fetchMyComments(); // Listeyi yenile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yorum silindi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Silme hatası: $e");
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- ARAYÜZ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          '👤 Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE50914),
        centerTitle: true,
      ),
      body: _isLoggedIn ? _buildDashboard() : _buildAuthForm(),
    );
  }

  Widget _buildDashboard() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.person, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      _currentUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    if (_isAdmin)
                      IconButton(
                        icon: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.purpleAccent,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminScreen(adminUsername: _currentUsername),
                            ),
                          );
                        },
                        tooltip: "Yönetici Paneli",
                      ),

                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      onPressed: _logout,
                      tooltip: "Çıkış Yap",
                    ),
                  ],
                ),
              ],
            ),
          ),
          // SEKMELER (TABS)
          const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.settings), text: "Ayarlar"),
              Tab(icon: Icon(Icons.comment), text: "Yorumlarım"),
            ],
          ),

          // SEKME İÇERİKLERİ
          Expanded(
            child: TabBarView(
              children: [
                _buildSettingsTab(), // 1. Sekme: Ayarlar
                _buildMyCommentsTab(), // 2. Sekme: Yorumlar
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. SEKME: AYARLAR (İSİM VE ŞİFRE DEĞİŞTİRME)
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Profil Bilgilerini Güncelle",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            _newUsernameController,
            "Yeni Kullanıcı Adı",
            Icons.person,
            false,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            _newPasswordController,
            "Yeni Şifre (Değiştirmek istemiyorsanız boş bırakın)",
            Icons.lock,
            true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _updateProfile,
              child: const Text(
                "Bilgilerimi Kaydet",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. SEKME: YORUMLARIM
  Widget _buildMyCommentsTab() {
    if (_isLoadingComments)
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    if (_myComments.isEmpty)
      return const Center(
        child: Text(
          "Henüz hiç yorum yapmamışsın.",
          style: TextStyle(color: Colors.grey),
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _myComments.length,
      itemBuilder: (context, index) {
        final comment = _myComments[index];
        return Card(
          color: const Color(0xFF222222),
          child: ListTile(
            title: Text(
              comment['body'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              "Film ID: ${comment['movie_id']} • ${comment['timestamp']}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deleteComment(comment['id']),
            ),
          ),
        );
      },
    );
  }

  // --- GİRİŞ YAPMA FORMU (Öncekiyle Aynı) ---
  Widget _buildAuthForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            _isLoginMode ? "Giriş Yap" : "Hesap Oluştur",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildTextField(
            _usernameController,
            "Kullanıcı Adı",
            Icons.person,
            false,
          ),
          const SizedBox(height: 16),
          if (!_isLoginMode)
            _buildTextField(_emailController, "E-Posta", Icons.email, false),
          if (!_isLoginMode) const SizedBox(height: 16),
          _buildTextField(_passwordController, "Şifre", Icons.lock, true),
          const SizedBox(height: 30),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _submitAuth,
                  child: Text(
                    _isLoginMode ? "Giriş Yap" : "Kayıt Ol",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
            child: Text(
              _isLoginMode
                  ? "Hesabın yok mu? Hemen Kayıt Ol"
                  : "Zaten hesabın var mı? Giriş Yap",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isPassword,
  ) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF333333),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
