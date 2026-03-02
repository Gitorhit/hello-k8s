// server.test.js — Tests using supertest (makes HTTP requests to our app
// without actually starting the server on a port).
//
// Think of this like: integration-testing your ECS service's endpoints
// locally before deploying.

const request = require('supertest');
const app = require('./server');

describe('GET /health', () => {
    // "it" describes a single test case.
    it('should return status ok', async () => {
        // supertest sends a GET request to /health and checks the response.
        const res = await request(app).get('/health');
        expect(res.statusCode).toBe(200);      // HTTP 200 = success
        expect(res.body.status).toBe('ok');     // Body should say "ok"
    });
});

describe('GET /hello', () => {
    it('should greet with default name', async () => {
        const res = await request(app).get('/hello');
        expect(res.body.message).toBe('Hello, World!');
    });

    it('should greet with custom name', async () => {
        const res = await request(app).get('/hello?name=Alice');
        expect(res.body.message).toBe('Hello, Alice!');
    });
});
