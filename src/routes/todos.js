/**
 * Todos API routes
 */
const express = require('express');
const router = express.Router();
const todosController = require('../controllers/todosController');

router.get('/', todosController.getAll.bind(todosController));
router.get('/:id', todosController.getById.bind(todosController));
router.post('/', todosController.create.bind(todosController));
router.put('/:id', todosController.update.bind(todosController));
router.delete('/:id', todosController.delete.bind(todosController));

module.exports = router;
