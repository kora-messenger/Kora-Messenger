import express from 'express';
import cors from 'cors';
import config from './config.js';
import connectDB from './db.js';

import authRoutes from './routes/auth.js';
import chatRoutes from './routes/chat.js';
import pairRoutes from './routes/pair.js';
import lookupRoutes from './routes/lookup.js';
import aiRoutes from './routes/ai.js';
import callsRoutes from './routes/calls.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', app: config.appName, timestamp: new Date() });
});

// Route Mounting
app.use('/auth', authRoutes);
app.use('/chat', chatRoutes);
app.use('/pair', pairRoutes);
app.use('/lookup', lookupRoutes);
app.use('/ai', aiRoutes);
app.use('/calls', callsRoutes);

// Start Server & Connect Database
const startServer = async () => {
  if (process.env.NODE_ENV !== 'test') {
    await connectDB();
  }
  app.listen(config.port, () => {
    console.log(`[Server] ${config.appName} running on port ${config.port}`);
  });
};

startServer();

export default app;
