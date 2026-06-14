# 🚀 QUICK START GUIDE - AI Budget Recommendation

## 🎉 Migration Update

The AI Expense Planner has been **successfully migrated from web (index.html) to Flutter mobile application**!

### 📱 New Location

- **Flutter App**: `INDIELIFE-main/lib/features/home/screens/ai_budget_recommendation.dart`
- **Service Layer**: `INDIELIFE-main/lib/core/services/ai_budget_service.dart`
- **Backend API**: Still running on Flask at `http://localhost:5000/api/`

---

## 🚀 Running the AI Feature with Flutter

### **Step 1: Start the Flask Backend**

```bash
# Navigate to the AI model folder (Updated for your current path)
cd "d:\WORK DATA\Semester 8\Indielife\Ai model fyp"

# Activate virtual environment
.venv\Scripts\activate

# Start Flask server
python app.py
```

**Expected Output:**

```
✅ AI Expense Planner API is running
🌐 Starting server on http://localhost:5000
📊 Available Endpoints:
  - GET  /api/health
  - GET  /api/datasets
  - POST /api/ai-budget-recommendation
  - ... (other endpoints)
```

### **Step 2: Run Flutter Application**

```bash
# Navigate to Flutter project (Updated for your current path)
cd "d:\WORK DATA\Semester 8\Indielife\INDIELIFE-main"

# Run the app
flutter run
```

### **Step 3: Access AI Budget Recommendation**

1. **Login** to the Flutter app
2. **Navigate** to User Home Screen
3. **Look for** the purple "🤖 AI Budget Recommendation" card
4. **Tap** the card to open the AI Assistant

---

## 🎯 How to Use AI Budget Recommendation in Flutter

### **Input Example 1: Meal Planning**

```
1. Select Category: 🍱 Meals
2. Budget: 5000 (PKR)
3. Duration: 14 (Days)
4. Tap: "Get AI Recommendation"
```

**Result:**

- ✅ 14-day meal plan
- 📊 Daily budget: Rs 357
- 📈 Breakdown of recommended items
- 💡 Smart tips for saving money
- 🎯 Budget efficiency score

### **Input Example 2: Laundry Management**

```
1. Select Category: 🧺 Laundry
2. Budget: 3000 (PKR)
3. Duration: 30 (Days)
4. Tap: "Get AI Recommendation"
```

### **Input Example 3: Maintenance Planning**

```
1. Select Category: 🔧 Maintenance
2. Budget: 2000 (PKR)
3. Duration: 7 (Days)
4. Tap: "Get AI Recommendation"
```

---

## 📊 Features in Flutter App

### **AI Analysis Provides:**

✅ **Smart Budget Plan**

- Daily spending breakdown
- Item recommendations per day
- Total allocation tracking

✅ **AI Recommendations**

- Budget alerts
- Category-specific tips
- Optimization suggestions

✅ **Budget Insights**

- Budget efficiency percentage
- Average item pricing
- Potential savings calculation
- Item availability count

✅ **Daily Breakdown**

- Day-by-day spending plan
- Recommended items per day
- Running totals

---

## 🔌 API Endpoints

The Flask backend provides these endpoints:

### **1. Health Check**

```
GET /api/health
```

### **2. AI Budget Recommendation (NEW - FOR FLUTTER)**

```
POST /api/ai-budget-recommendation

Body:
{
  "budget": 5000,
  "days": 14,
  "category": "meal"
}

Response:
{
  "success": true,
  "plan": { /* budget plan */ },
  "recommendations": [ /* AI tips */ ],
  "insights": { /* statistics */ },
  "statistics": { /* pricing data */ }
}
```

### **3. Chat-Style Planning**

```
POST /api/chat-plan

Body:
{
  "text": "I have 3000 rupees for 2 weeks for meals"
}
```

### **4. Get Datasets**

```
GET /api/datasets
GET /api/datasets/<category>  # meal, laundry, maintenance
```

### **5. Statistics**

```
GET /api/stats
```

---

## 🛠️ Configuration

### **For Android Devices (Physical or Emulator)**

Edit `ai_budget_service.dart`:

```dart
if (Platform.isAndroid) {
  // Use 10.0.2.2 for Android Emulator, or your machine's IPv4 for physical devices
  return "http://10.0.2.2:5000";
}
```

### **For iOS Devices**

```dart
return "http://127.0.0.1:5000";  // iOS Simulator
```

---

## 📁 File Structure

