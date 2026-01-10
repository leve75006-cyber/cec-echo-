const mongoose = require('mongoose');
require('dotenv').config();

console.log('Starting CEC ECHO Backend Server...');
console.log('Connecting to database...');

mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('✅ Database connected successfully');
    
    // Start the server after database connection
    const app = require('./server');
    const PORT = process.env.PORT || 5000;
    
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`🔗 Backend URL: http://localhost:${PORT}`);
      console.log(`💬 API endpoints available at: http://localhost:${PORT}/api`);
      console.log('\nPress Ctrl+C to stop the server');
    });
  })
  .catch(err => {
    console.error('❌ Database connection error:', err);
    process.exit(1);
  });