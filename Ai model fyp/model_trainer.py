"""
===============================================================
🤖 Model Training Pipeline - AI Expense Planner
===============================================================
Trains price prediction models for meal, laundry, and maintenance
Exports trained data as JSON for dynamic consumption
"""

import json
import logging
import pickle
from pathlib import Path
from typing import Dict, List, Tuple
import numpy as np
import pandas as pd
from datetime import datetime
from config import PRICE_COL_KEYWORDS, ITEM_COL_KEYWORDS, get_exchange_rate

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
logger = logging.getLogger(__name__)

# Paths
MODEL_DIR = Path('trained_models')
TRAINING_DATA_DIR = Path('kaggle_data')
MEAL_DATA_SUBDIR = TRAINING_DATA_DIR / 'food dataset'
PREMIUM_DATA_DIR = Path('premium_datasets')

# =========================================================
# TRAINING DATA
# =========================================================

# Enhanced meal database from Kaggle & Zomato
MEAL_TRAINING_DATA = [
    {'name': 'Fried Egg & Paratha', 'price': 90, 'calories': 320, 'protein': 10, 'type': 'breakfast'},
    {'name': 'Halwa Puri', 'price': 150, 'calories': 450, 'protein': 8, 'type': 'breakfast'},
    {'name': 'Yogurt & Muesli', 'price': 180, 'calories': 250, 'protein': 12, 'type': 'breakfast'},
    {'name': 'Beef Biryani', 'price': 280, 'calories': 550, 'protein': 18, 'type': 'lunch'},
    {'name': 'Chicken Pulao', 'price': 240, 'calories': 450, 'protein': 14, 'type': 'lunch'},
    {'name': 'Butter Chicken', 'price': 350, 'calories': 520, 'protein': 22, 'type': 'dinner'},
    {'name': 'Dal Mash', 'price': 120, 'calories': 250, 'protein': 9, 'type': 'dinner'},
    {'name': 'Chicken Karahi', 'price': 350, 'calories': 420, 'protein': 24, 'type': 'dinner'},
    {'name': 'Aloo Palak', 'price': 140, 'calories': 180, 'protein': 6, 'type': 'dinner'},
    {'name': 'Paneer Tikka', 'price': 280, 'calories': 280, 'protein': 15, 'type': 'lunch'},
    {'name': 'Zinger Burger', 'price': 320, 'calories': 550, 'protein': 20, 'type': 'dinner'},
    {'name': 'Seekh Kebab (2 pcs)', 'price': 200, 'calories': 350, 'protein': 18, 'type': 'dinner'},
    {'name': 'Anday Wala Burger', 'price': 150, 'calories': 400, 'protein': 12, 'type': 'lunch'},
    {'name': 'Nihari', 'price': 380, 'calories': 650, 'protein': 28, 'type': 'dinner'},
    {'name': 'Fruit Chaat', 'price': 100, 'calories': 150, 'protein': 2, 'type': 'breakfast'},
    {'name': 'Mix Sabzi', 'price': 130, 'calories': 190, 'protein': 5, 'type': 'lunch'},
    {'name': 'Haleem', 'price': 200, 'calories': 380, 'protein': 16, 'type': 'lunch'},
    {'name': 'Daal Chawal', 'price': 140, 'calories': 320, 'protein': 11, 'type': 'lunch'},
    {'name': 'Aloo Gosht', 'price': 300, 'calories': 450, 'protein': 20, 'type': 'dinner'},
]

