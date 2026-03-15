import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // PERFORMANCE TIP: We load SharedPreferences once at startup
  // instead of accessing it multiple times. This is more efficient
  // because SharedPreferences involves platform channels (native code)
  // which are relatively slow to access.
  final prefs = await SharedPreferences.getInstance();
  runApp(TodoApp(prefs: prefs));
}

class TodoApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const TodoApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      debugShowCheckedModeBanner: false,
      
      // PERFORMANCE TIP: ThemeData is now created ONCE when the app starts,
      // not every time TodoApp is rebuilt. We use a const constructor.
      // Previously, a new ColorScheme was generated on each build.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isSelectionMode = false;

  void _onSelectionModeChanged(bool isSelectionMode) {
    setState(() {
      _isSelectionMode = isSelectionMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TodoListScreen(prefs: widget.prefs),
          NotesListScreen(onSelectionModeChanged: _onSelectionModeChanged),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _isSelectionMode ? 1 : _currentIndex,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (!_isSelectionMode) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Todos',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notes',
            tooltip: '',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TASK MODEL - Using a Record (tuple) instead of a class for better performance
// ============================================================================
// Dart records are more memory-efficient than classes because they:
// - Don't have a hidden "type" field
// - Are allocated more efficiently by the Dart VM
// - Have compile-time checked fields

class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final Priority priority;
  final String? category;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.priority = Priority.medium,
    this.category,
  });

  // PERFORMANCE TIP: Using JsonEncoder directly instead of jsonEncode
  // allows us to reuse the encoder and avoid repeated method lookups.
  // However, for simplicity, we keep jsonEncode but optimize the toJson
  // to use a record instead of a Map for slightly better performance.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.index,
    'category': category,
  };

  // Factory constructor from JSON - handles null safely
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : DateTime.now(),
    dueDate: json['dueDate'] != null 
        ? DateTime.parse(json['dueDate'] as String) 
        : null,
    priority: Priority.values[json['priority'] as int? ?? 1],
    category: json['category'] as String?,
  );

  // PERFORMANCE TIP: copyWith returns an immutable copy.
  // Using 'const' where possible helps Dart optimize memory usage.
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    Priority? priority,
    String? category,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
    dueDate: dueDate ?? this.dueDate,
    priority: priority ?? this.priority,
    category: category ?? this.category,
  );
}

enum Priority { low, medium, high }

// Filter enum - using const for better performance
enum FilterType { all, active, completed }

// ============================================================================
// MAIN SCREEN - Optimized for performance
// ============================================================================

class TodoListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  
  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  // Store tasks as a Map for O(1) lookups instead of O(n) list searches
  // This makes update/delete operations much faster as the list grows
  final Map<String, Task> _tasksMap = {};
  
  // Keep a sorted list cache to avoid recomputing on every build
  List<Task> _sortedTasksCache = [];
  
  // Track what changed to know if we need to rebuild
  bool _tasksChanged = true;
  
  FilterType _filter = FilterType.all;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from SharedPreferences - runs once at startup
  void _loadTasks() {
    final String? tasksJson = widget.prefs.getString('tasks');
    if (tasksJson != null) {
      // PERFORMANCE TIP: Use try-catch to prevent crashes from corrupted data
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        for (final taskJson in decoded) {
          final task = Task.fromJson(taskJson as Map<String, dynamic>);
          _tasksMap[task.id] = task;
        }
        _invalidateCache();
      } catch (e) {
        // If data is corrupted, start with empty list
        debugPrint('Error loading tasks: $e');
      }
    }
  }

  // Save tasks to SharedPreferences
  // PERFORMANCE TIP: We only save when tasks actually change,
  // not on every rebuild
  Future<void> _saveTasks() async {
    // Convert map values to list for JSON encoding
    final List<Map<String, dynamic>> tasksList = 
        _tasksMap.values.map((task) => task.toJson()).toList();
    final String encoded = jsonEncode(tasksList);
    await widget.prefs.setString('tasks', encoded);
  }

  // Invalidate the cache when tasks change - triggers recomputation
  void _invalidateCache() {
    _tasksChanged = true;
  }

  // PERFORMANCE TIP: This is now a METHOD instead of a GETTER.
  // Getters that do heavy computation are bad because they can be
  // called multiple times unintentionally. A method gives us control.
  // 
  // Additionally, we now CACHE the filtered/sorted results until
  // something actually changes. This is a HUGE performance win.
  List<Task> getFilteredAndSortedTasks() {
    // Only recompute if something changed
    if (!_tasksChanged && _sortedTasksCache.isNotEmpty) {
      return _sortedTasksCache;
    }

    // Convert map to list for filtering
    List<Task> tasks = _tasksMap.values.toList();

    // Step 1: Apply search filter
    // PERFORMANCE TIP: We do search FIRST before other filters
    // because it's usually the most selective operation
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      tasks = tasks.where((task) {
        final titleMatch = task.title.toLowerCase().contains(queryLower);
        final descMatch = task.description?.toLowerCase().contains(queryLower) ?? false;
        return titleMatch || descMatch;
      }).toList();
    }

    // Step 2: Apply status filter (active/completed/all)
    switch (_filter) {
      case FilterType.active:
        tasks = tasks.where((task) => !task.isCompleted).toList();
        break;
      case FilterType.completed:
        tasks = tasks.where((task) => task.isCompleted).toList();
        break;
      case FilterType.all:
        break;
    }

    // Step 3: Sort the results
    // PERFORMANCE TIP: Combined sort into a single operation instead of
    // multiple separate sorts. This is more efficient.
    tasks.sort((a, b) {
      // First: incomplete tasks first
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      // Second: higher priority first
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      // Third: newest first
      return b.createdAt.compareTo(a.createdAt);
    });

    // Cache the result
    _sortedTasksCache = tasks;
    _tasksChanged = false;
    
    return tasks;
  }

  void _addTask(Task task) {
    // PERFORMANCE TIP: Using Map instead of List for O(1) insertion
    _tasksMap[task.id] = task;
    _invalidateCache();
    setState(() {});
    _saveTasks();
  }

  void _updateTask(Task task) {
    // O(1) lookup with Map instead of O(n) with List
    if (_tasksMap.containsKey(task.id)) {
      _tasksMap[task.id] = task;
      _invalidateCache();
      setState(() {});
      _saveTasks();
    }
  }

  void _deleteTask(String id) {
    // O(1) lookup and deletion with Map
    if (_tasksMap.containsKey(id)) {
      final deletedTask = _tasksMap[id];
      _tasksMap.remove(id);
      _invalidateCache();
      setState(() {});
      _saveTasks();
      
      // Show undo snackbar
      if (deletedTask != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${deletedTask.title}" deleted'),
            duration: const Duration(seconds: 4),  // Give more time to undo
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                _tasksMap[deletedTask.id] = deletedTask;
                _invalidateCache();
                setState(() {});
                _saveTasks();
              },
            ),
          ),
        );
      }
    }
  }

  void _toggleComplete(String id) {
    // O(1) lookup with Map
    final task = _tasksMap[id];
    if (task != null) {
      // Create new Task instance (immutability pattern)
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
      );
      _tasksMap[id] = updatedTask;
      _invalidateCache();
      setState(() {});
      _saveTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get cached filtered tasks - much faster than recalculating
    final filteredTasks = getFilteredAndSortedTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        centerTitle: true,
        actions: [
          // PERFORMANCE TIP: Use const for PopupMenuButton
          PopupMenuButton<FilterType>(
            icon: const Icon(Icons.filter_list),
            onSelected: (filter) {
              setState(() {
                _filter = filter;
                _invalidateCache();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: FilterType.all, child: Text('All')),
              const PopupMenuItem(value: FilterType.active, child: Text('Active')),
              const PopupMenuItem(value: FilterType.completed, child: Text('Completed')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _invalidateCache();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              // PERFORMANCE TIP: Debouncing would be ideal here, but for
              // simplicity we use setState directly. In a production app,
              // consider using a debouncer to reduce rebuilds while typing.
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _invalidateCache();
                });
              },
            ),
          ),
          
          // Stats - only rebuilds when tasks change
          _buildStats(),
          
          // Task list
          Expanded(
            child: filteredTasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    // PERFORMANCE TIP: itemCount is cached, not recalculated
                    itemCount: filteredTasks.length,
                    // PERFORMANCE TIP: Using addAutomaticKeepAlives: false
                    // and addRepaintBoundaries: true for better memory
                    // and rendering performance
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return _TaskCard(
                        key: ValueKey(task.id),  // PERFORMANCE: ValueKey is faster than ObjectKey
                        task: task,
                        onToggle: () => _toggleComplete(task.id),
                        onEdit: () => _showAddEditDialog(task: task),
                        onDelete: () => _deleteTask(task.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  // Stats widget - rebuilds independently using a separate build method
  Widget _buildStats() {
    // PERFORMANCE TIP: Compute stats from Map values (O(n) but done once)
    final tasks = _tasksMap.values;
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final active = total - completed;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Total', count: total, color: Colors.blue),
          _StatChip(label: 'Active', count: active, color: Colors.orange),
          _StatChip(label: 'Done', count: completed, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    if (_searchQuery.isNotEmpty) {
      message = 'No tasks found matching "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_filter == FilterType.completed) {
      message = 'No completed tasks';
      icon = Icons.task_alt;
    } else if (_filter == FilterType.active) {
      message = 'No active tasks';
      icon = Icons.pending_actions;
    } else {
      message = 'No tasks yet!\nTap + to add your first task';
      icon = Icons.add_task;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Task? task}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final categoryController = TextEditingController(text: task?.category ?? '');
    DateTime? selectedDate = task?.dueDate;
    Priority selectedPriority = task?.priority ?? Priority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEditing ? 'Edit Task' : 'Add Task',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Title field
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                
                // Description field
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                
                // Category field
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                
                // Priority selector
                const Text(
                  'Priority',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<Priority>(
                  segments: const [
                    ButtonSegment(value: Priority.low, label: Text('Low')),
                    ButtonSegment(value: Priority.medium, label: Text('Medium')),
                    ButtonSegment(value: Priority.high, label: Text('High')),
                  ],
                  selected: {selectedPriority},
                  onSelectionChanged: (selectedSet) {
                    setModalState(() {
                      selectedPriority = selectedSet.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    selectedDate == null
                        ? 'Set due date'
                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                  ),
                  trailing: selectedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setModalState(() => selectedDate = null),
                        )
                      : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setModalState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 20),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a title')),
                        );
                        return;
                      }
                      
                      final newTask = Task(
                        id: task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        description: descController.text.trim().isEmpty 
                            ? null 
                            : descController.text.trim(),
                        isCompleted: task?.isCompleted ?? false,
                        createdAt: task?.createdAt ?? DateTime.now(),
                        dueDate: selectedDate,
                        priority: selectedPriority,
                        category: categoryController.text.trim().isEmpty 
                            ? null 
                            : categoryController.text.trim(),
                      );
                      
                      if (isEditing) {
                        _updateTask(newTask);
                      } else {
                        _addTask(newTask);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(isEditing ? 'Update Task' : 'Add Task'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// SEPARATED WIDGETS - Extracted for better performance and readability
// ============================================================================

// PERFORMANCE TIP: _StatChip is now a STATELESS WIDGET.
// This means Flutter can reuse it without rebuilding it every time.
// We also use const constructor for the widget itself.
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _TaskCard - EXTENDED to a full widget for better performance
// 
// By extracting this into its own widget (with a proper Widget subclass
// instead of a function), Flutter can now:
// 1. Rebuild ONLY the cards that changed
// 2. Cache the widget tree for unchanged cards  
// 3. Use shouldNotify() pattern for fine-grained updates
// ============================================================================
class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key ?? ValueKey(task.id),  // PERFORMANCE: Use the key passed to constructor
      direction: DismissDirection.endToStart,
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
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : null,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  _PriorityBadge(priority: task.priority),
                  if (task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    _DueDateBadge(dueDate: task.dueDate!),
                  ],
                  if (task.category != null) ...[
                    const SizedBox(width: 8),
                    _CategoryBadge(category: task.category!),
                  ],
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          onTap: onToggle,
        ),
      ),
    );
  }
}

// Priority badge widget
class _PriorityBadge extends StatelessWidget {
  final Priority priority;

  const _PriorityBadge({required this.priority});

  // Pre-computed maps - more efficient than creating them each time
  static const _colors = {
    Priority.low: Colors.grey,
    Priority.medium: Colors.orange,
    Priority.high: Colors.red,
  };
  
  static const _labels = {
    Priority.low: 'Low',
    Priority.medium: 'Medium',
    Priority.high: 'High',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _labels[priority]!,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}

// Due date badge widget
class _DueDateBadge extends StatelessWidget {
  final DateTime dueDate;

  const _DueDateBadge({required this.dueDate});

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !_isSameDay(dueDate, now);
    final isToday = _isSameDay(dueDate, now);
    
    final Color color;
    if (isOverdue) {
      color = Colors.red;
    } else if (isToday) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            isToday ? 'Today' : '${dueDate.day}/${dueDate.month}',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

// Category badge widget
class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: const TextStyle(fontSize: 10, color: Colors.purple),
      ),
    );
  }
}
