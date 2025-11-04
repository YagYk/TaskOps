/**
 * Todos controller - handles HTTP requests/responses
 */
const todosService = require('../services/todosService');

class TodosController {
  async getAll(req, res) {
    try {
      const todos = todosService.getAll();
      res.status(200).json(todos);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async getById(req, res) {
    try {
      const todo = todosService.getById(req.params.id);
      res.status(200).json(todo);
    } catch (error) {
      if (error.message === 'Todo not found') {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  }

  async create(req, res) {
    try {
      const { text } = req.body;

      if (!text) {
        return res.status(400).json({ error: 'Text field is required' });
      }

      const todo = todosService.create(text);
      res.status(201).json(todo);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async update(req, res) {
    try {
      const { text, done } = req.body;

      if (text === undefined && done === undefined) {
        return res.status(400).json({
          error: 'At least one field (text or done) must be provided',
        });
      }

      const updates = {};
      if (text !== undefined) updates.text = text;
      if (done !== undefined) updates.done = done;

      const todo = todosService.update(req.params.id, updates);
      res.status(200).json(todo);
    } catch (error) {
      if (error.message === 'Todo not found') {
        res.status(404).json({ error: error.message });
      } else {
        res.status(400).json({ error: error.message });
      }
    }
  }

  async delete(req, res) {
    try {
      const result = todosService.delete(req.params.id);
      res.status(200).json(result);
    } catch (error) {
      if (error.message === 'Todo not found') {
        res.status(404).json({ error: error.message });
      } else {
        res.status(500).json({ error: error.message });
      }
    }
  }
}

module.exports = new TodosController();
