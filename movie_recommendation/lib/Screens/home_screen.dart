import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/movie.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Movie> movies = [];
  List<dynamic> genres = [];
  bool isLoading = true;

  // ARAMA VE FİLTRELEME DEĞİŞKENLERİ
  String searchQuery = "";
  int? selectedGenreId;
  String selectedFilterType =
      "popular"; // popular (Günün), top_rated (TMDB), community_top (Topluluk)

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchGenres();
    fetchMovies();
  }

  Future<void> fetchGenres() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/genres');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          genres = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Kategori Hatası: $e");
    }
  }

  Future<void> fetchMovies() async {
    setState(() => isLoading = true);

    // URL'yi seçilen tüm filtrelere göre dinamik oluşturuyoruz
    String urlStr =
        'http://10.0.2.2:5000/api/recommend?filter_type=$selectedFilterType&';
    if (searchQuery.isNotEmpty) urlStr += 'query=$searchQuery&';
    if (selectedGenreId != null) urlStr += 'genre_id=$selectedGenreId&';

    try {
      final response = await http.get(Uri.parse(urlStr));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        setState(() {
          movies = results
              .map((movieJson) => Movie.fromJson(movieJson))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Film Hatası: $e");
      setState(() => isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() => searchQuery = query);
    fetchMovies();
  }

  void _onGenreSelected(int? genreId) {
    setState(() => selectedGenreId = genreId);
    fetchMovies();
  }

  void _onFilterTypeSelected(String type) {
    setState(() => selectedFilterType = type);
    fetchMovies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          '🎬 Filmler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE50914),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. ARAMA ÇUBUĞU
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Film Ara...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch("");
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF222222),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _onSearch,
            ),
          ),

          // 2. ANA FİLTRELER (Günün Önerilenleri, TMDB, Topluluk)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                _buildMainFilterChip("🔥 Günün Önerilenleri", "popular"),
                const SizedBox(width: 8),
                _buildMainFilterChip("⭐ TMDB En İyiler", "top_rated"),
                const SizedBox(width: 8),
                _buildMainFilterChip("👥 Topluluğun Seçimi", "community_top"),
              ],
            ),
          ),

          // 3. AÇILIR KAPANIR KATEGORİ (TÜR) MENÜSÜ
          if (genres.isNotEmpty)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent), // Çizgileri gizler
              child: ExpansionTile(
                title: const Text(
                  "Kategoriler (Türler)",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: const Icon(Icons.filter_list, color: Colors.redAccent),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white70,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Wrap(
                      spacing: 8.0, // Yan yana boşluk
                      runSpacing: 0.0, // Alt alta boşluk
                      children: [
                        // TÜMÜ BUTONU
                        ChoiceChip(
                          label: const Text(
                            "Tümü",
                            style: TextStyle(color: Colors.white),
                          ),
                          selected: selectedGenreId == null,
                          selectedColor: const Color(0xFFE50914),
                          backgroundColor: const Color(0xFF333333),
                          onSelected: (selected) => _onGenreSelected(null),
                        ),
                        // DİĞER KATEGORİLER
                        ...genres.map((genre) {
                          final isSelected = selectedGenreId == genre['id'];
                          return ChoiceChip(
                            label: Text(
                              genre['name'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE50914),
                            backgroundColor: const Color(0xFF333333),
                            onSelected: (selected) => _onGenreSelected(
                              isSelected ? null : genre['id'],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(color: Colors.grey, height: 1),

          // 4. FİLM LİSTESİ
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  )
                : movies.isEmpty
                ? const Center(
                    child: Text(
                      "Bu kriterlere uygun film bulunamadı.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return Card(
                        color: const Color(0xFF222222),
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(
                              movie.posterPath,
                              width: 60,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            movie.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '⭐ ${movie.voteAverage.toStringAsFixed(1)} / 10',
                              style: const TextStyle(color: Colors.amber),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailScreen(movie: movie),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ANA FİLTRE BUTONLARINI OLUŞTURAN YARDIMCI WIDGET
  Widget _buildMainFilterChip(String label, String filterType) {
    final isSelected = selectedFilterType == filterType;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFE50914),
      backgroundColor: const Color(0xFF333333),
      onSelected: (selected) {
        if (selected) _onFilterTypeSelected(filterType);
      },
    );
  }
}
