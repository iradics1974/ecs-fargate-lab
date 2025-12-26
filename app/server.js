/**
 * Simple Node.js + Express application
 * Purpose:
 * - minimal demo app for ECS + Fargate
 * - responds on HTTP
 * - suitable behind an Application Load Balancer
 */

const express = require('express');
const app = express();

// ---- CONFIG ----
const PORT = 8080;
const HOST = '0.0.0.0'; // IMPORTANT: required for ECS / Docker

// ---- MIDDLEWARE ----
// parse application/x-www-form-urlencoded
app.use(express.urlencoded({ extended: true }));

// ---- ROUTES ----

// Health check endpoint (ALB can call this)
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>ECS Fargate Lab</title>
      </head>
      <body>
        <h1>✅ ECS Fargate Lab</h1>
        <p>Application is running.</p>

        <form method="POST" action="/login">
          <label>
            Username:
            <input type="text" name="username" />
          </label>
          <br /><br />
          <label>
            Password:
            <input type="password" name="password" />
          </label>
          <br /><br />
          <button type="submit">Login</button>
        </form>
      </body>
    </html>
  `);
});

// Dummy login handler (NO DB, NO AUTH — lab only)
app.post('/login', (req, res) => {
  const { username } = req.body;

  res.send(`
    <h2>Hello ${username || 'anonymous'} 👋</h2>
    <p>This is a demo login page.</p>
    <p>No authentication is implemented.</p>
    <a href="/">Back</a>
  `);
});

// ---- START SERVER ----
app.listen(PORT, HOST, () => {
  console.log(`🚀 Server running on http://${HOST}:${PORT}`);
});
