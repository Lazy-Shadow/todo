import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: TodoListScreen(prefs: prefs),
    );
  }
}

class Task {
  String id;
  String title;
  String? description;
  bool isCompleted;
  DateTime createdAt;
  DateTime? dueDate;
  Priority priority;
  String? category;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.dueDate,
    this.priority = Priority.medium,
    this.category,
  });

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

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        isCompleted: json['isCompleted'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        priority: Priority.values[json['priority'] ?? 1],
        category: json['category'],
      );

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    Priority? priority,
    String? category,
  }) =>
      Task(
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

class TodoListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const TodoListScreen({super.key, required this.prefs});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Task> _tasks = [];
  FilterType _filter = FilterType.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final String? tasksJson = widget.prefs.getString('tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((e) => Task.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final String encoded = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    await widget.prefs.setString('tasks', encoded);
  }

  List<Task> get _filteredTasks {
    var tasks = _tasks;
    if (_searchQuery.isNotEmpty) {
      tasks = tasks.where((t) =>
          t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    switch (_filter) {
      case FilterType.active:
        tasks = tasks.where((t) => !t.isCompleted).toList();
        break;
      case FilterType.completed:
        tasks = tasks.where((t) => t.isCompleted).toList();
        break;
      case FilterType.all:
        break;
    }
    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return tasks;
  }

  void _addTask(Task task) {
    setState(() {
      _tasks.add(task);
    });
    _saveTasks();
  }

  void _updateTask(Task task) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
      }
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final deletedTask = _tasks[taskIndex];
      setState(() {
        _tasks.removeAt(taskIndex);
      });
      _saveTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${deletedTask.title}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                _tasks.insert(taskIndex, deletedTask);
              });
              _saveTasks();
            },
          ),
        ),
      );
    }
  }

  void _toggleComplete(String id) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index].isCompleted = !_tasks[index].isCompleted;
      }
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          PopupMenuButton<FilterType>(
            icon: const Icon(Icons.filter_list),
            onSelected: (filter) => setState(() => _filter = filter),
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
          _buildStats(),
          Expanded(
            child: _filteredTasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      return _buildTaskCard(task);
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

  Widget _buildStats() {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.isCompleted).length;
    final active = total - completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('Total', total, Colors.blue),
          _statChip('Active', active, Colors.orange),
          _statChip('Done', completed, Colors.green),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color)),
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
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTask(task.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => _toggleComplete(task.id),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description?.isNotEmpty == true)
                Text(
                  task.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _priorityBadge(task.priority),
                  if (task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    _dueDateBadge(task.dueDate!),
                  ],
                  if (task.category != null) ...[
                    const SizedBox(width: 8),
                    _categoryBadge(task.category!),
                  ],
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showAddEditDialog(task: task),
          ),
          onTap: () => _toggleComplete(task.id),
        ),
      ),
    );
  }

  Widget _priorityBadge(Priority priority) {
    final colors = {Priority.low: Colors.grey, Priority.medium: Colors.orange, Priority.high: Colors.red};
    final labels = {Priority.low: 'Low', Priority.medium: 'Medium', Priority.high: 'High'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors[priority]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(labels[priority]!, style: TextStyle(fontSize: 10, color: colors[priority])),
    );
  }

  Widget _dueDateBadge(DateTime dueDate) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && !_isSameDay(dueDate, now);
    final isToday = _isSameDay(dueDate, now);
    final color = isOverdue ? Colors.red : (isToday ? Colors.orange : Colors.blue);
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

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(category, style: const TextStyle(fontSize: 10, color: Colors.purple)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Edit Task' : 'Add Task', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category (optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                ),
                const SizedBox(height: 16),
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<Priority>(
                  segments: const [
                    ButtonSegment(value: Priority.low, label: Text('Low')),
                    ButtonSegment(value: Priority.medium, label: Text('Medium')),
                    ButtonSegment(value: Priority.high, label: Text('High')),
                  ],
                  selected: {selectedPriority},
                  onSelectionChanged: (set) => setModalState(() => selectedPriority = set.first),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(selectedDate == null ? 'Set due date' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                  trailing: selectedDate != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setModalState(() => selectedDate = null)) : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) setModalState(() => selectedDate = date);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                        return;
                      }
                      final newTask = Task(
                        id: task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                        isCompleted: task?.isCompleted ?? false,
                        createdAt: task?.createdAt ?? DateTime.now(),
                        dueDate: selectedDate,
                        priority: selectedPriority,
                        category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
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

enum FilterType { all, active, completed }
