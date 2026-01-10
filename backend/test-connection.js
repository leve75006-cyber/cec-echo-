const mongoose = require('mongoose');
const OpenAI = require('openai');

// Load environment variables
require('dotenv').config();

async function testConnections() {
  console.log('Testing connections...\n');
  
  // Test MongoDB connection
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ MongoDB connection successful');
    await mongoose.connection.close();
    console.log('MongoDB connection closed\n');
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
  }
  
  // Test OpenRouter connection (using OpenAI library with custom base URL)
  try {
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      baseURL: 'https://openrouter.ai/api/v1',
    });
    
    // Make a simple test request
    const completion = await openai.chat.completions.create({
      model: "openai/gpt-3.5-turbo",  // OpenRouter format
      messages: [{ role: "user", content: "Hello, are you working?" }],
      max_tokens: 10,
      temperature: 0
    });
    
    console.log('✅ OpenRouter connection successful');
    console.log('Test response:', completion.choices[0].message.content.trim(), '\n');
  } catch (error) {
    console.error('❌ OpenRouter connection failed:', error.message);
  }
  
  console.log('Connection testing completed!');
}

// Run the test
testConnections();