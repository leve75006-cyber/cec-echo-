# CEC ECHO Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Backend Deployment](#backend-deployment)
3. [Database Setup](#database-setup)
4. [Frontend Deployment](#frontend-deployment)
5. [Environment Configuration](#environment-configuration)
6. [Production Considerations](#production-considerations)

## Prerequisites

- Node.js v16+ installed on your system
- MongoDB (either local or cloud-based)
- Git installed
- A server or cloud platform account (Render, Railway, Heroku, etc.)

## Backend Deployment

### Option 1: Deploy to Render.com (Recommended)

1. **Create a Render Account**
   - Go to [Render](https://render.com)
   - Sign up using GitHub/GitLab account

2. **Prepare Your Repository**
   - Push your backend code to a GitHub repository
   - Ensure you have a `Procfile` in your backend directory:

   ```
   web: npm start
   ```

3. **Set Up Web Service**
   - On Render dashboard, click "New +" -> "Web Service"
   - Connect your GitHub repository
   - Choose your backend directory
   - Set environment variables (see Environment Configuration section)
   - Deploy!

### Option 2: Deploy to Railway

1. **Install Railway CLI**
   ```bash
   npm install -g @railway/cli
   ```

2. **Deploy via CLI**
   ```bash
   railway login
   railway init
   railway up
   ```

### Option 3: Deploy to Heroku

1. **Install Heroku CLI**
   ```bash
   # Download from https://devcenter.heroku.com/articles/heroku-cli
   ```

2. **Deploy**
   ```bash
   heroku create your-app-name
   heroku config:set NODE_ENV=production
   git push heroku main
   ```

## Database Setup

### MongoDB Atlas (Production Recommended)

1. **Create Free Cluster**
   - Visit [MongoDB Atlas](https://www.mongodb.com/atlas/database)
   - Create account and build cluster
   - Choose FREE tier (M0)

2. **Create Database User**
   - Go to Database Access
   - Add new user with read/write permissions

3. **Whitelist IP Addresses**
   - Add your application server IPs
   - For testing, temporarily add 0.0.0.0/0

4. **Get Connection String**
   - Click "Connect" on your cluster
   - Choose "Connect your application"
   - Copy the connection string

## Frontend Deployment

### For Flutter Mobile App

1. **Build Release Versions**

   **Android:**
   ```bash
   flutter build apk --release
   # Output: build/app/outputs/flutter-apk/app-release.apk

   # For app bundle (recommended for Play Store)
   flutter build appbundle --release
   # Output: build/app/outputs/bundle/release/app.aab
   ```

   **iOS:**
   ```bash
   flutter build ios --release
   # Requires Xcode and Apple Developer Account
   ```

2. **Publish to App Stores**
   - Google Play Console for Android
   - Apple App Store Connect for iOS

### For Web Version (Optional)

1. **Build Web App**
   ```bash
   flutter build web
   # Output: build/web
   ```

2. **Deploy Web App**
   - Upload build/web folder to any static hosting (Netlify, Vercel, GitHub Pages)
   - Or serve with a simple HTTP server

## Environment Configuration

Create these environment variables for your deployed backend:

```env
# Server Configuration
PORT=5000
NODE_ENV=production

# Database Configuration
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/cec-echo?retryWrites=true&w=majority

# Security Configuration
JWT_SECRET=your-super-secure-jwt-secret-key-change-in-production
JWT_EXPIRE=7d

# Frontend URL (for CORS)
FRONTEND_URL=https://your-mobile-app-or-web-client.com

# WebRTC Configuration
STUN_SERVER=stun:stun.l.google.com:19302
TURN_SERVER=turn:your-turn-server.com:3478
TURN_USERNAME=your-turn-username
TURN_CREDENTIALS=your-turn-password

# Email Configuration (if needed)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
```

## Production Considerations

### Security

1. **JWT Secret**
   - Use a strong, randomly generated secret
   - Store in environment variables only
   - Rotate periodically

2. **Database Security**
   - Use strong database passwords
   - Implement IP whitelisting
   - Enable encryption in transit

3. **API Security**
   - Implement rate limiting
   - Add input validation
   - Use HTTPS everywhere
   - Sanitize user inputs

### Performance

1. **Database Optimization**
   - Add indexes to frequently queried fields
   - Optimize queries
   - Use caching for frequently accessed data

2. **Server Optimization**
   - Enable gzip compression
   - Implement caching strategies
   - Monitor resource usage

3. **Image/Asset Optimization**
   - Compress images before upload
   - Use CDN for static assets

### Monitoring

1. **Application Logs**
   - Implement structured logging
   - Monitor error rates
   - Set up alerts for critical issues

2. **Database Monitoring**
   - Monitor query performance
   - Watch for connection pool exhaustion
   - Set up backup verification

### Scaling

1. **Horizontal Scaling**
   - Design for statelessness
   - Use external session storage
   - Implement load balancing

2. **Database Scaling**
   - Monitor database performance
   - Plan for cluster upgrades
   - Implement read replicas if needed

## Post-Deployment Steps

1. **Test All Features**
   - Verify user registration/login
   - Test real-time messaging
   - Confirm WebRTC functionality
   - Check AI chatbot responses

2. **Performance Testing**
   - Load test with realistic traffic
   - Monitor response times
   - Verify concurrent user capacity

3. **Security Audit**
   - Run vulnerability scans
   - Review authentication mechanisms
   - Test for common security issues

4. **Documentation**
   - Document deployment process
   - Create operational runbooks
   - Plan for disaster recovery

## Troubleshooting Common Issues

### Connection Problems
- Verify database connection string
- Check firewall settings
- Ensure proper network access

### Real-time Features Not Working
- Confirm WebSocket connections
- Verify Socket.io configuration
- Check CORS settings

### Mobile App Connection Issues
- Ensure proper API endpoints
- Verify SSL certificate validity
- Check network connectivity

## Maintenance

### Regular Tasks
- Monitor application logs
- Backup database regularly
- Update dependencies
- Apply security patches

### Monitoring Checklist
- Server uptime
- Database performance
- User activity metrics
- Error rates
- Resource utilization

This deployment guide will help you successfully deploy your CEC ECHO platform to production and ensure it runs smoothly for you and your friends to connect and communicate effectively.