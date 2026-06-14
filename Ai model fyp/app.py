"""
===============================================================
🚀 AI Expense Planner - Flask API Backend
===============================================================
Connects Jupyter notebook AI model to website via REST API
Serves meal, laundry, maintenance data from processed datasets
"""

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import json
import logging
from pathlib import Path
import pandas as pd
from typing import Dict, List, Optional
import random
import spacy
import re
import subprocess
import sys
from datetime import datetime
from config import EXCHANGE_RATES as CFG_RATES, CATEGORIES, validate_budget, validate_days, PLANNER_CONFIG

# =========================================================
# CONFIGURATION
# =========================================================
app = Flask(__name__)
CORS(app)  # Enable CORS for web requests

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
logger = logging.getLogger(__name__)

# =========================================================
# NLP INITIALIZATION
# =========================================================

try:
    nlp = spacy.load("en_core_web_sm")
    logger.info("✅ spaCy NLP model loaded successfully")
except Exception:
    logger.warning("⚠️  spaCy model not found. Installing...")
    try:
        import subprocess
        # Added check=True and better error handling for disk space/network issues
        subprocess.run([sys.executable, "-m", "spacy", "download", "en_core_web_sm"], check=True)
        nlp = spacy.load("en_core_web_sm")
        logger.info("✅ spaCy NLP model installed and loaded")
    except Exception as e:
        logger.error(f"❌ Could not initialize spaCy: {e}")
        logger.warning("🔗 Falling back to keyword-based analysis only")
        nlp = None

# =========================================================
# DATA LOADING
# =========================================================

# =========================================================
# DATA LOADING & MODEL INTEGRATION
# =========================================================

DATASETS = {
    'meal': [],
    'laundry': [],
    'maintenance': []
}

TRAINED_MODELS = {}
TRAINED_MODELS_PATH = Path('trained_models')

def load_trained_models():
    """Load trained models from JSON"""
    global DATASETS, TRAINED_MODELS
    
    logger.info("📦 Loading trained models...")
    
    trained_data_file = TRAINED_MODELS_PATH / 'trained_data.json'
    
    if not trained_data_file.exists():
        logger.warning("⚠️  Trained models not found. Running training pipeline...")
        try:
            # Import and run the training pipeline
            from model_trainer import train_all_models
            train_all_models()
            logger.info("✅ Models trained successfully")
        except Exception as e:
            logger.error(f"❌ Training failed: {e}")
            logger.info("📥 Using fallback hardcoded data...")
            load_datasets()
            return
    
    try:
        with open(trained_data_file, 'r') as f:
            trained_data = json.load(f)
        
        TRAINED_MODELS = trained_data['metadata']
        DATASETS = trained_data['datasets']
        
        logger.info("✅ Trained models loaded successfully")
        logger.info(f"   Trained at: {TRAINED_MODELS.get('trained_at', 'Unknown')}")
        logger.info(f"   Meal items: {len(DATASETS['meal'])}")
        logger.info(f"   Laundry items: {len(DATASETS['laundry'])}")
        logger.info(f"   Maintenance items: {len(DATASETS['maintenance'])}")
        
    except Exception as e:
        logger.error(f"❌ Error loading trained models: {e}")
        logger.info("📥 Falling back to hardcoded data...")
        load_datasets()

EXCHANGE_RATES = CFG_RATES
# =========================================================
# NLP ANALYSIS FUNCTIONS
# =========================================================

