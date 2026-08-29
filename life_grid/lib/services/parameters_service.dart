import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_schema.dart';
import 'storage_service.dart';

enum TrackingMode { simple, precise }

/// Manages which categories/items are active, their display order, and
/// any custom ones the user has added. Scoped per logged-in user (kept
/// locally on-device for now — not yet synced across devices).
class ParametersService {
  String get _slug => StorageService.currentUser?.slug ?? 'guest';

  String get _modeKey => 'life_grid_mode_$_slug';
  String get _enabledCategoriesKey => 'life_grid_enabled_cats_$_slug';
  String get _enabledItemsKey => 'life_grid_enabled_items_$_slug'; // JSON: {catId: [itemIds]}
  String get _customCategoriesKey => 'life_grid_custom_cats_$_slug'; // JSON: [{id,label}]
  String get _customItemsKey => 'life_grid_custom_items_$_slug'; // JSON: {catId: [{id,label}]}
  String get _categoryOrderKey => 'life_grid_cat_order_$_slug'; // [catId,...]

  Future<TrackingMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey);
    return raw == 'precise' ? TrackingMode.precise : TrackingMode.simple;
  }

  Future<void> saveMode(TrackingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode == TrackingMode.precise ? 'precise' : 'simple');
  }

  Future<List<CategoryDef>> loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customCategoriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CategoryDef(
              e['id'],
              e['label'],
              isCustom: true,
              isStandalone: e['standalone'] as bool? ?? false,
            ))
        .toList();
  }

  /// [standalone] true = a flat single-rating item (like Today/Mood).
  /// [standalone] false = a category that can hold its own sub-items.
  Future<void> addCustomCategory(String label, {bool standalone = false}) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final existing = await loadCustomCategories();
    existing.add(CategoryDef(id, label, isCustom: true, isStandalone: standalone));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customCategoriesKey,
      jsonEncode(existing
          .map((c) => {'id': c.id, 'label': c.label, 'standalone': c.isStandalone})
          .toList()),
    );
    // New custom categories are enabled by default.
    final enabled = await loadEnabledCategories();
    enabled.add(id);
    await saveEnabledCategories(enabled);
  }

  Future<void> removeCustomCategory(String id) async {
    final existing = await loadCustomCategories();
    existing.removeWhere((c) => c.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customCategoriesKey,
      jsonEncode(existing
          .map((c) => {'id': c.id, 'label': c.label, 'standalone': c.isStandalone})
          .toList()),
    );
  }

  Future<Map<String, List<ItemDef>>> loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customItemsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((catId, items) => MapEntry(
          catId,
          (items as List<dynamic>).map((e) => ItemDef(e['id'], e['label'])).toList(),
        ));
  }

  Future<void> addCustomItem(String categoryId, String label) async {
    final id = 'custom_item_${DateTime.now().millisecondsSinceEpoch}';
    final all = await loadCustomItems();
    all.putIfAbsent(categoryId, () => []).add(ItemDef(id, label));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customItemsKey,
      jsonEncode(all.map((k, v) => MapEntry(k, v.map((i) => {'id': i.id, 'label': i.label}).toList()))),
    );
    final enabled = await loadEnabledItems(categoryId);
    enabled.add(id);
    await saveEnabledItems(categoryId, enabled);
  }

  Future<void> removeCustomItem(String categoryId, String itemId) async {
    final all = await loadCustomItems();
    all[categoryId]?.removeWhere((i) => i.id == itemId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customItemsKey,
      jsonEncode(all.map((k, v) => MapEntry(k, v.map((i) => {'id': i.id, 'label': i.label}).toList()))),
    );
  }

  /// All categories (built-in + custom), in saved display order.
  Future<List<CategoryDef>> allCategories() async {
    final custom = await loadCustomCategories();
    final all = [...kBuiltInCategories, ...custom];
    final order = await loadCategoryOrder();
    if (order.isEmpty) return all;
    final byId = {for (final c in all) c.id: c};
    final ordered = <CategoryDef>[];
    for (final id in order) {
      final c = byId.remove(id);
      if (c != null) ordered.add(c);
    }
    ordered.addAll(byId.values); // any new ones not yet in saved order
    return ordered;
  }

  /// All items for a category (built-in + custom), in saved order.
  Future<List<ItemDef>> allItems(CategoryDef cat) async {
    final custom = (await loadCustomItems())[cat.id] ?? [];
    return [...cat.items, ...custom];
  }

  Future<List<String>> loadCategoryOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_categoryOrderKey) ?? [];
  }

  Future<void> saveCategoryOrder(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoryOrderKey, ids);
  }

  Future<Set<String>> loadEnabledCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_enabledCategoriesKey);
    if (saved != null) return saved.toSet();
    // Default: every built-in category enabled.
    return kBuiltInCategories.map((c) => c.id).toSet();
  }

  Future<void> saveEnabledCategories(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledCategoriesKey, ids.toList());
  }

  Future<Set<String>> loadEnabledItems(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enabledItemsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded.containsKey(categoryId)) {
        return (decoded[categoryId] as List<dynamic>).map((e) => e as String).toSet();
      }
    }
    // Default: whichever items are marked defaultOn in the schema.
    final cat = kBuiltInCategories.where((c) => c.id == categoryId);
    if (cat.isEmpty) return {};
    return cat.first.items.where((i) => i.defaultOn).map((i) => i.id).toSet();
  }

  Future<void> saveEnabledItems(String categoryId, Set<String> itemIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enabledItemsKey);
    final decoded = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : <String, dynamic>{};
    decoded[categoryId] = itemIds.toList();
    await prefs.setString(_enabledItemsKey, jsonEncode(decoded));
  }
}
