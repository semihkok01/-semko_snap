import '../models/category.dart';
import 'api_service.dart';

class CategoryService {
  CategoryService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static bool _loadedActive = false;
  static bool _loadedAll = false;
  static List<Category> _allCategories = const [];

  Future<List<Category>> fetchCategories({
    bool forceRefresh = false,
    bool includeInactive = false,
  }) async {
    final canUseCache = includeInactive ? _loadedAll : _loadedActive;

    if (canUseCache && !forceRefresh) {
      return includeInactive
          ? List<Category>.unmodifiable(
              _allCategories.isNotEmpty ? _allCategories : Category.all,
            )
          : Category.all;
    }

    final response = await _apiService.get(
      'get_categories.php',
      queryParameters: {
        if (includeInactive) 'include_inactive': 1,
      },
    );

    return _applyResponse(response, includeInactive: includeInactive);
  }

  Future<List<Category>> saveCategory({
    int? id,
    required String name,
    required String icon,
    required String color,
    required bool isActive,
  }) async {
    final response = await _apiService.post(
      'save_category.php',
      body: {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'is_active': isActive,
      },
    );

    return _applyResponse(response, includeInactive: true);
  }

  List<Category> _applyResponse(
    Map<String, dynamic> response, {
    required bool includeInactive,
  }) {
    final items = (response['categories'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    final parsed = items.map(Category.fromJson).toList();
    final activeCategories = parsed.where((category) => category.isActive).toList();

    if (parsed.isNotEmpty) {
      _allCategories = parsed;
      _loadedAll = includeInactive || parsed.any((category) => !category.isActive);
    }

    if (activeCategories.isNotEmpty) {
      Category.setRegistry(activeCategories);
      _loadedActive = true;
    }

    return includeInactive
        ? List<Category>.unmodifiable(
            _allCategories.isNotEmpty ? _allCategories : Category.all,
          )
        : Category.all;
  }
}