LAUNDRY_TRAINING_DATA = [
    {'name': 'Surf Excel (500g)', 'price': 280, 'concentration': 'high', 'capacity': 15},
    {'name': 'Ariel (1kg)', 'price': 520, 'concentration': 'premium', 'capacity': 30},
    {'name': 'Washing Bar Soap', 'price': 60, 'concentration': 'standard', 'capacity': 1},
    {'name': 'Comfort Softener', 'price': 160, 'concentration': 'medium', 'capacity': 8},
    {'name': 'Bleach (500ml)', 'price': 90, 'concentration': 'high', 'capacity': 20},
    {'name': 'Stain Remover', 'price': 120, 'concentration': 'premium', 'capacity': 5},
    {'name': 'Dettol (250ml)', 'price': 140, 'concentration': 'high', 'capacity': 10},
    {'name': 'Rin Detergent (1kg)', 'price': 429, 'concentration': 'premium', 'capacity': 25},
    {'name': 'Vim Bar (150g)', 'price': 83, 'concentration': 'standard', 'capacity': 3},
    {'name': 'Nirma Detergent', 'price': 264, 'concentration': 'standard', 'capacity': 20},
    {'name': 'Vanish Stain Remover', 'price': 450, 'concentration': 'premium', 'capacity': 12},
    {'name': 'Dreft Laundry', 'price': 350, 'concentration': 'premium', 'capacity': 18},
    {'name': 'Woolite Delicates', 'price': 380, 'concentration': 'premium', 'capacity': 10},
    {'name': 'Downy Softener', 'price': 320, 'concentration': 'premium', 'capacity': 15},
]

MAINTENANCE_TRAINING_DATA = [
    {'name': 'Electricity Bill (Monthly)', 'price': 1200, 'frequency': 'monthly', 'usage': 'high'},
    {'name': 'Gas Bill (Monthly)', 'price': 400, 'frequency': 'monthly', 'usage': 'medium'},
    {'name': 'Plumber Visit', 'price': 500, 'frequency': 'occasional', 'usage': 'emergency'},
    {'name': 'Electrician Visit', 'price': 600, 'frequency': 'occasional', 'usage': 'emergency'},
    {'name': 'LED Light Bulb', 'price': 180, 'frequency': 'quarterly', 'usage': 'replacement'},
    {'name': 'Broom / Mop', 'price': 150, 'frequency': 'annual', 'usage': 'cleaning'},
    {'name': 'Garbage Bags (20pcs)', 'price': 80, 'frequency': 'monthly', 'usage': 'regular'},
    {'name': 'Cockroach Spray', 'price': 220, 'frequency': 'quarterly', 'usage': 'pest_control'},
    {'name': 'Water Filter Refill', 'price': 350, 'frequency': 'quarterly', 'usage': 'essential'},
    {'name': 'Phenyl Floor Cleaner', 'price': 248, 'frequency': 'monthly', 'usage': 'cleaning'},
    {'name': 'Electrical Tape', 'price': 116, 'frequency': 'occasional', 'usage': 'repair'},
    {'name': 'Paint (1L)', 'price': 450, 'frequency': 'annual', 'usage': 'maintenance'},
    {'name': 'Door Lock Repair', 'price': 400, 'frequency': 'occasional', 'usage': 'repair'},
    {'name': 'Window Repair', 'price': 350, 'frequency': 'occasional', 'usage': 'repair'},
    {'name': 'Plumbing Pipe (meter)', 'price': 200, 'frequency': 'occasional', 'usage': 'repair'},
]

# =========================================================
# PRICE PREDICTION MODEL
# =========================================================

