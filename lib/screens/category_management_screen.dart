import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../widgets/brand_app_bar_title.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final CategoryService _categoryService = CategoryService();

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await _categoryService.fetchCategories(
        forceRefresh: forceRefresh,
        includeInactive: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
      });
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = exception.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor({Category? category}) async {
    final didChange = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryEditorDialog(category: category),
    );

    if (!mounted || didChange != true) {
      return;
    }

    await _loadCategories(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _categories.where((category) => category.isActive).toList();
    final inactiveCategories = _categories.where((category) => !category.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: const BrandAppBarTitle('Kategorien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategorie'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCategories(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kategorien verwalten',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hier kannst du Kategorien hinzufügen, bearbeiten und deaktivieren.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!),
                ),
              )
            else if (_categories.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Noch keine Kategorien vorhanden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else ...[
              if (activeCategories.isNotEmpty) ...[
                const _SectionTitle('Aktive Kategorien'),
                const SizedBox(height: 10),
                ...activeCategories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CategoryTile(
                      category: category,
                      onTap: () => _openEditor(category: category),
                    ),
                  ),
                ),
              ],
              if (inactiveCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionTitle('Inaktive Kategorien'),
                const SizedBox(height: 10),
                ...inactiveCategories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CategoryTile(
                      category: category,
                      onTap: () => _openEditor(category: category),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.14),
          foregroundColor: category.color,
          child: Icon(category.iconData),
        ),
        title: Text(
          category.localizedName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${category.iconName} • ${category.colorHex}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!category.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Inaktiv'),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final Category? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final CategoryService _categoryService = CategoryService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late Color _selectedColor;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category?.localizedName ?? '',
    );
    _selectedIcon = widget.category?.iconName ?? Category.iconChoices.first.name;
    _selectedColor = widget.category?.color ?? Category.colorChoices.first;
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _categoryService.saveCategory(
        id: widget.category?.id,
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color:
            '#${(_selectedColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
        isActive: _isActive,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing ? 'Kategorie bearbeiten' : 'Kategorie hinzufügen'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.label_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte einen Namen eingeben.';
                    }
                    if (value.trim().length > 100) {
                      return 'Maximal 100 Zeichen.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    prefixIcon: Icon(Icons.apps_rounded),
                  ),
                  items: Category.iconChoices
                      .map(
                        (choice) => DropdownMenuItem<String>(
                          value: choice.name,
                          child: Row(
                            children: [
                              Icon(Category.iconForName(choice.name)),
                              const SizedBox(width: 10),
                              Text(choice.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedIcon = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktiv'),
                  subtitle: Text(
                    _isActive
                        ? 'Kategorie ist in Formularen sichtbar.'
                        : 'Kategorie wird für neue Ausgaben ausgeblendet.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Farbe',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: Category.colorChoices.map((color) {
                    final isSelected =
                        color.toARGB32() == _selectedColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.black87
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }
}


