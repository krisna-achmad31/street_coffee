import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/domain/entities/coffee_shop.dart';
import 'package:street_coffee/presentation/pages/explore/filter_sheet.dart';

CoffeeShop _shop(String id,
        {double rating = 4, int minPrice = 10000, double? km, List<String> fac = const []}) =>
    CoffeeShop(
      id: id,
      name: id,
      address: '',
      latitude: 0,
      longitude: 0,
      rating: rating,
      reviewCount: 0,
      priceRange: '',
      minPrice: minPrice,
      maxPrice: minPrice + 10000,
      vibe: '',
      vibes: const [],
      facilities: fac,
      categories: const [],
      imageUrl: '',
      galleryUrls: const [],
      menuFavorites: const [],
      whatsappNumber: '',
      isOpen: true,
      openUntil: '22:00',
      openFrom: '08:00',
      isFeatured: false,
      description: '',
      distanceKm: km,
    );

void main() {
  final shops = [
    _shop('far-cheap', km: 3, minPrice: 8000, rating: 4.1, fac: ['WiFi']),
    _shop('near-pricey', km: 0.3, minPrice: 30000, rating: 4.8, fac: ['WiFi', 'Colokan']),
    _shop('mid-low', km: 1, minPrice: 15000, rating: 3.6),
  ];

  test('default sort is nearest first', () {
    final out = const ExploreFilters().applyLocal(shops);
    expect(out.map((s) => s.id), ['near-pricey', 'mid-low', 'far-cheap']);
  });

  test('rating 4+ and facilities filter locally', () {
    final out = const ExploreFilters(minRating: 4, facilities: {'Colokan'}).applyLocal(shops);
    expect(out.map((s) => s.id), ['near-pricey']);
  });

  test('cheapest and rating sorts', () {
    expect(const ExploreFilters(sort: ExploreSort.cheapest).applyLocal(shops).first.id,
        'far-cheap');
    expect(const ExploreFilters(sort: ExploreSort.rating).applyLocal(shops).first.id,
        'near-pricey');
  });

  test('count reflects active filters', () {
    expect(const ExploreFilters().count, 0);
    expect(const ExploreFilters(openNow: true, maxPrice: 25000, vibes: {'Deep Talk'}).count, 3);
  });

  test('distance text uses Indonesian decimal comma', () {
    expect(_shop('a', km: 0.35).distanceText, '350 m');
    expect(_shop('b', km: 1.24).distanceText, '1,2 km');
  });
}