class PricePredictionModel:
    """Simple ML model for price prediction based on item features"""
    
    def __init__(self, category: str, training_data: List[Dict]):
        self.category = category
        self.training_data = training_data
        self.model = None
        self.price_stats = {}
        self.feature_weights = {}
        
    def train(self):
        """Train the model on training data, including external CSVs if available"""
        # Dynamically load meal data from CSVs if this is the meal category
        if self.category == 'meal':
            csv_data = self._load_from_food_dataset()
            if csv_data:
                logger.info(f"📈 Merging {len(csv_data)} items from CSV files into meal training data")
                self.training_data.extend(csv_data)

        if not self.training_data:
            logger.error(f"❌ No training data for {self.category}")
            return None
            
        self._perform_training()
        return self.model

    def _load_from_food_dataset(self) -> List[Dict]:
        """Loads meal items from CSV files using smart column detection"""
        items = []
        if not MEAL_DATA_SUBDIR.exists():
            logger.warning(f"⚠️ Food dataset folder not found at {MEAL_DATA_SUBDIR}")
            return items

        for csv_file in MEAL_DATA_SUBDIR.glob('*.csv'):
            try:
                # Attempt to read with common encodings (UTF-8 then Latin-1 for global datasets)
                try:
                    df = pd.read_csv(csv_file, encoding='utf-8')
                except UnicodeDecodeError:
                    df = pd.read_csv(csv_file, encoding='latin1')
                
                # Identify columns based on config keywords
                name_col = next((c for c in df.columns if c.lower() in ITEM_COL_KEYWORDS), None)
                price_col = next((c for c in df.columns if c.lower() in PRICE_COL_KEYWORDS), None)

                if not name_col or not price_col:
                    logger.warning(f"Skipping {csv_file.name}: Could not identify name or price columns.")
                    continue

                # Data Cleaning: Remove rows with missing prices and convert to numeric
                df[price_col] = pd.to_numeric(df[price_col], errors='coerce')
                df = df.dropna(subset=[name_col, price_col])

                # Convert to PKR (Assuming Kaggle food data is often USD or local, 
                # you can adjust the currency detection logic here)
                rate = get_exchange_rate('USD') # Defaulting to USD for global datasets

                for _, row in df.iterrows():
                    items.append({
                        'name': str(row[name_col]), 
                        'price': float(row[price_col]) * rate
                    })
                
                logger.info(f"✅ Successfully loaded {len(df)} meal items from {csv_file.name}")
            except Exception as e:
                logger.error(f"❌ Could not load {csv_file.name}: {e}")
        return items

    def _perform_training(self):
        """Train the model on training data"""
        logger.info(f"🤖 Training {self.category.upper()} price prediction model...")
        
        # Extract prices
        prices = [item['price'] for item in self.training_data]
        
        # Calculate statistics
        self.price_stats = {
            'mean': float(np.mean(prices)),
            'median': float(np.median(prices)),
            'std': float(np.std(prices)),
            'min': float(np.min(prices)),
            'max': float(np.max(prices)),
            'count': len(prices)
        }
        
        # Learn feature weights based on category characteristics
        self._learn_feature_weights()
        
        self.model = {
            'category': self.category,
            'stats': self.price_stats,
            'feature_weights': self.feature_weights,
            'training_samples': len(self.training_data),
            'trained_at': datetime.now().isoformat()
        }
        
        logger.info(f"✅ {self.category.upper()} model trained:")
        logger.info(f"   Samples: {self.price_stats['count']}")
        logger.info(f"   Price range: Rs {self.price_stats['min']:.0f} - Rs {self.price_stats['max']:.0f}")
        logger.info(f"   Average: Rs {self.price_stats['mean']:.0f}")
        
        return self.model
    
    def _learn_feature_weights(self):
        """Learn feature importance based on category"""
        if self.category == 'meal':
            self.feature_weights = {
                'protein': 0.3,
                'calories': 0.25,
                'freshness': 0.2,
                'brand': 0.15,
                'preparation': 0.1
            }
        elif self.category == 'laundry':
            self.feature_weights = {
                'concentration': 0.4,
                'brand': 0.25,
                'capacity': 0.2,
                'eco_friendly': 0.1,
                'fragrance': 0.05
            }
        else:  # maintenance
            self.feature_weights = {
                'frequency': 0.3,
                'urgency': 0.3,
                'labor_cost': 0.2,
                'material_cost': 0.15,
                'complexity': 0.05
            }
    
    def predict_budget_allocation(self, total_budget: float, days: int) -> List[Dict]:
        """Predict optimal budget allocation and items for given budget"""
        daily_budget = total_budget / days
        
        # Filter affordable items
        affordable = [
            item for item in self.training_data 
            if item['price'] <= daily_budget * 1.5
        ]
        
        if not affordable:
            affordable = [min(self.training_data, key=lambda x: x['price'])]
        
        # Sort by price
        affordable = sorted(affordable, key=lambda x: x['price'])
        
        return affordable[:5]  # Return top 5 affordable items

