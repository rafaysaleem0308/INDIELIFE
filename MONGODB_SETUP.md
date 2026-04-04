# 🗄️ MongoDB Setup Guide for IndieLife

## Problem

MongoDB data is not appearing in MongoDB Compass because the MongoDB service is not running against the local `mongo_data` folder.

## Solution

### Option 1: Using Provided Scripts (Recommended)

#### Windows (Batch File)

```
1. Open PowerShell or Command Prompt
2. Navigate to: D:\Semester 8\INDIELIFE-main\backend
3. Run: .\start-mongodb.bat
4. Keep this window open (MongoDB will be running)
```

#### Windows (PowerShell Script)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Navigate to backend folder
cd "D:\Semester 8\INDIELIFE-main\backend"
.\start-mongodb.ps1
```

### Option 2: Manual Command

Open PowerShell and run:

```powershell
mongod --dbpath "D:\Semester 8\INDIELIFE-main\backend\mongo_data" --port 27017
```

## ✅ Verify MongoDB is Running

1. **Check if MongoDB started successfully:**
   - You should see messages like:
   - `[initandlisten] waiting for connections on port 27017`
   - `[initandlisten] The server started successfully`

2. **Open MongoDB Compass:**
   - Connection String: `mongodb://localhost:27017`
   - Click Connect
   - You should now see:
     - Database: `IndieLife`
     - Collections: `users`, `orders`, `transactions`, `services`, etc.

## 🚀 Full Startup Sequence

Once MongoDB is running, in a **new terminal window**:

```powershell
# Terminal 1: MongoDB (keep running)
cd "D:\Semester 8\INDIELIFE-main\backend"
.\start-mongodb.bat

# Terminal 2: Backend Server
cd "D:\Semester 8\INDIELIFE-main\backend"
npm install  # if needed
node server.js

# Terminal 3: Frontend App
cd "D:\Semester 8\INDIELIFE-main"
flutter run

# Terminal 4: Admin Panel (optional)
cd "D:\Semester 8\INDIELIFE-main\admin-panel"
npm run dev
```

## 🔧 Database Configuration

Your backend is already configured correctly:

**File:** `backend/.env`

```
MONGO_URI=mongodb://127.0.0.1:27017/IndieLife
PORT=3000
```

**File:** `backend/config/database.js`

```javascript
const MONGO_URI =
  process.env.MONGO_URI || "mongodb://127.0.0.1:27017/IndieLife";
```

## ✨ What Should Appear in MongoDB Compass

After running some operations (creating orders, users, etc.), you'll see:

- **collections:** (example data)
  - `users` - User profiles
  - `service_providers` - Service provider accounts
  - `orders` - Meal/Laundry orders
  - `housing_bookings` - Property bookings
  - `services` - Service listings
  - `payments` - Payment records
  - `transactions` - Transaction history
  - And more...

## ⚠️ Troubleshooting

### "mongod: command not found"

- **Solution:** MongoDB is not installed or not in PATH
- **Fix:** [Download MongoDB Community Edition](https://www.mongodb.com/try/download/community)
- **Windows:** Choose `.msi` installer and follow the installation wizard
- **Add to PATH:** After installation, verify: `mongod --version`

### Database already in use

- **Solution:** MongoDB is already running (from before)
- **Fix:** Open Task Manager → Search for `mongod` → End Task
- **Then:** Run the startup script again

### Permission denied on `mongo_data`

- **Solution:** Folder permissions issue
- **Fix:** Right-click `mongo_data` → Properties → Security → Edit → Select "Users" → Check "Full Control"

### Compass shows empty collections

- **Solution:** You need to create data through the app
- **Steps:**
  1. Start the backend (`node server.js`)
  2. Create orders/bookings in the app
  3. Refresh MongoDB Compass to see new data

## 📊 Expected Workflow

```
User Action → Flutter Frontend → Backend API → MongoDB (via Mongoose)
                                                      ↓
                                    Fresh data appears in MongoDB Compass
```

---

**Your setup is now ready!** Keep MongoDB running in the background and all data will be persistently stored in the `mongo_data` folder and visible in MongoDB Compass.
