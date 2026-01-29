/**
 * Simple Node.js + Express application with PostgreSQL
 * Purpose:
 * - minimal demo app for ECS + Fargate
 * - responds on HTTP
 * - connects to RDS PostgreSQL
 * - suitable behind an Application Load Balancer
 */

const express = require('express');
const { Pool } = require('pg');
const app = express();

// ---- CONFIG ----
const PORT = 8080;
const HOST = '0.0.0.0'; // IMPORTANT: required for ECS / Docker

// Database configuration from environment variables
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 5432,
  ssl: {
    rejectUnauthorized: false // For RDS, we can use this for simplicity
  }
});

// ---- MIDDLEWARE ----
// parse application/x-www-form-urlencoded
app.use(express.urlencoded({ extended: true }));

// ---- DATABASE SETUP ----
async function initDatabase() {
  try {
    // Create users table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✅ Database initialized');
  } catch (err) {
    console.error('❌ Database initialization failed:', err.message);
  }
}

// ---- ROUTES ----

// Health check endpoint (ALB can call this)
app.get('/', async (req, res) => {
  let dbStatus = 'Unknown';
  let userCount = 0;
  
  try {
    const result = await pool.query('SELECT COUNT(*) FROM users');
    userCount = result.rows[0].count;
    dbStatus = 'Connected';
  } catch (err) {
    dbStatus = `Error: ${err.message}`;
  }

  res.send(`
    <html>
      <head>
        <title>ECS Fargate Lab</title>
      </head>
      <body>
        <h1>✅ ECS Fargate Lab</h1>
        <p>Application is running.</p>
        <p><strong>Database Status:</strong> ${dbStatus}</p>
        <p><strong>Total Users:</strong> ${userCount}</p>

        <form method="POST" action="/register">
          <h3>Register New User</h3>
          <label>
            Username:
            <input type="text" name="username" required />
          </label>
          <br /><br />
          <button type="submit">Register</button>
        </form>
        
        <hr>
        <h3>All Users</h3>
        <a href="/users">View All Users</a>
      </body>
    </html>
  `);
});

// Register new user
app.post('/register', async (req, res) => {
  const { username } = req.body;
  
  try {
    await pool.query('INSERT INTO users (username) VALUES ($1)', [username]);
    res.send(`
      <h2>✅ User "${username}" registered successfully!</h2>
      <a href="/">Back to Home</a>
    `);
  } catch (err) {
    res.send(`
      <h2>❌ Registration failed</h2>
      <p>Error: ${err.message}</p>
      <a href="/">Back to Home</a>
    `);
  }
});

// List all users
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY created_at DESC');
    const users = result.rows;
    
    let userList = users.map(user => 
      `<li>${user.username} (ID: ${user.id}, Created: ${user.created_at})</li>`
    ).join('');
    
    res.send(`
      <html>
        <head><title>All Users</title></head>
        <body>
          <h1>All Users (${users.length})</h1>
          <ul>${userList || '<li>No users found</li>'}</ul>
          <a href="/">Back to Home</a>
        </body>
      </html>
    `);
  } catch (err) {
    res.send(`
      <h2>❌ Failed to load users</h2>
      <p>Error: ${err.message}</p>
      <a href="/">Back to Home</a>
    `);
  }
});

// ---- START SERVER ----
app.listen(PORT, HOST, async () => {
  console.log(`🚀 Server running on http://${HOST}:${PORT}`);
  await initDatabase();
});
