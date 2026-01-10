# CEC ECHO - College Communication Platform

CEC ECHO is an intelligent communication platform designed to unify all college communications into a single, real-time ecosystem. The platform brings together students, faculty, and administration through a centralized system that replaces fragmented communication channels.

## Features

- **Unified Communication**: Replaces WhatsApp groups, emails, and notice boards with a single platform
- **Real-time Notifications**: Instant delivery of announcements and messages using Socket.io
- **Role-Based Access Control**: Secure access based on user roles (student, faculty, admin)
- **Announcement System**: Organized announcements with categories, priorities, and targeted audiences
- **Real-time Chat**: Direct messaging and group chats with multimedia support
- **WebRTC Integration**: Audio/video calls with STUN/TURN servers for NAT traversal
- **AI Chatbot**: Intelligent assistant for common queries with AI API integration
- **Mobile Application**: Cross-platform mobile app using Flutter

## Tech Stack

- **Backend**: Node.js with Express
- **Database**: MongoDB
- **Real-time Communication**: Socket.io
- **Authentication**: JWT
- **Frontend**: Flutter (Mobile Application)
- **WebRTC**: For audio/video calls
- **Security**: Helmet, CORS, Rate Limiting

## Architecture

The system is divided into three main modules:
1. **Admin Module**: For managing users and announcements
2. **Student Module**: For viewing updates and accessing repository
3. **Chatbot Module**: For handling routine queries automatically

## Setup Instructions

### Prerequisites

- Node.js (v14 or higher)
- MongoDB
- Flutter SDK
- Git

### Backend Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd CEC-ECHO/backend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the backend directory with the following content:
```env
PORT=5000
MONGODB_URI=mongodb://localhost:27017/cec-echo
JWT_SECRET=cec-echo-jwt-secret-key-change-in-production
JWT_EXPIRE=7d
FRONTEND_URL=http://localhost:3000
NODE_ENV=development

# WebRTC Configuration
STUN_SERVER=stun:stun.l.google.com:19302
TURN_SERVER=turn:your-turn-server.com:3478
TURN_USERNAME=your-turn-username
TURN_CREDENTIALS=your-turn-password
```

4. Start the backend server:
```bash
npm run dev
```

### Mobile App Setup

1. Navigate to the frontend directory:
```bash
cd ../frontend/cec_echo_mobile
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user profile
- `PUT /api/auth/password` - Update password

### Users (Admin only)
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get specific user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Announcements
- `GET /api/announcements` - Get all announcements
- `POST /api/announcements` - Create announcement
- `GET /api/announcements/:id` - Get specific announcement
- `PUT /api/announcements/:id` - Update announcement
- `DELETE /api/announcements/:id` - Delete announcement
- `PUT /api/announcements/like/:id` - Like announcement
- `POST /api/announcements/comment/:id` - Add comment

### Chat
- `GET /api/chat/messages` - Get all messages
- `POST /api/chat/messages` - Send message
- `GET /api/chat/messages/:userId` - Get messages with specific user
- `GET /api/chat/groups` - Get all groups
- `POST /api/chat/groups` - Create group
- `PUT /api/chat/groups/add-member/:id` - Add member to group

### Admin Dashboard
- `GET /api/admin/dashboard` - Get admin dashboard stats
- `GET /api/admin/users` - Get all users with pagination
- `GET /api/admin/announcements` - Get all announcements with filters

### Student Features
- `GET /api/student/announcements` - Get announcements for student
- `GET /api/student/dashboard` - Get student dashboard
- `GET /api/student/unread-count` - Get unread messages count

### Chatbot
- `POST /api/chatbot/query` - Get basic chatbot response
- `POST /api/chatbot/advanced-query` - Get advanced chatbot response
- `POST /api/chatbot/openai-query` - Get OpenAI-powered chatbot response
- `GET /api/chatbot/info` - Get chatbot info

## WebRTC Configuration

The platform supports various types of calls:
- Direct audio/video calls
- Group calls
- Broadcast calls (FM-style where one speaks, others listen)
- Hand raise functionality for broadcast calls
- Permission-based speaking in broadcast calls

## Security Features

- JWT-based authentication
- Role-based access control (RBAC)
- Input validation and sanitization
- Rate limiting to prevent abuse
- CORS configured for security
- Password hashing using bcrypt

## Database Models

1. **User Model**: Stores user information including role, department, etc.
2. **Announcement Model**: Stores announcements with metadata
3. **Message Model**: Handles direct and group messages
4. **Group Model**: Manages chat groups
5. **Call Model**: Tracks WebRTC calls

## Real-time Features

The platform uses Socket.io for real-time communication:
- Instant messaging
- Typing indicators
- Online/offline status
- Call signaling
- Broadcast notifications

## Mobile App Features

The Flutter app includes:
- User authentication
- Dashboard with quick access to features
- Announcement browsing
- Real-time chat
- Group management
- Profile management
- Push notifications

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For support, please contact the development team or raise an issue in the repository.