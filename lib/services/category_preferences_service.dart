import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';

class CategoryPreferencesService {
  static const String _favoriteCategoryIdsKey = 'favorite_category_ids';

  Future<List<int>> loadFavoriteCategoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteCategoryIdsKey)?.map(int.tryParse).whereType<int>().toList() ?? const <int>[];
  }

  Future<void> saveFavoriteCategoryIds(List<int> categoryIds) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitizedIds = <String>[];
    final seen = <int>{};

    for (final categoryId in categoryIds) {
      if (seen.add(categoryId)) {
        sanitizedIds.add(categoryId.toString());
      }
    }

    await prefs.setStringList(_favoriteCategoryIdsKey, sanitizedIds);
  }

  Future<List<int>> sanitizeFavoriteCategoryIds(List<Category> categories) async {
    final favoriteIds = await loadFavoriteCategoryIds();
    final validIds = categories.map((category) => category.id).toSet();
    final sanitized = favoriteIds.where(validIds.contains).toList();

    if (sanitized.length != favoriteIds.length) {
      await saveFavoriteCategoryIds(sanitized);
    }

    return sanitized;
  }

  Future<List<Category>> sortCategories(List<Category> categories) async {
    final favoriteIds = await loadFavoriteCategoryIds();
    return sortCategoriesWithFavoriteIds(
      categories,
      favoriteIds: favoriteIds,
    );
  }

  List<Category> sortCategoriesWithFavoriteIds(
    List<Category> categories, {
    required List<int> favoriteIds,
  }) {
    if (categories.isEmpty) {
      return const <Category>[];
    }

    final categoryById = <int, Category>{
      for (final category in categories) category.id: category,
    };
    final orderedFavorites = <Category>[];
    final favoriteSet = <int>{};

    for (final favoriteId in favoriteIds) {
      final category = categoryById[favoriteId];
      if (category != null && favoriteSet.add(favoriteId)) {
        orderedFavorites.add(category);
      }
    }

    final remainingCategories = categories
        .where((category) => !favoriteSet.contains(category.id))
        .toList();

    return List<Category>.unmodifiable(<Category>[
      ...orderedFavorites,
      ...remainingCategories,
    ]);
  }
}