def analyze_user_input(text: str) -> Dict:
    """
    Use spaCy NLP to analyze user input and extract budget, days, and category
    Returns: {budget, days, category, confidence, original_text}
    """
    try:
        # Only use spaCy if it was successfully loaded
        doc = None
        if nlp:
            doc = nlp(text.lower())
        
        text_lower = text.lower()
        
        # Extract numerical values
        budget = None
        days = None
        
        # Robust budget detection for "Easy English" (supports pk, rs, amount)
        budget_patterns = [
            # 1. Number followed by currency (highest confidence)
            r'([\d,]+)\s*(?:pkr|rs|rupees?|pk|amount|bucks)',
            # 2. Keywords (excluding 'for') followed by number
            r'(?:i have|budget|total|pk|rs|pkr|rupees?|price|spent|cost)\s*([\d,]+)',
            # 3. Leading number at start of sentence (common in "5000 for 10 days")
            r'^\s*([\d,]+)(?!\s*(?:days?|weeks?|months?|din|hafte|mahine|d|w|m|mo))',
        ]
        
        for pattern in budget_patterns:
            match = re.search(pattern, text_lower)
            if match:
                budget = float(match.group(1).replace(',', ''))
                break
        
        # Robust duration detection (days, weeks, months, or just numbers)
        duration_patterns = [
            (r'(\d+)\s*(?:days?|din|d)', 1),
            (r'(\d+)\s*(?:weeks?|hafte|w|wk)', 7),
            (r'(\d+)\s*(?:months?|mahine|m|mo)', 30),
            (r'(?:for|period|duration)\s*(\d+)', 1), 
        ]
        
        for pattern, multiplier in duration_patterns:
            match = re.search(pattern, text_lower)
            if match:
                days = int(match.group(1)) * multiplier
                break
        
        # Detect category using spaCy entities and keywords
        category = 'meal'  # Default
        
        category_keywords = {
            'meal': ['meal', 'food', 'eat', 'khana', 'dinner', 'lunch', 'breakfast', 'biryani', 'naan', 'curry'],
            'laundry': ['laundry', 'wash', 'clothes', 'dhobi', 'kapray', 'detergent', 'soap', 'fabric'],
            'maintenance': ['maintenance', 'repair', 'bijli', 'gas', 'paani', 'ghar', 'bill', 'plumber', 'electrician'],
        }
        
        for cat, keywords in category_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                category = cat
                break
        
        return {
            'budget': budget,
            'days': days,
            'category': category,
            'original_text': text,
            'success': budget is not None and days is not None
        }
    
    except Exception as e:
        logger.error(f"Error in NLP analysis: {e}")
        return {
            'budget': None,
            'days': None,
            'category': 'meal',
            'original_text': text,
            'success': False,
            'error': str(e)
        }

