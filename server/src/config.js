import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  mongodbUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/kora_messenger',
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.EMAIL_FROM || 'Kora Messenger <noreply@example.com>',
  },
  jwtSecret: process.env.JWT_SECRET || 'default_secret_key',
  openRouterApiKey: process.env.OPENROUTER_API_KEY || '',
  appName: process.env.APP_NAME || 'Kora Messenger',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:5173',
};

export default config;
