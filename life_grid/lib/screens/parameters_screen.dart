import 'package:flutter/material.dart';
import '../models/category_schema.dart';
import '../services/parameters_service.dart';
import '../theme/app_theme.dart';

class ParametersScreen extends StatefulWidget {
  const ParametersScreen({super.key});

  @override
  State<ParametersScreen> createState() => _ParametersScreenState();
}

class _ParametersScreenState extends State<ParametersScreen> {
  final _params = ParametersService();
  bool _loading = true;
  TrackingMode _mode = TrackingMode.simple;
  List<CategoryDef> _categories = [];
  Set<String> _enabledCategories = {};
  final Map<String, List<ItemDef>> _itemsByCategory = {};
  final Map<String, Set<String>> _enabledItemsByCategory = {};
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final mode = await _params.loadMode();
    final categories = await _params.allCategories();
    final enabledCategories = await _params.loadEnabledCategories();
    _itemsByCategory.clear();
    _enabledItemsByCategory.clear();
    for (final cat in categories) {
      if (cat.isSolo) continue;
      _itemsByCategory[cat.id] = await _params.allItems(cat);
      _enabledItemsByCategory[cat.id] = await _params.loadEnabledItems(cat.id);
    }
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _categories = categories;
      _enabledCategories = enabledCategories;
      _loading = false;
    });
  }

  Future<void> _setMode(TrackingMode mode) async {
    setState(() => _mode = mode);
    await _params.saveMode(mode);
  }

  Future<void> _toggleCategory(String id, bool value) async {
    setState(() {
      if (value) {
        _enabledCategories.add(id);
      } else {
        _enabledCategories.remove(id);
      }
    });
    await _params.saveEnabledCategories(_enabledCategories);
  }

  Future<void> _toggleItem(String catId, String itemId, bool value) async {
    final current = Set<String>.of(_enabledItemsByCategory[catId] ?? {});
    if (value) {
      current.add(itemId);
    } else {
      current.remove(itemId);
    }
    setState(() => _enabledItemsByCategory[catId] = current);
    await _params.saveEnabledItems(catId, current);
  }

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    await _params.saveCategoryOrder(_categories.map((c) => c.id).toList());
  }

  Future<void> _addCategory() async {
    final label = await _promptText('New category name');
    if (label == null || label.trim().isEmpty) return;
    await _params.addCustomCategory(label.trim());
    _load();
  }

  Future<void> _removeCategory(String id) async {
    await _params.removeCustomCategory(id);
    _load();
  }

  Future<void> _addItem(String categoryId) async {
    final label = await _promptText('New item name');
    if (label == null || label.trim().isEmpty) return;
    await _params.addCustomItem(categoryId, label.trim());
    _load();
  }

  Future<void> _removeItem(String categoryId, String itemId) async {
    await _params.removeCustomItem(categoryId, itemId);
    _load();
  }

  Future<String?> _promptText(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(title, style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parameters')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                Text('MODE', style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1)),
                SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Simple',
                            selected: _mode == TrackingMode.simple,
                            onTap: () => _setMode(TrackingMode.simple),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _ModeButton(
                            label: 'Precise',
                            selected: _mode == TrackingMode.precise,
                            onTap: () => _setMode(TrackingMode.precise),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CATEGORIES', style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1)),
                    TextButton.icon(
                      onPressed: _addCategory,
                      icon: Icon(Icons.add, size: 16, color: AppColors.accent),
                      label: Text('Add', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    ),
                  ],
                ),
                Text(
                  'Drag the handle to reorder. Tap a category with items to expand it.',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
                SizedBox(height: 8),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  onReorder: _reorderCategories,
                  children: [
                    for (final cat in _categories) _categoryTile(cat, key: ValueKey(cat.id)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _categoryTile(CategoryDef cat, {required Key key}) {
    final hasItems = !cat.isSolo;
    final expanded = _expanded.contains(cat.id);
    final items = _itemsByCategory[cat.id] ?? [];
    final enabledItems = _enabledItemsByCategory[cat.id] ?? {};

    return Card(
      key: key,
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: Checkbox(
              value: _enabledCategories.contains(cat.id),
              activeColor: AppColors.accent,
              onChanged: (v) => _toggleCategory(cat.id, v ?? true),
            ),
            title: Text(cat.label, style: TextStyle(fontSize: 13, color: AppColors.text)),
            onTap: hasItems ? () => setState(() => expanded ? _expanded.remove(cat.id) : _expanded.add(cat.id)) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cat.isCustom)
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    onPressed: () => _removeCategory(cat.id),
                  ),
                if (hasItems)
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textDim),
                Icon(Icons.drag_handle, color: AppColors.textDim, size: 18),
              ],
            ),
          ),
          if (hasItems && expanded)
            Padding(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Column(
                children: [
                  for (final item in items)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.label, style: TextStyle(fontSize: 12, color: AppColors.textDim)),
                      value: enabledItems.contains(item.id),
                      activeColor: AppColors.accent,
                      secondary: item.id.startsWith('custom_item_')
                          ? IconButton(
                              icon: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                              onPressed: () => _removeItem(cat.id, item.id),
                            )
                          : null,
                      onChanged: (v) => _toggleItem(cat.id, item.id, v ?? false),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addItem(cat.id),
                      icon: Icon(Icons.add, size: 14, color: AppColors.accent),
                      label: Text('Add item', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.bg,
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.accent : AppColors.textDim,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
