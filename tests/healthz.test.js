const request = require('supertest');
const app = require('../src/app');

describe('GET /healthz', () => {
  test('should return 200 with status ok', async () => {
    const response = await request(app).get('/healthz');
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
});
