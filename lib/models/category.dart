import 'package:flutter/material.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconName,
    required this.color,
    this.isActive = true,
    this.splitInHalf = false,
  });

  final int id;
  final String name;
  final String iconName;
  final Color color;
  final bool isActive;
  final bool splitInHalf;

  static final List<Category> _fallback = [
    const Category(
      id: 1,
      name: 'Essen',
      iconName: 'restaurant',
      color: Color(0xFFE76F51),
    ),
    const Category(
      id: 2,
      name: 'Auto',
      iconName: 'directions_car',
      color: Color(0xFF264653),
    ),
    const Category(
      id: 3,
      name: 'Einkauf',
      iconName: 'shopping_bag',
      color: Color(0xFFF4A261),
    ),
    const Category(
      id: 4,
      name: 'Reisen',
      iconName: 'flight',
      color: Color(0xFF2A9D8F),
    ),
    const Category(
      id: 5,
      name: 'Rechnungen',
      iconName: 'receipt_long',
      color: Color(0xFF577590),
    ),
    const Category(
      id: 6,
      name: 'Gesundheit',
      iconName: 'local_hospital',
      color: Color(0xFF90BE6D),
    ),
  ];

  static List<Category> _registry = List<Category>.from(_fallback);

  static List<Category> get all => List<Category>.unmodifiable(_registry);

  static void setRegistry(List<Category> categories) {
    if (categories.isEmpty) {
      return;
    }

    _registry = List<Category>.from(categories);
  }

  static void resetRegistry() {
    _registry = List<Category>.from(_fallback);
  }

  static Category byId(int id) {
    return _registry.firstWhere(
      (category) => category.id == id,
      orElse: () => _registry.isNotEmpty ? _registry.first : _fallback.first,
    );
  }

  static Category? byName(String? name) {
    if (name == null) {
      return null;
    }

    final normalized = name.trim().toLowerCase();

    for (final category in _registry) {
      if (category.name.toLowerCase() == normalized ||
          category.localizedName.toLowerCase() == normalized) {
        return category;
      }
    }

    return null;
  }

  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? 'Kategorie',
      iconName: _normalizeIconName((json['icon'] as String?)?.trim()),
      color: colorFromHex((json['color'] as String?)?.trim()),
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : ((json['is_active'] as num?)?.toInt() ?? 1) == 1,
      splitInHalf: json['split_in_half'] is bool
          ? json['split_in_half'] as bool
          : ((json['split_in_half'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? iconName,
    Color? color,
    bool? isActive,
    bool? splitInHalf,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      splitInHalf: splitInHalf ?? this.splitInHalf,
    );
  }

  static String _normalizeIconName(String? value) {
    if (value == null || value.isEmpty) {
      return 'category';
    }

    return iconChoices.any((choice) => choice.name == value)
        ? value
        : 'category';
  }

  static Color colorFromHex(String? value) {
    if (value == null || value.isEmpty) {
      return const Color(0xFF2563EB);
    }

    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6) {
      return const Color(0xFF2563EB);
    }

    final colorValue = int.tryParse(normalized, radix: 16);
    if (colorValue == null) {
      return const Color(0xFF2563EB);
    }

    return Color(0xFF000000 | colorValue);
  }

  String get localizedName {
    return _defaultGermanNames[name.trim().toLowerCase()] ?? name;
  }

  String get colorHex {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  IconData get iconData => iconForName(iconName);

  static IconData iconForName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static const List<CategoryIconChoice> iconChoices = [
    CategoryIconChoice('category', 'Allgemein'),
    CategoryIconChoice('restaurant', 'Essen'),
    CategoryIconChoice('shopping_bag', 'Einkauf'),
    CategoryIconChoice('directions_car', 'Auto'),
    CategoryIconChoice('local_gas_station', 'Tanken'),
    CategoryIconChoice('flight', 'Reisen'),
    CategoryIconChoice('receipt_long', 'Rechnungen'),
    CategoryIconChoice('local_hospital', 'Gesundheit'),
    CategoryIconChoice('home', 'Wohnen'),
    CategoryIconChoice('school', 'Bildung'),
    CategoryIconChoice('pets', 'Tiere'),
    CategoryIconChoice('sports_esports', 'Freizeit'),
  ];

  static const List<Color> colorChoices = [
    Color(0xFF2563EB),
    Color(0xFFE76F51),
    Color(0xFF264653),
    Color(0xFFF4A261),
    Color(0xFF2A9D8F),
    Color(0xFF577590),
    Color(0xFF90BE6D),
    Color(0xFF7C3AED),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const Map<String, String> _defaultGermanNames = {
    'food': 'Essen',
    'auto': 'Auto',
    'shopping': 'Einkauf',
    'travel': 'Reisen',
    'bills': 'Rechnungen',
    'health': 'Gesundheit',
  };
}

class CategoryIconChoice {
  const CategoryIconChoice(this.name, this.label);

  final String name;
  final String label;
}