```
Ai model fyp/
├── app.py                 # Flask API with new endpoint
├── model_trainer.py       # AI model training
├── trained_models/
│   └── trained_data.json  # Pre-trained weights
├── index.html             # Legacy web interface
├── requirements.txt       # Python dependencies
└── QUICK_START.md         # This file

INDIELIFE-main/
└── lib/
    ├── core/
    │   └── services/
    │       ├── ai_budget_service.dart      # NEW: Flutter AI Service
    │       └── api_service.dart
    └── features/
        └── home/
            ├── screens/
            │   ├── user_home.dart          # UPDATED: Added AI Card
            │   └── ai_budget_recommendation.dart  # NEW: AI Screen
```

---

## ✨ New Features in Flutter

### **What's New:**

- 🤖 **AI Assistant** - Intelligent budget planning
- 💾 **Mobile Native** - Better UI/UX with Material Design
- 📱 **Offline Support** - Cache recommendations
- 🔄 **Real-time Updates** - Live budget tracking
- 🎨 **Beautiful UI** - Animated cards and transitions
- 📊 **Better Visualization** - Charts and detailed breakdowns

---

## 🐛 Troubleshooting

### **Issue: "Cannot connect to AI service"**

**Solution:**

1. Ensure Flask server is running on `localhost:5000`
2. Check firewall settings
3. For Android Emulator: Use `10.0.2.2` instead of `127.0.0.1`
4. For physical device: Use machine's local IP address

### **Issue: "Invalid request parameters"**

**Solution:**

- Budget must be ≥ Rs 100
- Days must be between 1-365
- Category must be: `meal`, `laundry`, or `maintenance`

### **Issue: Empty recommendation results**

**Solution:**

1. Check trained_models/trained_data.json exists
2. Run `python model_trainer.py` to retrain models
3. Restart Flask server

---

## 📞 Support

For issues or questions:

1. Check Flask server logs
2. Verify all dependencies installed
3. Run `pip install -r requirements.txt`
4. Check device network connectivity

---

## 🎓 Learn More

The AI model uses:

- **ML Algorithm**: Price prediction with statistical analysis
- **NLP**: spaCy for natural language understanding
- **Features**: Budget, duration, category analysis
- **Training Data**: Kaggle datasets + custom data

---

**Last Updated**: April 2026  
**Version**: 2.0 (Flutter Migration)

```
💵 Budget: 50 (too low!)
📅 Duration: 5
🏷️  Category: Meal

✅ Click: Generate Plan
❌ You'll see: Error message "Minimum budget is Rs 100"
✅ Try with Rs 200 instead - works!
```

### **Test 5️⃣: Export to CSV**

```
1. Generate any plan (Test 1, 2, or 3)
2. Scroll down to bottom
3. Click: 📥 Download as CSV button
4. Check Downloads folder for the CSV file
5. Open in Excel/Google Sheets
```

---

## 🎨 What to Look For

### **Visual Quality ✅**

- [ ] Gradient purple background looks professional
- [ ] Cards have nice shadows and spacing
- [ ] Text is readable and well-formatted
- [ ] Buttons have hover effects

### **Functionality ✅**

- [ ] Input form accepts all data types
- [ ] Category buttons toggle correctly
- [ ] Plan generates immediately (no lag)
- [ ] Statistics update in real-time
- [ ] CSV export works without errors

### **Responsiveness ✅**

- [ ] Works on desktop (1920px)
- [ ] Works on tablet (768px)
- [ ] Works on phone (375px)
- [ ] Layout adjusts automatically

### **User Experience ✅**

- [ ] Error messages are helpful
- [ ] Success confirmations appear
- [ ] Natural language parsing works
- [ ] Reset button clears everything
- [ ] Export file has correct data

---

## 📋 Comparison: Website vs Jupyter

| Feature             | Website          | Jupyter Notebook   |
| ------------------- | ---------------- | ------------------ |
| **Easy to Use**     | ✅ Point & click | ⚠️ Requires coding |
| **Visual**          | ✅ Beautiful UI  | ⚠️ Text output     |
| **Speed**           | ✅ Instant       | ⚠️ Requires kernel |
| **Data Input**      | ✅ Forms         | ⚠️ Code cells      |
| **Export**          | ✅ CSV button    | ⚠️ Manual copying  |
| **Demo Ready**      | ✅ Ready to show | ⚠️ Needs setup     |
| **Mobile Friendly** | ✅ Yes           | ❌ No              |

---

## 💡 Pro Tips

### **Natural Language Parsing Works With:**

- ✅ "I have 2000 rupees for 2 weeks for meals"
- ✅ "3000 mein 1 month laundry plan"
- ✅ "need maintenance plan for 10 days with 3000 rupees"
- ✅ "khane ka plan 5000 mein 2 weeks"
- ❌ Don't forget amount and duration!

### **Best Practices:**

1. Use natural language first (faster)
2. Manual entry for precise control
3. Download CSV for records
4. Test all 3 categories
5. Try edge cases (very low/high budgets)

