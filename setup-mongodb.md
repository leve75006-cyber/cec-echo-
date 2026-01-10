# Setting up MongoDB for Production

## Option 1: MongoDB Atlas (Recommended for Production)

1. **Sign up for MongoDB Atlas**
   - Go to [MongoDB Atlas](https://www.mongodb.com/atlas/database)
   - Create a free account

2. **Create a New Cluster**
   - Click "Build a Database"
   - Select "Free" tier (M0) for development
   - Choose a cloud provider and region closest to your users
   - Click "Create Cluster"

3. **Set up Database Access**
   - Go to "Database Access" tab
   - Click "Add New Database User"
   - Choose "Password" authentication method
   - Enter a username and strong password
   - Select "Custom Roles" -> "Read and Write to Any Database"
   - Click "Add User"

4. **Configure Network Access**
   - Go to "Network Access" tab
   - Click "Add IP Address"
   - For development: Add "0.0.0.0/0" to allow all connections
   - For production: Add specific IP addresses only

5. **Get Connection String**
   - Click "Connect" on your cluster
   - Choose "Connect your application"
   - Copy the connection string
   - Replace `<password>` with your database user password
   - Replace `<username>` with your database user username
   - Replace `<cluster-name>` with your cluster name

6. **Update Environment Variables**
   ```
   MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-name>.mongodb.net/cec-echo?retryWrites=true&w=majority
   ```

## Option 2: Self-hosted MongoDB

1. **Install MongoDB on your server**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install mongodb
   
   # CentOS/RHEL
   sudo yum install mongodb-server
   
   # Or use Docker
   docker run -d -p 27017:27017 --name mongodb mongo
   ```

2. **Configure MongoDB for remote access**
   - Edit `/etc/mongod.conf`
   - Change `bindIp` to allow external connections
   - Restart MongoDB service

3. **Create database and user**
   ```bash
   mongo
   use cec-echo
   db.createUser({
     user: "cec_user",
     pwd: "your_secure_password",
     roles: ["readWrite"]
   })
   ```

## Environment Configuration

Update your `.env` file:

```env
# For MongoDB Atlas
MONGODB_URI=mongodb+srv://username:password@cluster-name.mongodb.net/cec-echo?retryWrites=true&w=majority

# For self-hosted MongoDB
MONGODB_URI=mongodb://your-server-ip:27017/cec-echo

# Other settings remain the same
PORT=5000
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRE=7d
FRONTEND_URL=https://your-frontend-domain.com
NODE_ENV=production
```

## Connection Options for Production

In your `server.js`, you might want to add additional connection options:

```javascript
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  maxPoolSize: 10,          // Maintain up to 10 socket connections
  serverSelectionTimeoutMS: 5000, // Keep trying to send operations for 5 seconds
  socketTimeoutMS: 45000,   // Close sockets after 45 seconds of inactivity
  bufferCommands: false,    // Disable mongoose buffering
  bufferMaxEntries: 0       // Disable mongoose buffering
})
.then(() => console.log('Connected to MongoDB Atlas'))
.catch(err => console.error('Could not connect to MongoDB', err));
```

## Security Best Practices

1. **Use Strong Passwords**: Ensure your database user has a strong, unique password
2. **IP Whitelisting**: Only allow connections from your application servers
3. **Encryption**: Always use SSL/TLS for database connections
4. **Environment Variables**: Never hardcode database credentials in your code
5. **Regular Backups**: Enable automated backups in MongoDB Atlas
6. **Monitoring**: Enable monitoring and alerts for your database

## Troubleshooting

1. **Connection Issues**:
   - Verify your IP address is whitelisted
   - Check that your connection string is correct
   - Ensure your firewall allows outbound connections to MongoDB ports

2. **Performance Issues**:
   - Add indexes to frequently queried fields
   - Monitor slow queries
   - Consider upgrading your cluster tier if needed

3. **Authentication Issues**:
   - Verify username and password are correct
   - Check that the database user has appropriate permissions
   - Ensure the database name in the connection string matches your setup