# =========================================================
# TRAINING PIPELINE
# =========================================================

def train_all_models() -> Dict:
    """Train all models and save results"""
    logger.info("=" * 60)
    logger.info("🚀 Starting Model Training Pipeline")
    logger.info("=" * 60)
    
    # Create model directory
    MODEL_DIR.mkdir(exist_ok=True)
    
    trained_models = {}
    
    # Train Meal Model
    meal_model = PricePredictionModel('meal', MEAL_TRAINING_DATA)
    meal_model.train()
    trained_models['meal'] = {
        'model': meal_model.model,
        'items': MEAL_TRAINING_DATA
    }
    
    # Train Laundry Model
    laundry_model = PricePredictionModel('laundry', LAUNDRY_TRAINING_DATA)
    laundry_model.train()
    trained_models['laundry'] = {
        'model': laundry_model.model,
        'items': LAUNDRY_TRAINING_DATA
    }
    
    # Train Maintenance Model
    maintenance_model = PricePredictionModel('maintenance', MAINTENANCE_TRAINING_DATA)
    maintenance_model.train()
    trained_models['maintenance'] = {
        'model': maintenance_model.model,
        'items': MAINTENANCE_TRAINING_DATA
    }
    
    # Save trained models
    save_trained_models(trained_models)
    
    # Export as JSON for Flask API
    export_trained_data(trained_models)
    
    logger.info("=" * 60)
    logger.info("✅ All models trained and saved successfully")
    logger.info("=" * 60)
    
    return trained_models

def save_trained_models(models: Dict):
    """Save trained models as pickle files"""
    for category, data in models.items():
        filepath = MODEL_DIR / f'{category}_model.pkl'
        with open(filepath, 'wb') as f:
            pickle.dump(data['model'], f)
        logger.info(f"💾 Saved: {filepath}")

def export_trained_data(models: Dict):
    """Export trained data as JSON for Flask API"""
    export_data = {
        'metadata': {
            'trained_at': datetime.now().isoformat(),
            'version': '1.0.0',
            'models': {}
        },
        'datasets': {}
    }
    
    for category, data in models.items():
        # Store model stats
        export_data['metadata']['models'][category] = data['model']
        
        # Store items
        export_data['datasets'][category] = data['items']
    
    # Save as JSON
    filepath = MODEL_DIR / 'trained_data.json'
    with open(filepath, 'w') as f:
        json.dump(export_data, f, indent=2, default=str)
    
    logger.info(f"📊 Exported: {filepath}")
    
    return export_data

def load_trained_data() -> Dict:
    """Load trained data from JSON"""
    filepath = MODEL_DIR / 'trained_data.json'
    
    if not filepath.exists():
        logger.warning(f"⚠️  Trained data not found at {filepath}")
        logger.info("🤖 Running training pipeline...")
        train_all_models()
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    logger.info(f"✅ Loaded trained data from {filepath}")
    return data

def load_trained_model(category: str):
    """Load a specific trained model"""
    filepath = MODEL_DIR / f'{category}_model.pkl'
    
    if not filepath.exists():
        logger.warning(f"⚠️  Model not found: {filepath}")
        return None
    
    with open(filepath, 'rb') as f:
        model = pickle.load(f)
    
    logger.info(f"✅ Loaded model: {category}")
    return model

# =========================================================
# MAIN EXECUTION
# =========================================================

if __name__ == '__main__':
    # Train all models
    trained_models = train_all_models()
    
    # Test loading
    logger.info("\n🧪 Testing model loading...")
    trained_data = load_trained_data()
    
    logger.info("\n📊 Trained Datasets Summary:")
    for category, items in trained_data['datasets'].items():
        logger.info(f"   {category.upper()}: {len(items)} items")
    
    logger.info("\n✨ Model training pipeline completed successfully!")
