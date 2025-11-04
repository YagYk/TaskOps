/**
 * Todos API endpoint tests - happy path CRUD
 */
const request = require('supertest');
const app = require('../src/app');

describe('Todos API - CRUD operations', () => {
  let todoId;

  test('POST /api/todos - Create a todo', async () => {
    const response = await request(app)
      .post('/api/todos')
      .send({ text: 'Test todo' });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('id');
    expect(response.body.text).toBe('Test todo');
    expect(response.body.done).toBe(false);
    expect(response.body).toHaveProperty('createdAt');

    todoId = response.body.id;
  });

  test('GET /api/todos - Get all todos', async () => {
    const response = await request(app).get('/api/todos');

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
    expect(response.body.length).toBeGreaterThan(0);
  });

  test('GET /api/todos/:id - Get a todo by ID', async () => {
    const response = await request(app).get(`/api/todos/${todoId}`);

    expect(response.status).toBe(200);
    expect(response.body.id).toBe(todoId);
    expect(response.body.text).toBe('Test todo');
  });

  test('PUT /api/todos/:id - Update a todo', async () => {
    const response = await request(app)
      .put(`/api/todos/${todoId}`)
      .send({ done: true });

    expect(response.status).toBe(200);
    expect(response.body.done).toBe(true);
    expect(response.body.id).toBe(todoId);
  });

  test('DELETE /api/todos/:id - Delete a todo', async () => {
    const response = await request(app).delete(`/api/todos/${todoId}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message');

    // Verify deletion
    const getResponse = await request(app).get(`/api/todos/${todoId}`);
    expect(getResponse.status).toBe(404);
  });
});
