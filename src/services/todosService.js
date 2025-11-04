/**
 * Todo service - in-memory storage
 */
class TodosService {
  constructor() {
    this.todos = [];
    this.nextId = 1;
  }

  getAll() {
    return [...this.todos];
  }

  getById(id) {
    const todo = this.todos.find((t) => t.id === parseInt(id, 10));
    if (!todo) {
      throw new Error('Todo not found');
    }
    return todo;
  }

  create(text) {
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      throw new Error('Text is required and must be a non-empty string');
    }

    const todo = {
      id: this.nextId++,
      text: text.trim(),
      done: false,
      createdAt: new Date().toISOString(),
    };

    this.todos.push(todo);
    return todo;
  }

  update(id, updates) {
    const todo = this.getById(id);

    if (updates.text !== undefined) {
      if (typeof updates.text !== 'string' || updates.text.trim().length === 0) {
        throw new Error('Text must be a non-empty string');
      }
      todo.text = updates.text.trim();
    }

    if (updates.done !== undefined) {
      if (typeof updates.done !== 'boolean') {
        throw new Error('Done must be a boolean');
      }
      todo.done = updates.done;
    }

    return todo;
  }

  delete(id) {
    const index = this.todos.findIndex((t) => t.id === parseInt(id, 10));
    if (index === -1) {
      throw new Error('Todo not found');
    }

    this.todos.splice(index, 1);
    return { message: 'Todo deleted successfully' };
  }
}

module.exports = new TodosService();