def load_datasets():
    """Load datasets from Kaggle data or JSON exports"""
    global DATASETS
    
    logger.info("📥 Loading datasets...")
    
    try:
        # Try to load from flask_datasets.json (exported from notebook)
        datasets_file = Path('flask_datasets.json')
        if datasets_file.exists():
            logger.info(f"📂 Loading from {datasets_file}")
            with open(datasets_file, 'r') as f:
                loaded_data = json.load(f)
                DATASETS = loaded_data.get('datasets', DATASETS)
                logger.info(f"✅ Loaded from JSON export")
                return
    except Exception as e:
        logger.warning(f"⚠️  Could not load from JSON: {e}")
    
    # Fallback: Use enhanced meal database
    logger.info("📦 Using built-in enhanced meal database...")
    
    DATASETS['meal'] = [
        {'name': 'Fried Egg & Paratha', 'price': 90, 'type': 'breakfast'},
        {'name': 'Halwa Puri', 'price': 150, 'type': 'breakfast'},
        {'name': 'Yogurt & Muesli', 'price': 180, 'type': 'breakfast'},
        {'name': 'Beef Biryani', 'price': 280, 'type': 'lunch'},
        {'name': 'Chicken Pulao', 'price': 240, 'type': 'lunch'},
        {'name': 'Butter Chicken', 'price': 350, 'type': 'dinner'},
        {'name': 'Dal Mash', 'price': 120, 'type': 'dinner'},
        {'name': 'Chicken Karahi', 'price': 350, 'type': 'dinner'},
        {'name': 'Aloo Palak', 'price': 140, 'type': 'dinner'},
        {'name': 'Paneer Tikka', 'price': 280, 'type': 'lunch'},
        {'name': 'Seekh Kebab (2 pcs)', 'price': 200, 'type': 'dinner'},
        {'name': 'Anday Wala Burger', 'price': 150, 'type': 'lunch'},
        {'name': 'Fruit Chaat', 'price': 100, 'type': 'breakfast'},
        {'name': 'Mix Sabzi', 'price': 130, 'type': 'lunch'},
        {'name': 'Haleem', 'price': 200, 'type': 'lunch'},
        {'name': 'Daal Chawal', 'price': 140, 'type': 'lunch'},
        {'name': 'Aloo Gosht', 'price': 300, 'type': 'dinner'},
        {'name': 'Nihari', 'price': 380, 'type': 'dinner'},
    ]
    
    DATASETS['laundry'] = [
        {'name': 'Surf Excel (500g)', 'price': 280, 'currency': 'PKR'},
        {'name': 'Ariel (1kg)', 'price': 520, 'currency': 'PKR'},
        {'name': 'Washing Bar Soap', 'price': 60, 'currency': 'PKR'},
        {'name': 'Comfort Softener', 'price': 160, 'currency': 'PKR'},
        {'name': 'Bleach (500ml)', 'price': 90, 'currency': 'PKR'},
        {'name': 'Stain Remover', 'price': 120, 'currency': 'PKR'},
        {'name': 'Dettol (250ml)', 'price': 140, 'currency': 'PKR'},
        {'name': 'Rin Detergent (1kg)', 'price': 429, 'currency': 'PKR'},
        {'name': 'Vim Bar (150g)', 'price': 83, 'currency': 'PKR'},
        {'name': 'Nirma Detergent', 'price': 264, 'currency': 'PKR'},
        {'name': 'Vanish Stain Remover', 'price': 450, 'currency': 'PKR'},
        {'name': 'Dreft Laundry', 'price': 350, 'currency': 'PKR'},
        {'name': 'Woolite Delicates', 'price': 380, 'currency': 'PKR'},
        {'name': 'Downy Softener', 'price': 320, 'currency': 'PKR'},
    ]
    
    DATASETS['maintenance'] = [
        {'name': 'Electricity Bill (Monthly)', 'price': 1200, 'currency': 'PKR'},
        {'name': 'Gas Bill (Monthly)', 'price': 400, 'currency': 'PKR'},
        {'name': 'Plumber Visit', 'price': 500, 'currency': 'PKR'},
        {'name': 'Electrician Visit', 'price': 600, 'currency': 'PKR'},
        {'name': 'LED Light Bulb', 'price': 180, 'currency': 'PKR'},
        {'name': 'Broom / Mop', 'price': 150, 'currency': 'PKR'},
        {'name': 'Garbage Bags (20pcs)', 'price': 80, 'currency': 'PKR'},
        {'name': 'Cockroach Spray', 'price': 220, 'currency': 'PKR'},
        {'name': 'Water Filter Refill', 'price': 350, 'currency': 'PKR'},
        {'name': 'Phenyl Floor Cleaner', 'price': 248, 'currency': 'PKR'},
        {'name': 'Electrical Tape', 'price': 116, 'currency': 'PKR'},
        {'name': 'Paint (1L)', 'price': 450, 'currency': 'PKR'},
        {'name': 'Door Lock Repair', 'price': 400, 'currency': 'PKR'},
        {'name': 'Window Repair', 'price': 350, 'currency': 'PKR'},
        {'name': 'Plumbing Pipe (meter)', 'price': 200, 'currency': 'PKR'},
    ]
    
    logger.info(f"✅ Built-in datasets loaded")
    logger.info(f"   Meals: {len(DATASETS['meal'])} items")
    logger.info(f"   Laundry: {len(DATASETS['laundry'])} items")
    logger.info(f"   Maintenance: {len(DATASETS['maintenance'])} items")

# =========================================================
# API ENDPOINTS
# =========================================================

