import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_preferences_service.dart';
import '../services/category_service.dart';
import '../widgets/brand_app_bar_title.dart';

class CategoryFavoritesScreen extends StatefulWidget {
  const CategoryFavoritesScreen({super.key});

  @override
  State<CategoryFavoritesScreen> createState() => _CategoryFavoritesScreenState();
}

class _CategoryFavoritesScreenState extends State<CategoryFavoritesScreen> {
  final CategoryService _categoryService = CategoryService();
  final CategoryPreferencesService _preferencesService =
      CategoryPreferencesService();

  bool _loading = true;
  bool _saving = false;
  List<Category> _categories = const [];
  List<int> _favoriteCategoryIds = const [];

  List<Category> get _favoriteCategories {
    final categoryById = <int, Category>{
      for (final category in _categories) category.id: category,
    };

    return _favoriteCategoryIds
        .map((categoryId) => categoryById[categoryId])
        .whereType<Category>()
        .toList();
  }

  List<Category> get _otherCategories {
    final favoriteIds = _favoriteCategoryIds.toSet();
    return _categories
        .where((category) => !favoriteIds.contains(category.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    List<Category> categories;
    try {
      categories = await _categoryService.fetchCategories(
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      categories = Category.all;
    }

    final favoriteIds = await _preferencesService.sanitizeFavoriteCategoryIds(
      categories,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _favoriteCategoryIds = favoriteIds;
      _loading = false;
    });
  }

  Future<void> _saveFavorites(List<int> favoriteCategoryIds) async {
    final previousFavoriteIds = _favoriteCategoryIds;

    setState(() {
      _favoriteCategoryIds = favoriteCategoryIds;
      _saving = true;
    });

    try {
      await _preferencesService.saveFavoriteCategoryIds(favoriteCategoryIds);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _favoriteCategoryIds = previousFavoriteIds;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favoriten konnten nicht gespeichert werden.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Category category) async {
    final updatedFavorites = List<int>.from(_favoriteCategoryIds);

    if (updatedFavorites.contains(category.id)) {
      updatedFavorites.remove(category.id);
    } else {
      updatedFavorites.add(category.id);
    }

    await _saveFavorites(updatedFavorites);
  }

  Future<void> _reorderFavorites(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final updatedFavorites = List<int>.from(_favoriteCategoryIds);
    final movedCategoryId = updatedFavorites.removeAt(oldIndex);
    updatedFavorites.insert(newIndex, movedCategoryId);

    await _saveFavorites(updatedFavorites);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandAppBarTitle('Kategorie-Favoriten')),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Favoriten stehen in der Kategorieauswahl immer zuerst.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Lege hier deine wichtigsten Kategorien fest und sortiere sie per Drag & Drop.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          if (_saving) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Favoriten',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_favoriteCategoryIds.isNotEmpty)
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _saveFavorites(const <int>[]),
                                  child: const Text('Zurücksetzen'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_favoriteCategories.isEmpty)
                            _EmptyFavoritesNotice(
                              message:
                                  'Noch keine Favoriten ausgewählt. Tippe unten auf den Stern, um Kategorien oben anzuheften.',
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: _favoriteCategories.length,
                              onReorder: _reorderFavorites,
                              itemBuilder: (context, index) {
                                final category = _favoriteCategories[index];
                                return _FavoriteCategoryTile(
                                  key: ValueKey('favorite-${category.id}'),
                                  category: category,
                                  index: index,
                                  onRemove: _saving
                                      ? null
                                      : () => _toggleFavorite(category),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alle aktiven Kategorien',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._otherCategories.map(
                            (category) => _CategoryOptionTile(
                              category: category,
                              onPressed:
                                  _saving ? null : () => _toggleFavorite(category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FavoriteCategoryTile extends StatelessWidget {
  const _FavoriteCategoryTile({
    super.key,
    required this.category,
    required this.index,
    required this.onRemove,
  });

  final Category category;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.16),
          foregroundColor: category.color,
          child: Icon(category.iconData),
        ),
        title: Text(
          category.localizedName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Erscheint beim Erfassen ganz oben.'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Aus Favoriten entfernen',
              onPressed: onRemove,
              icon: const Icon(
                Icons.star_rounded,
                color: Color(0xFFF59E0B),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.category,
    required this.onPressed,
  });

  final Category category;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: category.color.withValues(alpha: 0.16),
            foregroundColor: category.color,
            child: Icon(category.iconData),
          ),
          title: Text(category.localizedName),
          subtitle: const Text('Als Favorit oben anzeigen'),
          trailing: IconButton(
            tooltip: 'Zu Favoriten hinzufügen',
            onPressed: onPressed,
            icon: const Icon(Icons.star_border_rounded),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavoritesNotice extends StatelessWidget {
  const _EmptyFavoritesNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}
