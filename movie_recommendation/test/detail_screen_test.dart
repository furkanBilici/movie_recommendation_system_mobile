import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movie_recommendation/screens/detail_screen.dart';
import 'package:movie_recommendation/models/movie.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Film detay sayfası film bilgilerini doğru göstermeli', (
    WidgetTester tester,
  ) async {
    final testMovie = Movie(
      id: 1,
      title: 'Inception',
      overview: 'Rüya içinde rüya...',
      posterPath: 'https://image.tmdb.org/t/p/w500/test.jpg',
      voteAverage: 8.8,
    );

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(home: DetailScreen(movie: testMovie)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Inception'), findsNWidgets(2));
      expect(find.text('Rüya içinde rüya...'), findsOneWidget);
      expect(find.text('Topluluk Yorumları'), findsOneWidget);
    });
  });
}