@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'message': '🚀 AI Expense Planner API is running',
        'version': '1.0.0'
    })

@app.route('/api/datasets', methods=['GET'])
def get_datasets():
    """Get all datasets"""
    return jsonify({
        'meal': DATASETS['meal'],
        'laundry': DATASETS['laundry'],
        'maintenance': DATASETS['maintenance'],
        'stats': {
            'meal_count': len(DATASETS['meal']),
            'laundry_count': len(DATASETS['laundry']),
            'maintenance_count': len(DATASETS['maintenance']),
        }
    })

@app.route('/api/datasets/<category>', methods=['GET'])
def get_category(category):
    """Get specific category data"""
    category = category.lower()
    
    if category not in DATASETS:
        return jsonify({'error': f'Category {category} not found'}), 404
    
    return jsonify({
        'category': category,
        'items': DATASETS[category],
        'count': len(DATASETS[category])
    })

@app.route('/api/plan', methods=['POST'])
def generate_plan():
    """Generate expense plan"""
    try:
        data = request.json
        
        budget = float(data.get('budget', 0))
        days = int(data.get('days', 1))
        category = data.get('category', 'meal').lower()
        
        # Validation
        if budget < 100:
            return jsonify({'error': 'Minimum budget is Rs 100'}), 400
        if days < 1 or days > 365:
            return jsonify({'error': 'Days must be between 1-365'}), 400
        if category not in DATASETS:
            return jsonify({'error': f'Category {category} not found'}), 400
        
        # Generate plan
        plan = create_plan(budget, days, category)
        
        return jsonify({
            'success': True,
            'plan': plan
        })
    
    except Exception as e:
        logger.error(f"Error generating plan: {e}")
        return jsonify({'error': str(e)}), 500

def create_plan(budget: float, days: int, category: str) -> Dict:
    """Create expense plan using greedy algorithm"""
    
    items = DATASETS[category]
    daily_budget = budget / days
    
    # Use category-specific constraints from config
    max_items_per_day = CATEGORIES.get(category, {}).get('max_items_per_day', 3)

    # Filter items that are potentially affordable within the daily budget
    # Add a buffer to allow for some flexibility (e.g., 1.3 means 130% of daily budget)
    affordable_items = [
        item for item in items
        if item['price'] <= daily_budget * PLANNER_CONFIG['BUDGET_BUFFER']
    ]
    
    if not affordable_items:
        logger.warning(f"No affordable items found for {category} with daily budget {daily_budget:.2f}. Falling back to cheapest items.")
        # Fallback: if no items are affordable, take the cheapest few from the whole dataset
        affordable_items = sorted(items, key=lambda x: x['price'])[:PLANNER_CONFIG['MAX_ITEMS_PREVIEW']]
        if not affordable_items:
            raise ValueError(f"No items available for category {category}.")

    # Sort affordable items by price for greedy selection (cheapest first)
    affordable_items = sorted(affordable_items, key=lambda x: x['price'])
    
    day_plans = []
    total_spent = 0
    pool_idx = 0
    item_count = len(affordable_items)
    
    for day in range(1, days + 1):
        day_items = []
        day_spend = 0
        current_day_remaining_budget = daily_budget
        
        # 1. Specialized Selection for Meals: Strict type slot preservation
        if category == 'meal':
            meal_types = ['breakfast', 'lunch', 'dinner']
            # To ensure variety and avoid picking the same item if multiple exist
            random.shuffle(affordable_items) 
            for m_type in meal_types:
                # Find affordable items strictly of this type from the shuffled affordable pool
                type_pool = [i for i in affordable_items if i.get('type') == m_type and i['price'] <= current_day_remaining_budget]
                if type_pool:
                    item = random.choice(type_pool)
                    day_items.append(item['name'])
                    day_spend += item['price']
                    current_day_remaining_budget -= item['price']
                else:
                    day_items.append("Adjusted (Home-cooked)") # Fallback if no affordable item of type
        else:
            # 2. General Greedy Selection (for Laundry/Maintenance - already sorted by price)
            items_added_today = 0
            for item in affordable_items: # Iterate through sorted affordable items
                if items_added_today >= max_items_per_day:
                    break
                if current_day_remaining_budget >= item['price']:
                    day_items.append(item['name'])
                    day_spend += item['price']
                    current_day_remaining_budget -= item['price']
                    items_added_today += 1
        
        total_spent += day_spend
        day_plans.append({
            'day': day,
            'items': day_items, # List of item names
            'spend': round(day_spend, 2) # Round daily spend
        })
    
    return {
        'budget': budget,
        'days': days,
        'category': category,
        'daily_budget': round(daily_budget, 2),
        'day_plans': day_plans,
        'total_spent': round(total_spent, 2),
        'remaining': round(budget - total_spent, 2)
    }

