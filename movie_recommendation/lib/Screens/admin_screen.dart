import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminScreen extends StatefulWidget {
  final String adminUsername;
  const AdminScreen({super.key, required this.adminUsername});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _errorMessage = ""; // Ekranda hatayı göstermek için

  @override
  void initState() {
    super.initState();
    _fetchAdminStats();
  }

  Future<void> _fetchAdminStats() async {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/admin/stats?username=${widget.adminUsername}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        // SORUN BURADAYDI: Backend hata verirse dönmeyi durdur!
        print(
          "BACKEND HATASI: Kod ${response.statusCode} - Mesaj: ${response.body}",
        );
        setState(() {
          _errorMessage = "Veriler çekilemedi. Hata: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Bağlantı Hatası: $e");
      setState(() {
        _errorMessage = "Sunucuya bağlanılamadı!";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String type, int id) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/admin/delete_$type/$id');
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': widget.adminUsername}),
      );
      if (response.statusCode == 200) {
        _fetchAdminStats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$type başarıyla silindi"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Silme işlemi başarısız oldu."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Silme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // GERİ TUŞUNUN ÇALIŞMASI İÇİN APPBAR'I HER DURUMDA ÇİZİYORUZ
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF141414),
        appBar: AppBar(
          title: const Text(
            '👑 Yönetici Paneli',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ), // Geri tuşu rengi
          backgroundColor: Colors.purple[800],
          // Sadece yükleme bitmişse ve hata yoksa sekmeleri göster
          bottom: (_isLoading || _errorMessage.isNotEmpty)
              ? null
              : const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: "Kullanıcılar"),
                    Tab(text: "Son Yorumlar"),
                  ],
                ),
        ),
        body: _buildBodyContent(),
      ),
    );
  }

  // EKRANIN İÇERİĞİNİ DURUMA GÖRE ÇİZEN YARDIMCI WIDGET
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                "Kullanıcılar",
                _stats?['user_count'] ?? 0,
                Icons.people,
              ),
              _buildStatCard(
                "Yorumlar",
                _stats?['comment_count'] ?? 0,
                Icons.comment,
              ),
            ],
          ),
        ),
        const Divider(color: Colors.grey),
        Expanded(
          child: TabBarView(
            children: [_buildUsersList(), _buildCommentsList()],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.purple[300], size: 30),
          const SizedBox(height: 10),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _stats?['all_users'] ?? [];
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(
            u['username'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            u['email'],
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteItem('user', u['id']),
          ),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    final comments = _stats?['recent_comments'] ?? [];
    return ListView.builder(
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final c = comments[index];
        return ListTile(
          title: Text(c['body'], style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            "Yazar: ${c['author']} • Film ID: ${c['movie_id']}",
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteItem('comment', c['id']),
          ),
        );
      },
    );
  }
}
