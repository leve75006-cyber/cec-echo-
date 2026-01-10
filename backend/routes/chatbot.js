const express = require('express');
const router = express.Router();
const { getChatbotResponse, getChatbotInfo, getAdvancedChatbotResponse, getOpenAIChatbotResponse } = require('../controllers/chatbotController');
const { protect } = require('../middleware/auth');

// Public route for chatbot info
router.route('/info')
  .get(getChatbotInfo);

// Protected routes for actual chatbot queries
router.use(protect);

router.route('/query')
  .post(getChatbotResponse);

router.route('/advanced-query')
  .post(getAdvancedChatbotResponse);

router.route('/openai-query')
  .post(getOpenAIChatbotResponse);

module.exports = router;