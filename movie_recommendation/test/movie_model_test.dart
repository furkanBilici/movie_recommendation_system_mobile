import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommendation/models/movie.dart';

void main() {
  group('Movie Model Testleri', () {
    test('JSON verisi başarıyla modele dönüşmeli', () {
      final json = {
        'id': 500,
        'title': 'Test Filmi',
        'overview': 'Bu bir test açıklamasıdır.',
        'poster_path': '/test.jpg',
        'vote_average': 9.5,
      };

      final movie = Movie.fromJson(json);
      expect(movie.id, 500);
      expect(movie.title, 'Test Filmi');
      expect(movie.voteAverage, 9.5);
    });

    test('Eksik JSON verisi geldiğinde varsayılan değerler atanmalı', () {
      final json = {'id': 1, 'title': 'Başlıksız Film'};

      final movie = Movie.fromJson(json);

      expect(movie.overview, isNotNull);
    });
  });
}
