// server.js — A simple Express app with two endpoints.
//
// Express is a minimal Node.js web framework (like Spring Boot for Java,
// or Flask for Python). It handles HTTP routing for us.

const express = require('express');

// Create an Express application instance.
// Think of this as: "I'm building a web server."
const app = express();

// Define the port. process.env.PORT lets us override it
// via environment variables (useful in containers & K8s ConfigMaps).
const port = process.env.PORT || 8080;

// GET /health — A health check endpoint.
// In ECS, you set health check paths in your Task Definition.
// In Kubernetes, you'll configure "liveness probes" that hit this endpoint
// to know if your container is alive.
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// GET /hello — A greeting endpoint.
// Query parameter "name" defaults to "World" if not provided.
// Example: /hello?name=Alice → { "message": "Hello, Alice!" }
app.get('/hello', (req, res) => {
  const name = req.query.name || 'World';
  res.json({ message: `Hello, ${name}!` });
});

// Only start the server if this file is run directly (not imported by tests).
// This prevents the server from binding to a port during testing,
// which would cause "port already in use" errors.
if (require.main === module) {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

// Export the app so our tests can import it without starting the server.
module.exports = app;
