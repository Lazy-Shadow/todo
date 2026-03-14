import { useState, useEffect, useCallback, useMemo } from 'react';
import { View, Text, TextInput, FlatList, TouchableOpacity, Modal, StyleSheet, Alert } from 'react-native';
import { Storage, Task, Priority } from '../types';
import { Ionicons } from '@expo/vector-icons';
import DateTimePicker from '@react-native-community/datetimepicker';

const PRIORITY_ORDER = { high: 0, medium: 1, low: 2 };

export default function TodoScreen() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all');
  const [modalVisible, setModalVisible] = useState(false);
  const [editingTask, setEditingTask] = useState<Task | null>(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [priority, setPriority] = useState<Priority>('medium');
  const [dueDate, setDueDate] = useState<Date | null>(null);
  const [showDatePicker, setShowDatePicker] = useState(false);

  useEffect(() => {
    loadTasks();
  }, []);

  const loadTasks = useCallback(async () => {
    const data = await Storage.getTasks();
    setTasks(data);
  }, []);

  const saveTasks = useCallback(async (newTasks: Task[]) => {
    setTasks(newTasks);
    await Storage.saveTasks(newTasks);
  }, []);

  const filteredTasks = useMemo(() => {
    return tasks
      .filter(task => {
        if (searchQuery) {
          const query = searchQuery.toLowerCase();
          if (!task.title.toLowerCase().includes(query) && 
              !task.description?.toLowerCase().includes(query)) {
            return false;
          }
        }
        if (filter === 'active') return !task.isCompleted;
        if (filter === 'completed') return task.isCompleted;
        return true;
      })
      .sort((a, b) => {
        if (a.isCompleted !== b.isCompleted) return a.isCompleted ? 1 : -1;
        if (PRIORITY_ORDER[a.priority] !== PRIORITY_ORDER[b.priority]) {
          return PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
        }
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
      });
  }, [tasks, searchQuery, filter]);

  const stats = useMemo(() => ({
    total: tasks.length,
    active: tasks.filter(t => !t.isCompleted).length,
    completed: tasks.filter(t => t.isCompleted).length,
  }), [tasks]);

  const openAddModal = useCallback(() => {
    setEditingTask(null);
    setTitle('');
    setDescription('');
    setCategory('');
    setPriority('medium');
    setDueDate(null);
    setModalVisible(true);
  }, []);

  const openEditModal = useCallback((task: Task) => {
    setEditingTask(task);
    setTitle(task.title);
    setDescription(task.description || '');
    setCategory(task.category || '');
    setPriority(task.priority);
    setDueDate(task.dueDate ? new Date(task.dueDate) : null);
    setModalVisible(true);
  }, []);

  const handleSave = useCallback(() => {
    if (!title.trim()) {
      Alert.alert('Error', 'Please enter a title');
      return;
    }

    const newTask: Task = {
      id: editingTask?.id || Date.now().toString(),
      title: title.trim(),
      description: description.trim() || undefined,
      category: category.trim() || undefined,
      priority,
      dueDate: dueDate?.toISOString(),
      isCompleted: editingTask?.isCompleted || false,
      createdAt: editingTask?.createdAt || new Date().toISOString(),
    };

    let newTasks: Task[];
    if (editingTask) {
      newTasks = tasks.map(t => t.id === editingTask.id ? newTask : t);
    } else {
      newTasks = [...tasks, newTask];
    }
    saveTasks(newTasks);
    setModalVisible(false);
  }, [title, description, category, priority, dueDate, editingTask, tasks, saveTasks]);

  const toggleComplete = (id: string) => {
    const newTasks = tasks.map(t => 
      t.id === id ? { ...t, isCompleted: !t.isCompleted } : t
    );
    saveTasks(newTasks);
  };

  const getPriorityColor = (p: Priority) => {
    switch (p) {
      case 'high': return '#ef4444';
      case 'medium': return '#f97316';
      case 'low': return '#6b7280';
    }
  };

  const getDueDateInfo = (dateStr?: string) => {
    if (!dateStr) return null;
    const date = new Date(dateStr);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    const isOverdue = date < now && !isToday;
    return { date, isToday, isOverdue };
  };

  const renderTask = ({ item }: { item: Task }) => {
    const dueInfo = getDueDateInfo(item.dueDate);
    
    return (
      <TouchableOpacity 
        style={styles.taskCard}
        onPress={() => toggleComplete(item.id)}
        onLongPress={() => openEditModal(item)}
      >
        <View style={styles.taskContent}>
          <View style={[styles.checkbox, item.isCompleted && styles.checkboxCompleted]}>
            {item.isCompleted && <Ionicons name="checkmark" size={16} color="#fff" />}
          </View>
          <View style={styles.taskDetails}>
            <Text style={[styles.taskTitle, item.isCompleted && styles.completedText]}>
              {item.title}
            </Text>
            {item.description && (
              <Text style={styles.taskDescription} numberOfLines={1}>
                {item.description}
              </Text>
            )}
            <View style={styles.badges}>
              <View style={[styles.badge, { backgroundColor: getPriorityColor(item.priority) + '20' }]}>
                <Text style={[styles.badgeText, { color: getPriorityColor(item.priority) }]}>
                  {item.priority}
                </Text>
              </View>
              {dueInfo && (
                <View style={[styles.badge, { 
                  backgroundColor: dueInfo.isOverdue ? '#ef444420' : dueInfo.isToday ? '#f9731620' : '#3b82f620'
                }]}>
                  <Text style={[styles.badgeText, { 
                    color: dueInfo.isOverdue ? '#ef4444' : dueInfo.isToday ? '#f97316' : '#3b82f6'
                  }]}>
                    {dueInfo.isToday ? 'Today' : `${dueInfo.date.getDate()}/${dueInfo.date.getMonth() + 1}`}
                  </Text>
                </View>
              )}
              {item.category && (
                <View style={[styles.badge, { backgroundColor: '#9333ea20' }]}>
                  <Text style={[styles.badgeText, { color: '#9333ea' }]}>{item.category}</Text>
                </View>
              )}
            </View>
          </View>
          <TouchableOpacity onPress={() => openEditModal(item)} style={styles.editBtn}>
            <Ionicons name="pencil" size={20} color="#6b7280" />
          </TouchableOpacity>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Todo List</Text>
      </View>

      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search tasks..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
        <TouchableOpacity style={styles.filterBtn} onPress={() => {
          const filters: Array<'all' | 'active' | 'completed'> = ['all', 'active', 'completed'];
          const currentIndex = filters.indexOf(filter);
          setFilter(filters[(currentIndex + 1) % 3]);
        }}>
          <Ionicons name="filter" size={20} color="#6b7280" />
        </TouchableOpacity>
      </View>

      <View style={styles.statsContainer}>
        <View style={[styles.statChip, { backgroundColor: '#3b82f620' }]}>
          <Text style={[styles.statText, { color: '#3b82f6' }]}>{stats.total} Total</Text>
        </View>
        <View style={[styles.statChip, { backgroundColor: '#f9731620' }]}>
          <Text style={[styles.statText, { color: '#f97316' }]}>{stats.active} Active</Text>
        </View>
        <View style={[styles.statChip, { backgroundColor: '#22c55e20' }]}>
          <Text style={[styles.statText, { color: '#22c55e' }]}>{stats.completed} Done</Text>
        </View>
      </View>

      {filteredTasks.length === 0 ? (
        <View style={styles.emptyState}>
          <Ionicons name="clipboard-outline" size={64} color="#d1d5db" />
          <Text style={styles.emptyText}>
            {searchQuery ? 'No tasks found' : 'No tasks yet!\nTap + to add your first task'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredTasks}
          renderItem={renderTask}
          keyExtractor={item => item.id}
          contentContainerStyle={styles.list}
        />
      )}

      <TouchableOpacity style={styles.fab} onPress={openAddModal}>
        <Ionicons name="add" size={28} color="#fff" />
      </TouchableOpacity>

      <Modal visible={modalVisible} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {editingTask ? 'Edit Task' : 'Add Task'}
              </Text>
              <TouchableOpacity onPress={() => setModalVisible(false)}>
                <Ionicons name="close" size={24} color="#6b7280" />
              </TouchableOpacity>
            </View>

            <TextInput
              style={styles.input}
              placeholder="Title"
              value={title}
              onChangeText={setTitle}
            />

            <TextInput
              style={[styles.input, styles.multilineInput]}
              placeholder="Description (optional)"
              value={description}
              onChangeText={setDescription}
              multiline
            />

            <TextInput
              style={styles.input}
              placeholder="Category (optional)"
              value={category}
              onChangeText={setCategory}
            />

            <Text style={styles.label}>Priority</Text>
            <View style={styles.priorityButtons}>
              {(['low', 'medium', 'high'] as Priority[]).map((p) => (
                <TouchableOpacity
                  key={p}
                  style={[
                    styles.priorityBtn,
                    priority === p && { backgroundColor: getPriorityColor(p) + '20', borderColor: getPriorityColor(p) }
                  ]}
                  onPress={() => setPriority(p)}
                >
                  <Text style={[
                    styles.priorityBtnText,
                    priority === p && { color: getPriorityColor(p) }
                  ]}>
                    {p.charAt(0).toUpperCase() + p.slice(1)}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <TouchableOpacity 
              style={styles.dateBtn}
              onPress={() => setShowDatePicker(true)}
            >
              <Ionicons name="calendar-outline" size={20} color="#6b7280" />
              <Text style={styles.dateText}>
                {dueDate ? `${dueDate.getDate()}/${dueDate.getMonth() + 1}/${dueDate.getFullYear()}` : 'Set due date'}
              </Text>
              {dueDate && (
                <TouchableOpacity onPress={() => setDueDate(null)}>
                  <Ionicons name="close-circle" size={20} color="#6b7280" />
                </TouchableOpacity>
              )}
            </TouchableOpacity>

            {showDatePicker && (
              <DateTimePicker
                value={dueDate || new Date()}
                mode="date"
                onChange={(event, date) => {
                  setShowDatePicker(false);
                  if (date) setDueDate(date);
                }}
              />
            )}

            <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
              <Text style={styles.saveBtnText}>
                {editingTask ? 'Update Task' : 'Add Task'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f9fafb',
  },
  header: {
    paddingTop: 60,
    paddingBottom: 16,
    paddingHorizontal: 20,
    backgroundColor: '#fff',
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#111827',
  },
  searchContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 8,
  },
  searchInput: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
  },
  filterBtn: {
    backgroundColor: '#fff',
    borderRadius: 12,
    paddingHorizontal: 16,
    justifyContent: 'center',
  },
  statsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingBottom: 12,
    gap: 8,
  },
  statChip: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  statText: {
    fontWeight: '600',
  },
  list: {
    paddingHorizontal: 16,
    paddingBottom: 100,
  },
  taskCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    marginBottom: 8,
    padding: 12,
  },
  taskContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: '#d1d5db',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  checkboxCompleted: {
    backgroundColor: '#22c55e',
    borderColor: '#22c55e',
  },
  taskDetails: {
    flex: 1,
  },
  taskTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#111827',
  },
  completedText: {
    textDecorationLine: 'line-through',
    color: '#9ca3af',
  },
  taskDescription: {
    fontSize: 14,
    color: '#6b7280',
    marginTop: 2,
  },
  badges: {
    flexDirection: 'row',
    marginTop: 8,
    gap: 8,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  badgeText: {
    fontSize: 10,
    fontWeight: '600',
  },
  editBtn: {
    padding: 8,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    marginTop: 16,
    fontSize: 16,
    color: '#6b7280',
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    backgroundColor: '#7c3aed',
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  modalTitle: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  input: {
    backgroundColor: '#f3f4f6',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    marginBottom: 12,
  },
  multilineInput: {
    minHeight: 60,
    textAlignVertical: 'top',
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  priorityButtons: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 12,
  },
  priorityBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e5e7eb',
    alignItems: 'center',
  },
  priorityBtnText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#6b7280',
  },
  dateBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f3f4f6',
    borderRadius: 8,
    padding: 12,
    marginBottom: 16,
    gap: 8,
  },
  dateText: {
    flex: 1,
    fontSize: 16,
    color: '#6b7280',
  },
  saveBtn: {
    backgroundColor: '#7c3aed',
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
  },
  saveBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
