import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;

  const DetailScreen({super.key, required this.movie});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  bool _isLoggedIn = false;
  String _currentUsername = "";
  final TextEditingController _commentController = TextEditingController();

  // SEÇİLEN YILDIZ SAYISINI TUTACAK DEĞİŞKEN (0-5 arası)
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _fetchComments();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null) {
      setState(() {
        _isLoggedIn = true;
        _currentUsername = savedUsername;
      });
    }
  }

  Future<void> _fetchComments() async {
    final url = Uri.parse(
      'http://10.0.2.2:5000/api/comments/${widget.movie.id}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _comments = json.decode(response.body);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  // --- GÜNCELLENEN: HEM YORUM HEM PUAN GÖNDERME FONKSİYONU ---
  // --- GÜNCELLENEN: YILDIZLARI YORUMA EKLEYEN FONKSİYON ---
  Future<void> _postCommentAndRate() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen önce filme yıldız verin!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen bir yorum yazın!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 1. ZEKİCE DOKUNUŞ: Seçilen yıldızları emojiye çevirip yorumun en üstüne ekliyoruz (\n ile alt satıra geçiyoruz)
      String starEmojis = List.generate(_selectedRating, (index) => '⭐').join();
      String finalCommentText =
          "$starEmojis\n${_commentController.text.trim()}";

      // 2. YORUMU GÖNDER (Artık içinde yıldız emojileri de var)
      final commentUrl = Uri.parse(
        'http://10.0.2.2:5000/api/comments/${widget.movie.id}',
      );
      await http.post(
        commentUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _currentUsername,
          'body': finalCommentText,
        }),
      );

      // 3. PUANI GÖNDER
      final rateUrl = Uri.parse('http://10.0.2.2:5000/api/rate');
      await http.post(
        rateUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _currentUsername,
          'movie_id': widget.movie.id,
          'score': _selectedRating * 2,
        }),
      );

      // 4. EKRANI TEMİZLE VE YENİLE
      _commentController.clear();
      setState(() {
        _selectedRating = 0;
      });
      _fetchComments();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorum ve puan başarıyla kaydedildi!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Gönderme hatası: $e");
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
        _fetchComments();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: Text(
          widget.movie.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE50914),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.movie.posterPath,
                    height: 350,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.movie.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // ESKİ PUAN VERME BUTONUNU KALDIRDIK, SADECE FİLMİN ORTALAMA PUANI GÖRÜNÜYOR
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 5),
                        Text(
                          widget.movie.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Filmin Konusu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                widget.movie.overview,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(color: Colors.grey),

            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Topluluk Yorumları",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // YORUM YAZMA VE YILDIZ VERME BÖLÜMÜ
            if (_isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // YILDIZLAR
                    Row(
                      children: [
                        const Text(
                          "Puanın: ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...List.generate(5, (index) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(), // İkonlar arası boşluğu daraltır
                            icon: Icon(
                              index < _selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 30,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedRating =
                                    index + 1; // 1 ile 5 arası değer atar
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // YORUM KUTUSU VE GÖNDER BUTONU
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Bu film hakkında ne düşünüyorsun?",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF222222),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _postCommentAndRate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Yorum yapmak ve puan vermek için giriş yapmalısınız.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // YORUMLARI LİSTELEME
            _isLoadingComments
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Colors.red),
                    ),
                  )
                : _comments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Henüz yorum yapılmamış. İlk yorumu sen yap!",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final isMyComment = comment['author'] == _currentUsername;

                      return Card(
                        color: const Color(0xFF222222),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            comment['author'] ?? 'Kullanıcı',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            comment['body'] ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: isMyComment
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _deleteComment(comment['id']),
                                )
                              : Text(
                                  comment['timestamp'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
