/**
 * Metrics endpoint tests
 */
const request = require('supertest');
const app = require('../src/app');

describe('GET /metrics', () => {
  test('should return 200 and expose Prometheus metrics', async () => {
    // Make a request first to generate metrics
    await request(app).get('/healthz');

    const response = await request(app).get('/metrics');

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('text/plain');

    const metricsText = response.text;

    // Check for required metrics
    expect(metricsText).toContain('http_requests_total');
    expect(metricsText).toContain('http_request_duration_seconds');

    // Check for default metrics
    expect(metricsText).toMatch(/process_cpu_user_seconds_total|nodejs_/);
  });

  test('should increment http_requests_total on requests', async () => {
    // Make multiple requests
    await request(app).get('/healthz');
    await request(app).get('/healthz');

    const response = await request(app).get('/metrics');

    expect(response.status).toBe(200);
    // Should have at least 2 requests recorded
    expect(response.text).toContain('http_requests_total');
  });
});

