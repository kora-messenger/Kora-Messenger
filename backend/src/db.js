const mongoose = require('mongoose');

module.exports = async function connectDb() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is not set');
  const name = process.env.MONGODB_DB_NAME || 'kora';
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri, { dbName: name });
  console.log(`[db] connected to MongoDB (${name})`);
};
