const { Message } = require('../models/Chat');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
});

// Simple Q&A dataset for college-related queries
const collegeQAData = {
  // General Queries
  "hello": "Hello! I'm Echo, your CEC ECHO assistant. How can I help you today?",
  "hi": "Hi there! I'm Echo, your CEC ECHO assistant. How can I help you today?",
  "help": "I can help you with information about courses, schedules, events, policies, and general college information. Just ask your question!",
  "thank you": "You're welcome! Is there anything else I can help you with?",
  "thanks": "You're welcome! Feel free to ask if you have more questions.",
  
  // Academic Information
  "course": "Our college offers various undergraduate and postgraduate programs. For specific course details, please contact the academic office or check the official website.",
  "courses": "Our college offers various undergraduate and postgraduate programs. For specific course details, please contact the academic office or check the official website.",
  "program": "Our college offers various undergraduate and postgraduate programs. For specific program details, please contact the academic office or check the official website.",
  "programs": "Our college offers various undergraduate and postgraduate programs. For specific program details, please contact the academic office or check the official website.",
  "syllabus": "Syllabus information is available in the student portal. You can also contact your department head for specific syllabus details.",
  "timetable": "Class timetables are published on the college notice board and student portal. Contact your department for updates.",
  "exam": "Examination schedules are announced in advance. Please check the announcements section or contact the examination office.",
  "exams": "Examination schedules are announced in advance. Please check the announcements section or contact the examination office.",
  "results": "Results are typically published within 30 days of the exam completion. Check the student portal or contact the examination office.",
  
  // Administrative Information
  "fee": "Fee information is available in the student portal. For fee-related queries, please contact the finance office during working hours.",
  "fees": "Fee information is available in the student portal. For fee-related queries, please contact the finance office during working hours.",
  "payment": "Fee payments can be made online through the student portal or at the college counter. Check the payment deadlines to avoid late fees.",
  "library": "The college library is open from 8 AM to 8 PM on weekdays and 9 AM to 5 PM on Saturdays. It's closed on Sundays.",
  "library hours": "The college library is open from 8 AM to 8 PM on weekdays and 9 AM to 5 PM on Saturdays. It's closed on Sundays.",
  "timing": "College timings are from 9 AM to 5 PM on weekdays. Specific class timings vary by department.",
  "timings": "College timings are from 9 AM to 5 PM on weekdays. Specific class timings vary by department.",
  "office hours": "Administrative offices are open from 9 AM to 5 PM on weekdays.",
  
  // Events and Activities
  "events": "Upcoming events are announced in the announcements section. Check regularly for cultural, sports, and academic events.",
  "event": "Upcoming events are announced in the announcements section. Check regularly for cultural, sports, and academic events.",
  "sports": "Our college has various sports facilities and teams. For sports-related activities, contact the sports coordinator.",
  "cultural": "We organize various cultural events throughout the year. Stay tuned to announcements for upcoming events.",
  "clubs": "Our college has multiple clubs and societies. You can join by contacting the respective club coordinators.",
  "activities": "We offer various extracurricular activities including clubs, societies, sports, and cultural events.",
  
  // Policies and Procedures
  "attendance": "Minimum attendance requirement is 75% for all courses. Regular attendance is important for academic success.",
  "leave": "Leave applications should be submitted to your department with proper justification and supporting documents.",
  "holiday": "Holiday lists are published at the beginning of each academic year. Check the official calendar for updates.",
  "holidays": "Holiday lists are published at the beginning of each academic year. Check the official calendar for updates.",
  "transfer": "Transfer procedures are handled by the academic office. Contact them with your specific requirements.",
  
  // Campus Facilities
  "hostel": "We have separate hostels for boys and girls with basic amenities. Contact the hostel office for accommodation details.",
  "cafeteria": "The college cafeteria operates during lunch hours from 12 PM to 2 PM. It offers various food options.",
  "transport": "College bus services are available for students. Route information is available at the transport office.",
  "wifi": "WiFi is available throughout the campus. Connect using your student credentials.",
  
  // Contact Information
  "contact": "For general inquiries, contact the reception. For academic matters, contact your department office.",
  "phone": "Main office phone number is available on the college website. Department-specific contacts are in the student handbook.",
  "email": "Official college email addresses follow the format [department]@college.edu.in. Check the website for specific contacts."
};

// Function to find best matching response
const findBestResponse = (input) => {
  const lowerInput = input.toLowerCase().trim();
  
  // Direct match first
  if (collegeQAData[lowerInput]) {
    return collegeQAData[lowerInput];
  }
  
  // Partial match with fuzzy matching
  const keys = Object.keys(collegeQAData);
  for (const key of keys) {
    if (lowerInput.includes(key) || key.includes(lowerInput.split(' ')[0])) {
      return collegeQAData[key];
    }
  }
  
  // More comprehensive phrase matching
  if (lowerInput.includes('deadline') || lowerInput.includes('last date') || lowerInput.includes('due')) {
    return "Important deadlines are mentioned in the announcements section. Please check regularly for updates.";
  }
  
  if (lowerInput.includes('principal') || lowerInput.includes('director') || lowerInput.includes('headmaster')) {
    return "For matters requiring the principal's attention, please submit a formal application through your department head.";
  }
  
  if (lowerInput.includes('complaint') || lowerInput.includes('issue') || lowerInput.includes('problem') || lowerInput.includes('grievance')) {
    return "For complaints or issues, please contact the student grievance cell or approach the administration office.";
  }
  
  if (lowerInput.includes('schedule') || lowerInput.includes('timetable') || lowerInput.includes('class time')) {
    return "Class schedules are available in the announcements section or on the student portal. Contact your department for specific timetable information.";
  }
  
  if (lowerInput.includes('result') || lowerInput.includes('grade') || lowerInput.includes('mark')) {
    return "Results are typically published within 30 days of the exam completion. Check the student portal or contact the examination office.";
  }
  
  if (lowerInput.includes('admission') || lowerInput.includes('enrollment')) {
    return "Admission information is available on the college website or at the admission office. Check the official admission brochure for requirements.";
  }
  
  if (lowerInput.includes('transport') || lowerInput.includes('bus') || lowerInput.includes('commute')) {
    return "College bus services are available for students. Route information is available at the transport office. Contact them for schedule details.";
  }
  
  if (lowerInput.includes('hostel') || lowerInput.includes('accommodation') || lowerInput.includes('lodging')) {
    return "We have separate hostels for boys and girls with basic amenities. Contact the hostel office for accommodation details and availability.";
  }
  
  // Default response
  return "I'm sorry, I couldn't understand your query. Please contact the appropriate department or check the announcements section for more information. You can also rephrase your question.";
};

