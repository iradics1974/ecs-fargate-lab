const express = require("express");
const app = express();

const PORT = 8080;

app.get("/", (req, res) => {
  res.send("Login app – step 1");
});

app.get("/health", (req, res) => {
  res.send("ok");
});

app.listen(PORT, () => {
  console.log(`Listening on port ${PORT}`);
});
