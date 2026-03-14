import * as SQLite from 'expo-sqlite';

export type Priority = 'low' | 'medium' | 'high';

export interface Task {
  id: string;
  title: string;
  description?: string;
  isCompleted: boolean;
  createdAt: string;
  dueDate?: string;
  priority: Priority;
  category?: string;
}

export interface Note {
  id: string;
  title: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  category?: string;
  isPinned: boolean;
}

let db: SQLite.SQLiteDatabase | null = null;

async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (!db) {
    db = await SQLite.openDatabaseAsync('todo.db');
    await initDb();
  }
  return db;
}

async function initDb() {
  if (!db) return;
  
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      isCompleted INTEGER DEFAULT 0,
      createdAt TEXT NOT NULL,
      dueDate TEXT,
      priority TEXT DEFAULT 'medium',
      category TEXT
    );
    
    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      category TEXT,
      isPinned INTEGER DEFAULT 0
    );
  `);
}

export const Storage = {
  async getTasks(): Promise<Task[]> {
    try {
      const database = await getDb();
      const rows = await database.getAllAsync<any>('SELECT * FROM tasks ORDER BY createdAt DESC');
      return rows.map(row => ({
        ...row,
        isCompleted: Boolean(row.isCompleted),
      }));
    } catch (e) {
      console.error('Error loading tasks:', e);
      return [];
    }
  },

  async saveTasks(tasks: Task[]): Promise<void> {
    try {
      const database = await getDb();
      await database.execAsync('DELETE FROM tasks');
      for (const task of tasks) {
        await database.runAsync(
          'INSERT INTO tasks (id, title, description, isCompleted, createdAt, dueDate, priority, category) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [task.id, task.title, task.description || null, task.isCompleted ? 1 : 0, task.createdAt, task.dueDate || null, task.priority, task.category || null]
        );
      }
    } catch (e) {
      console.error('Error saving tasks:', e);
    }
  },

  async getNotes(): Promise<Note[]> {
    try {
      const database = await getDb();
      const rows = await database.getAllAsync<any>('SELECT * FROM notes ORDER BY isPinned DESC, updatedAt DESC');
      return rows.map(row => ({
        ...row,
        isPinned: Boolean(row.isPinned),
      }));
    } catch (e) {
      console.error('Error loading notes:', e);
      return [];
    }
  },

  async saveNotes(notes: Note[]): Promise<void> {
    try {
      const database = await getDb();
      await database.execAsync('DELETE FROM notes');
      for (const note of notes) {
        await database.runAsync(
          'INSERT INTO notes (id, title, content, createdAt, updatedAt, category, isPinned) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [note.id, note.title, note.content, note.createdAt, note.updatedAt, note.category || null, note.isPinned ? 1 : 0]
        );
      }
    } catch (e) {
      console.error('Error saving notes:', e);
    }
  },
};