### **Performance Tricks:**

- JavaScript executes in <100ms
- No server calls needed
- Works offline (after first load)
- Zero external dependencies
- Fast on all devices

---

## 🔧 File Organization

```
After running everything, you'll have:

✅ index.html              ← OPEN THIS (the website!)
✅ config.py               ← Configuration (advanced)
✅ AI model.ipynb          ← Jupyter notebook (advanced)
✅ WEBSITE_GUIDE.md        ← Detailed documentation
✅ QUICK_START.md          ← This file!
✅ flutter_*.json          ← Data exports
```

---

## ❓ Frequently Asked Questions

**Q: Can I open it without Python?**
A: ✅ YES! The website is pure HTML/CSS/JavaScript - no backend needed.

**Q: Is my data safe?**
A: ✅ YES! Everything runs in your browser. Nothing is sent to servers.

**Q: Can I use it offline?**
A: ✅ YES! After first load, it works completely offline.

**Q: Can I modify the prices?**
A: 🔧 Edit the JavaScript in index.html (advanced) or prices in CATEGORIES object.

**Q: How do I share the CSV file?**
A: 📧 Download → Attach to email OR copy to shared folder.

**Q: Does it work on phone?**
A: ✅ YES! Fully responsive design adapts to any screen size.

**Q: Can I integrate it with my app?**
A: 🔧 Yes! Extracted planner logic can be used separately (advanced).

---

## 📊 Sample Output

When you generate a plan, you'll see something like:

```
PLAN SUMMARY:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Daily Allowance:    Rs 142.86
Total Budget:       Rs 2,000
Total Spent:        Rs 1,982
Remaining:          Rs 18
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DAILY BREAKDOWN:
Day 1:  Paratha + Chai              Rs 110 ✅
Day 2:  Rice + Eggs                 Rs 347 ✅
Day 3:  Bread + Daal                Rs 202 ✅
...
Day 14: Roti + Vegetables           Rs 110 ✅

TIPS:
💡 Buy items in bulk for better prices
💡 Choose seasonal vegetables
💡 Keep 10-15% budget as emergency reserve
```

---

## 🎯 Testing Checklist

```
FUNCTIONALITY TESTS:
□ Natural language input works
□ Manual input works
□ All 3 categories work
□ Reset button clears form
□ Error messages appear for invalid input
□ CSV export works

VISUAL TESTS:
□ Colors are vibrant (purple gradient)
□ Text is readable
□ Buttons have hover effects
□ Cards have nice shadows
□ Mobile layout looks good

EDGE CASE TESTS:
□ Budget: 50 (should error)
□ Budget: 100 (should work - minimum)
□ Budget: 100,000 (should work - high)
□ Duration: 0 (should error)
□ Duration: 1 (should work - minimum)
□ Duration: 365 (should work - maximum)

EXPORT TESTS:
□ CSV file downloads
□ CSV opens in Excel
□ CSV has correct format
□ CSV contains all data
```

---

## 🎓 Understanding the Technology

### **Frontend Stack:**

- **HTML5** — Structure & semantic markup
- **CSS3** — Modern styling, gradients, animations
- **JavaScript (Vanilla)** — No frameworks, 100% pure

### **Features:**

- Responsive grid layout (works on all screens)
- Smooth animations and transitions
- Real-time form validation
- Smart natural language parsing
- Intelligent plan generation algorithm

### **Performance:**

- File size: ~50 KB
- Load time: <1 second
- Plan generation: <100ms
- Zero external dependencies

---

## 🚀 Ready to Go!

### **RIGHT NOW:**

1. Open `index.html` in your browser
2. Try Test #1 (copy-paste the sentence)
3. Click "Generate Plan"
4. Scroll down to see the full plan
5. Click "Download as CSV"

**That's it! You're ready to showcase your project!** 🎉

---

## 📞 Need Help?

### **If website won't open:**

```
1. Right-click index.html
2. Select "Open with..."
3. Choose your browser (Chrome recommended)
```

### **If styles look broken:**

```
1. Press Ctrl+Shift+R (hard refresh)
2. Or: Ctrl+Minus (zoom out)
3. Or: Clear browser cache
```

### **If nothing happens when you click "Generate":**

```
1. Press F12 (Developer Tools)
2. Go to Console tab
3. Check for any red error messages
4. Try a different browser
```

---

**Status:** ✅ **READY TO DEMO**  
**Time to First Result:** < 10 seconds  
**Learning Curve:** None! Just fill form & click  
**Wow Factor:** ⭐⭐⭐⭐⭐ (Very impressive for presentations!)

Now go open that HTML file and see the magic! 🪄✨