@app.route('/api/exchange-rates', methods=['GET'])
def get_exchange_rates():
    """Get exchange rates"""
    return jsonify(EXCHANGE_RATES)

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get dataset statistics"""
    stats = {}
    
    for category, items in DATASETS.items():
        if items:
            prices = [item.get('price', 0) for item in items]
            stats[category] = {
                'count': len(items),
                'min_price': min(prices),
                'max_price': max(prices),
                'avg_price': round(sum(prices) / len(prices), 2)
            }
    
    return jsonify(stats)

@app.route('/api/analyze', methods=['POST'])
def analyze_input():
    """Analyze natural language input using spaCy NLP"""
    try:
        data = request.json
        text = data.get('text', '').strip()
        
        if not text:
            return jsonify({'error': 'No input text provided'}), 400
        
        analysis = analyze_user_input(text)
        
        return jsonify({
            'success': analysis['success'],
            'budget': analysis['budget'],
            'days': analysis['days'],
            'category': analysis['category'],
            'original_text': analysis['original_text']
        })
    
    except Exception as e:
        logger.error(f"Error analyzing input: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/chat-plan', methods=['POST'])
def chat_plan():
    """Generate expense plan with chat-style response using spaCy NLP"""
    try:
        data = request.json
        text = data.get('text', '').strip()
        
        if not text:
            return jsonify({'error': 'No input text provided'}), 400
        
        # Analyze user input with NLP
        analysis = analyze_user_input(text)
        
        if not analysis['success'] or not analysis['budget'] or not analysis['days']:
            return jsonify({
                'error': 'Could not understand your request. Please provide budget and duration.',
                'suggestion': 'Example: "I have 3000 rupees for 2 weeks for meals"'
            }), 400
        
        budget = analysis['budget']
        days = analysis['days']
        category = analysis['category']
        
        # Validate
        if budget < 100:
            return jsonify({'error': 'Minimum budget is Rs 100'}), 400
        if days < 1 or days > 365:
            return jsonify({'error': 'Days must be between 1-365'}), 400
        if category not in DATASETS:
            return jsonify({'error': f'Category {category} not found'}), 400
        
        # Generate plan
        plan = create_plan(budget, days, category)
        
        # Create chat response
        category_names = {
            'meal': 'Meal',
            'laundry': 'Laundry',
            'maintenance': 'Maintenance'
        }
        
        category_emojis = {
            'meal': '🍱',
            'laundry': '🧺',
            'maintenance': '🔧'
        }
        
        # Consolidate response into a single unified message to prevent UI duplication/race conditions
        summary = (f"🚀 STRATEGIC {category_names[category].upper()} ALLOCATION\n\n"
                  f"I have engineered a financial roadmap for your {days}-day period with a total capital of PKR {budget:,.0f}.\n\n"
                  f"EXECUTIVE SUMMARY\n"
                  f"• Category: {category_names[category]} {category_emojis[category]}\n"
                  f"• Daily Expenditure Ceiling: PKR {plan['daily_budget']:,.0f}\n"
                  f"• Projected Total Investment: PKR {plan['total_spent']:,.0f}\n"
                  f"• Projected Surplus (Savings): PKR {plan['remaining']:,.0f}")
        
        # Add daily breakdown messages
        breakdown_text = "Daily Breakdown:\n"
        meal_labels = ["Breakfast", "Lunch", "Dinner"]
        meal_icons = ["🍳", "🍛", "🍲"]

        for day_plan in plan['day_plans']:
            if day_plan['items']:
                if category == 'meal':
                    categorized = []
                    for idx, item_name in enumerate(day_plan['items']):
                        if idx < len(meal_labels):
                            display_name = "Light/Home-made" if "Adjusted" in item_name else item_name
                            categorized.append(f"{meal_icons[idx]} {meal_labels[idx]}: {display_name}")
                    items_text = "\n".join(categorized)
                else:
                    items_text = "\n".join([f"🔹 {item}" for item in day_plan['items']])

                breakdown_text += f"\n🗓️ DAY {day_plan['day']}\n{items_text}\n💰 Allocated: PKR {day_plan['spend']:,.0f}\n"
            else:
                breakdown_text += f"\nDay {day_plan['day']}: Rest day\n"
        
        # Add tips
        tips_text = ("\n💡 Pro Tips:\n"
                    "• Buy items in bulk for better pricing\n"
                    "• Choose seasonal/discounted items when possible\n"
                    "• Keep 10-15% of budget as emergency reserve\n"
                    "• Track your spending daily for better control")

        # Combine everything into a single response payload
        full_response = f"{summary}\n\n{breakdown_text}\n{tips_text}"
        
        chat_messages = [{
            'role': 'assistant',
            'content': full_response,
            'timestamp': datetime.now().isoformat()
        }]
        
        return jsonify({
            'success': True,
            'plan': plan,
            'chat_messages': chat_messages,
            'nlp_analysis': {
                'budget': analysis['budget'],
                'days': analysis['days'],
                'category': analysis['category']
            }
        })
    
    except Exception as e:
        logger.error(f"Error generating chat plan: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/train', methods=['POST'])
def train_models():
    """Train/retrain all models on demand"""
    try:
        logger.info("🤖 Training models on request...")
        
        from model_trainer import train_all_models
        
        trained_models = train_all_models()
        
        # Reload trained models into app
        load_trained_models()
        
        return jsonify({
            'success': True,
            'message': 'Models trained and reloaded successfully',
            'trained_at': datetime.now().isoformat(),
            'models': {
                'meal': len(DATASETS.get('meal', [])),
                'laundry': len(DATASETS.get('laundry', [])),
                'maintenance': len(DATASETS.get('maintenance', []))
            }
        })
    
    except Exception as e:
        logger.error(f"Error training models: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/models/status', methods=['GET'])
def model_status():
    """Get status of trained models"""
    try:
        return jsonify({
            'success': True,
            'models': TRAINED_MODELS,
            'datasets_loaded': {
                'meal': len(DATASETS.get('meal', [])),
                'laundry': len(DATASETS.get('laundry', [])),
                'maintenance': len(DATASETS.get('maintenance', []))
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/ai-budget-recommendation', methods=['POST'])
def ai_budget_recommendation():
    """
    AI Budget Recommendation endpoint for Flutter app
    Analyzes budget and generates smart spending recommendations
    """
    try:
        data = request.json
        budget = float(data.get('budget', 0))
        days = int(data.get('days', 1))
        category = data.get('category', 'meal').lower()
        
        # Validation
        if budget < 100:
            return jsonify({
                'success': False,
                'error': 'Minimum budget is Rs 100'
            }), 400
        
        if days < 1 or days > 365:
            return jsonify({
                'success': False,
                'error': 'Days must be between 1-365'
            }), 400
        
        if category not in DATASETS:
            return jsonify({
                'success': False,
                'error': f'Category {category} not found'
            }), 400
        
        # Generate plan
        plan = create_plan(budget, days, category)
        
        # Calculate AI insights
        items = DATASETS[category]
        prices = [item.get('price', 0) for item in items]
        
        daily_budget = budget / days
        average_price = sum(prices) / len(prices)
        
        # Generate recommendations
        recommendations = []
        
        if daily_budget < average_price * 0.8:
            recommendations.append({
                'type': 'warning',
                'title': 'Budget Alert',
                'message': 'Your daily budget is below average pricing. Consider focusing on budget-friendly items.',
                'emoji': '⚠️'
            })
        elif daily_budget > average_price * 1.5:
            recommendations.append({
                'type': 'info',
                'title': 'Budget Advantage',
                'message': 'You have a comfortable budget! You can afford premium items or variety.',
                'emoji': '🎯'
            })
        
        # Category-specific recommendations
        if category == 'meal':
            recommendations.append({
                'type': 'tip',
                'title': 'Nutrition Tip',
                'message': 'Mix proteins and carbs for balanced nutrition within your budget.',
                'emoji': '🥗'
            })
        elif category == 'laundry':
            recommendations.append({
                'type': 'tip',
                'title': 'Laundry Tip',
                'message': 'Buy detergent in bulk for Rs 429+ to save on per-wash cost.',
                'emoji': '🧺'
            })
        elif category == 'maintenance':
            recommendations.append({
                'type': 'tip',
                'title': 'Budget Tip',
                'message': 'Keep 15% of budget reserved for emergency repairs.',
                'emoji': '🔧'
            })
        
        # Calculate savings potential
        min_price = min(prices)
        optimal_spending = min_price * 2 * days  # Very conservative estimate
        potential_savings = budget - optimal_spending if budget > optimal_spending else 0
        
        return jsonify({
            'success': True,
            'plan': plan,
            'recommendations': recommendations,
            'insights': {
                'daily_budget': round(daily_budget, 2),
                'average_item_price': round(average_price, 2),
                'budget_efficiency': round((daily_budget / average_price) * 100, 1),
                'potential_savings': round(potential_savings, 2),
                'items_in_category': len(items)
            },
            'statistics': {
                'min_price': min(prices),
                'max_price': max(prices),
                'avg_price': round(average_price, 2)
            }
        })
    
    except Exception as e:
        logger.error(f"Error generating AI recommendation: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# =========================================================
# ERROR HANDLERS
# =========================================================

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Internal server error'}), 500

# =========================================================
# STARTUP
# =========================================================

if __name__ == '__main__':
    logger.info("="*60)
    logger.info("🚀 AI Expense Planner - Flask API Backend")
    logger.info("="*60)
    
    # Load trained models
    load_trained_models()
    
    logger.info("\n📊 Available Endpoints:")
    logger.info("  GET  /api/health                      - Health check")
    logger.info("  GET  /api/datasets                    - All datasets")
    logger.info("  GET  /api/datasets/<category>         - Specific category")
    logger.info("  POST /api/plan                        - Generate plan")
    logger.info("  POST /api/analyze                     - Analyze natural language")
    logger.info("  POST /api/chat-plan                   - Chat-style plan (NLP)")
    logger.info("  GET  /api/exchange-rates              - Exchange rates")
    logger.info("  GET  /api/stats                       - Dataset statistics")
    logger.info("  POST /api/train                       - Train/retrain models")
    logger.info("  GET  /api/models/status               - Check model status")
    logger.info("  POST /api/ai-budget-recommendation    - 🆕 Flutter AI Recommendations")
    
    logger.info("\n📱 Flutter Integration:")
    logger.info("  Service: lib/core/services/ai_budget_service.dart")
    logger.info("  Screen:  lib/features/home/screens/ai_budget_recommendation.dart")
    logger.info("  Card:    Added to user_home.dart")
    
    logger.info("\n🌐 Starting server on http://localhost:5000")
    logger.info("="*60 + "\n")
    
    # Run Flask app
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        use_reloader=False  # Prevent duplicate logging
    )