// Function to calculate similarity for advanced matching
const calculateSimilarity = (str1, str2) => {
  const s1 = str1.toLowerCase().trim();
  const s2 = str2.toLowerCase().trim();
  
  // Simple word overlap similarity
  const words1 = s1.split(/\W+/);
  const words2 = s2.split(/\W+/);
  
  const intersection = words1.filter(word => words2.includes(word)).length;
  const union = [...new Set([...words1, ...words2])].length;
  
  return union === 0 ? 0 : intersection / union;
};

// Advanced Q&A function with similarity matching
const findBestResponseAdvanced = (input) => {
  const threshold = 0.3; // Minimum similarity threshold
  let bestMatch = null;
  let bestScore = 0;
  
  for (const [question, answer] of Object.entries(collegeQAData)) {
    const score = calculateSimilarity(input, question);
    if (score > bestScore && score >= threshold) {
      bestScore = score;
      bestMatch = answer;
    }
  }
  
  // If no good match found, try partial matching
  if (!bestMatch) {
    const keys = Object.keys(collegeQAData);
    for (const key of keys) {
      if (input.toLowerCase().includes(key) || key.includes(input.toLowerCase().split(' ')[0])) {
        return collegeQAData[key];
      }
    }
  }
  
  return bestMatch || "I'm sorry, I couldn't understand your query. Please contact the appropriate department or check the announcements section for more information. You can also rephrase your question.";
};

// @desc      Get chatbot response
// @route     POST /api/chatbot/query
// @access    Private
exports.getChatbotResponse = async (req, res) => {
  try {
    const { query } = req.body;
    
    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'Query is required'
      });
    }
    
    // Find the best response for the query
    const response = findBestResponse(query);
    
    // Optionally save the query-response pair for analytics
    // This would require creating a new model for chat logs
    
    res.status(200).json({
      success: true,
      data: {
        query,
        response,
        timestamp: new Date()
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get advanced chatbot response
// @route     POST /api/chatbot/advanced-query
// @access    Private
exports.getAdvancedChatbotResponse = async (req, res) => {
  try {
    const { query } = req.body;
    
    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'Query is required'
      });
    }
    
    // Find the best response for the query using advanced matching
    const response = findBestResponseAdvanced(query);
    
    res.status(200).json({
      success: true,
      data: {
        query,
        response,
        timestamp: new Date(),
        type: 'advanced'
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get OpenAI-powered chatbot response
// @route     POST /api/chatbot/openai-query
// @access    Private
exports.getOpenAIChatbotResponse = async (req, res) => {
  try {
    const { query } = req.body;
    
    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'Query is required'
      });
    }
    
    // Prepare the prompt for OpenAI
    const prompt = `You are a helpful assistant for CEC ECHO, a college communication platform. 
    The user has asked: "${query}". 
    Provide a helpful response related to college life, academics, administration, or the CEC ECHO platform itself. 
    Keep your response concise and informative.`;
    
    // Call OpenRouter API (compatible with OpenAI format)
    const completion = await openai.chat.completions.create({
      model: "openai/gpt-3.5-turbo",  // OpenRouter format
      messages: [
        { 
          role: "system", 
          content: "You are Echo, a helpful assistant for CEC ECHO, a college communication platform. Answer questions related to college life, academics, administration, and the platform features. Be concise and informative." 
        },
        { 
          role: "user", 
          content: query 
        }
      ],
      max_tokens: 200,
      temperature: 0.7
    });
    
    const response = completion.choices[0].message.content.trim();
    
    res.status(200).json({
      success: true,
      data: {
        query,
        response,
        timestamp: new Date(),
        type: 'openai'
      }
    });
  } catch (error) {
    console.error('OpenAI API Error:', error);
    
    // Fallback to local response if OpenRouter fails
    if (error.type === 'invalid_request_error' || error.status === 401) {
      return res.status(500).json({
        success: false,
        message: 'AI API configuration error. Please contact administrator.'
      });
    }
    
    // Try local response as fallback
    const fallbackResponse = findBestResponse(req.body.query || '');
    
    res.status(200).json({
      success: true,
      data: {
        query: req.body.query || '',
        response: fallbackResponse,
        timestamp: new Date(),
        type: 'fallback-local'
      }
    });
  }
};

// @desc      Get chatbot info
// @route     GET /api/chatbot/info
// @access    Public
exports.getChatbotInfo = async (req, res) => {
  try {
    res.status(200).json({
      success: true,
      data: {
        name: "Echo",
        version: "2.0",
        description: "Echo is an AI-powered chatbot to answer common queries related to college life, academics, and administration",
        capabilities: [
          "Answering frequently asked questions",
          "Providing information about courses and exams",
          "Sharing details about events and activities",
          "Giving information about college policies",
          "Directing to appropriate departments",
          "Powered by AI API for advanced responses"
        ]
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};