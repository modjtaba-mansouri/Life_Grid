import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _storage = StorageService();
  bool _loading = true;
  List<DailyEntry> _entries = []; // newest first, note.isNotEmpty only

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _storage.loadAll();
    final withNotes = all.values.where((e) => e.note.trim().isNotEmpty).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      _entries = withNotes;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final existing = await _storage.loadEntry(date);
    if (!mounted) return;
    await _editNote(existing ?? DailyEntry(date: date));
  }

  Future<void> _editNote(DailyEntry entry) async {
    final controller = TextEditingController(text: entry.note);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          DateFormat('EEEE, MMM d, yyyy').format(entry.date),
          style: TextStyle(color: AppColors.text, fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          maxLines: 8,
          minLines: 4,
          autofocus: true,
          style: TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Write as much as you like…',
            hintStyle: TextStyle(color: AppColors.textDim),
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
            child: Text('Save', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _storage.saveEntry(entry.copyWith(note: result));
    _load();
  }

  Future<void> _deleteEntry(DailyEntry entry) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Remove this entry?', style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: Text(
          'You can just clear the journal note and keep that day\'s ratings, '
          'or erase the whole day\'s entry completely.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'note_only'),
            child: Text('Clear Note Only', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'erase_all'),
            child: Text('Erase Entire Day', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (choice == 'note_only') {
      await _storage.saveEntry(entry.copyWith(note: ''));
      _load();
    } else if (choice == 'erase_all') {
      await _storage.deleteEntry(entry.dateKey);
      _load();
    }
  }

  Future<void> _export() async {
    final buffer = StringBuffer();
    for (final entry in _entries) {
      buffer.writeln(DateFormat('EEEE, MMM d, yyyy').format(entry.date));
      buffer.writeln('-' * 24);
      buffer.writeln(entry.note.trim());
      buffer.writeln();
    }
    final text = buffer.toString();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Journal Exported', style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: Text(
          'Copied to your clipboard as plain text, entries separated by date. '
          'Paste it into any notes app, email, or document to save or share it.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Journal'),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, size: 20),
            onPressed: _entries.isEmpty ? null : _export,
            tooltip: 'Export',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: AppColors.accentSoft,
        foregroundColor: AppColors.accent,
        child: Icon(Icons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No journal entries yet. Write about any day — '
                          'at least a paragraph, or as much as you like.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDim, fontSize: 13),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _addEntry,
                          icon: Icon(Icons.add, size: 18),
                          label: Text('ADD ENTRY'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('EEEE, MMM d, yyyy').format(entry.date),
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.textDim),
                                      onPressed: () => _editNote(entry),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                    SizedBox(width: 16),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                      onPressed: () => _deleteEntry(entry),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              entry.note,
                              style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
