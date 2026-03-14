import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? category;
  final bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.isPinned = false,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    bool? isPinned,
  }) => Note(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    category: category ?? this.category,
    isPinned: isPinned ?? this.isPinned,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'category': category,
    'isPinned': isPinned,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    category: json['category'] as String?,
    isPinned: json['isPinned'] as bool? ?? false,
  );
}

class NotesListScreen extends StatefulWidget {
  final Function(bool)? onSelectionModeChanged;

  const NotesListScreen({super.key, this.onSelectionModeChanged});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _notes = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedNotes = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes');

    if (notesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(notesJson);
        setState(() {
          _notes = decoded.map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
          _sortNotes();
        });
      } catch (e) {
        debugPrint('Error loading notes: $e');
      }
    }
  }

  void _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('notes', encoded);
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  List<Note> _getFilteredNotes() {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((note) {
      return note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             note.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _addNote(Note note) {
    setState(() {
      _notes.add(note);
      _sortNotes();
    });
    _saveNotes();
  }

  void _updateNote(Note note) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
        _sortNotes();
      }
    });
    _saveNotes();
  }

  void _togglePinNote(String id) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
        _sortNotes();
      }
    });
    _saveNotes();
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((note) => note.id == id);
    });
    _saveNotes();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note deleted')),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedNotes.contains(id)) {
        _selectedNotes.remove(id);
      } else {
        _selectedNotes.add(id);
      }
      if (_selectedNotes.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _startSelection(String id) {
    setState(() {
      _selectedNotes.add(id);
      _isSelectionMode = true;
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _cancelSelection() {
    setState(() {
      _selectedNotes.clear();
      _isSelectionMode = false;
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _deleteSelectedNotes() {
    setState(() {
      for (final id in _selectedNotes) {
        _notes.removeWhere((note) => note.id == id);
      }
      _selectedNotes.clear();
      _isSelectionMode = false;
    });
    _saveNotes();
    widget.onSelectionModeChanged?.call(false);
  }

  void _openNoteEditor({Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          note: note,
          onSave: (updatedNote) {
            if (note == null) {
              _addNote(updatedNote);
            } else {
              _updateNote(updatedNote);
            }
          },
          onPin: note != null
              ? () {
                  _togglePinNote(note.id);
                  Navigator.pop(context);
                }
              : null,
          onDelete: note != null
              ? () {
                  _deleteNote(note.id);
                  Navigator.pop(context);
                }
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _getFilteredNotes();

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedNotes.length} item selected')
            : const Text('Notes'),
        centerTitle: true,
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _cancelSelection)
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelectedNotes),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          Expanded(
            child: filteredNotes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      return _NoteCard(
                        note: note,
                        isSelected: _selectedNotes.contains(note.id),
                        isSelectionMode: _isSelectionMode,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(note.id);
                          } else {
                            _openNoteEditor(note: note);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _startSelection(note.id);
                          }
                        },
                        onDelete: () => _deleteNote(note.id),
                        onTogglePin: () => _togglePinNote(note.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _openNoteEditor(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmptyState() {
    String message = _searchQuery.isNotEmpty
        ? 'No notes found'
        : 'No notes yet!\nTap + to add your first note';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onLongPress;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(note.id),
      direction: isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: isSelectionMode
              ? Checkbox(value: isSelected, onChanged: (_) => onTap())
              : note.isPinned
                  ? const Icon(Icons.push_pin, size: 20)
                  : null,
          title: Text(note.title.isEmpty ? 'Untitled' : note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
              ],
              const SizedBox(height: 4),
              Text(_formatDate(note.updatedAt), style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
          trailing: isSelectionMode
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    } else if (value == 'pin') {
                      onTogglePin();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(children: [
                        Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 20),
                        const SizedBox(width: 8),
                        Text(note.isPinned ? 'Unpin' : 'Pin'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ]),
                    ),
                  ],
                ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final Function(Note) onSave;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.onSave,
    this.onPin,
    this.onDelete,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
    _autoSave();
  }

  void _autoSave() {
    if (_isSaving) return;
    _isSaving = true;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _isSaving = false;
      if (_hasChanges) _saveNote(isAutoSave: true);
    });
  }

  void _saveNote({bool isAutoSave = false}) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (!isAutoSave) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a title or content')));
      }
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id ?? now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      category: widget.note?.category,
      isPinned: widget.note?.isPinned ?? false,
    );

    widget.onSave(note);
    
    if (!isAutoSave) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Note' : 'New Note'),
          actions: [
            if (isEditing && widget.note != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'pin') {
                    widget.onPin?.call();
                  } else if (value == 'delete') {
                    widget.onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(children: [
                      Icon(widget.note!.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 20),
                      const SizedBox(width: 8),
                      Text(widget.note!.isPinned ? 'Unpin' : 'Pin'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, size: 20),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ]),
                  ),
                ],
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Title', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(hintText: 'Note something down', border: OutlineInputBorder(), alignLabelWithHint: true),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
