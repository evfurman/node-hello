'use strict';

const express = require('express');

const PORT = 3000;

// This is ok because we are running the service as a ClusterIp
const HOST = '0.0.0.0'; 

const app = express();

app.get('/', (req, res) => {
  res.send('hello world\n\nenvironment: development\n');
});

app.get('/healthz', (req, res) => {
  res.send('ping!\n');
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
