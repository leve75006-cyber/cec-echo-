require('dotenv').config();
const OpenAI = require('openai');
const supabase = require('./config/supabase');

async function testConnections() {
  console.log('Testing connections...\n');

  try {
    const { data, error } = await supabase.from('users').select('id').limit(1);
    if (error) {
      throw error;
    }
    console.log('Supabase connection successful');
    console.log(`Supabase users probe rows: ${Array.isArray(data) ? data.length : 0}\n`);
  } catch (error) {
    console.error('Supabase connection failed:', error.message);
  }

  try {
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      baseURL: 'https://openrouter.ai/api/v1',
    });

    const completion = await openai.chat.completions.create({
      model: 'openai/gpt-3.5-turbo',
      messages: [{ role: 'user', content: 'Hello, are you working?' }],
      max_tokens: 10,
      temperature: 0,
    });

    console.log('OpenRouter connection successful');
    console.log('Test response:', completion.choices[0].message.content.trim(), '\n');
  } catch (error) {
    console.error('OpenRouter connection failed:', error.message);
  }

  console.log('Connection testing completed!');
}

testConnections();
