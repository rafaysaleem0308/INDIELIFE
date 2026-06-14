"""
═══════════════════════════════════════════════════════════════════════════════
  CONFIG.PY — Centralized Configuration for AI Expense Planner
  
  All magic numbers, constants, and settings in one place for easy maintenance.
═══════════════════════════════════════════════════════════════════════════════
"""

# ────────────────────────────────────────────────────────────────────────────
# 1. EXCHANGE RATES (Update these if currency rates change)
# ────────────────────────────────────────────────────────────────────────────
EXCHANGE_RATES = {
    'INR_TO_PKR': 3.3,      # 1 Indian Rupee = 3.3 Pakistani Rupees
    'USD_TO_PKR': 278.0,    # 1 US Dollar = 278 Pakistani Rupees
    'PRIMARY_CURRENCY': 'PKR',  # All calculations in PKR
}

# ────────────────────────────────────────────────────────────────────────────
# 2. EXPENSE CATEGORIES & METADATA
# ────────────────────────────────────────────────────────────────────────────
CATEGORIES = {
    'meal': {
        'label': 'Meal',
        'icon': '🍱',
        'color': '0xFF2ECC71',
        'expected_currency': 'USD',  # Global Food Prices dataset
        'max_items_per_day': 3,
        'description': 'Food & Grocery Expenses',
    },
    'laundry': {
        'label': 'Laundry',
        'icon': '🧺',
        'color': '0xFF3498DB',
        'expected_currency': 'INR',  # Supermart dataset
        'max_items_per_day': 2,
        'description': 'Washing, Detergents, Cleaning Supplies',
    },
    'maintenance': {
        'label': 'Maintenance',
        'icon': '🔧',
        'color': '0xFFE74C3C',
        'expected_currency': 'USD',  # Personal Expense dataset
        'max_items_per_day': 2,
        'description': 'Home Repairs, Utilities, Household Maintenance',
    },
}

# ────────────────────────────────────────────────────────────────────────────
# 3. KAGGLE DATASET MAPPINGS (Automatic assignment via keywords)
# ────────────────────────────────────────────────────────────────────────────
CATEGORY_KEYWORDS = {
    'meal': [
        'food', 'meal', 'grocery', 'groceries', 'price', 'india',
        'rice', 'vegetable', 'fruit', 'nutrition', 'diet', 'market',
        'commodity', 'agriculture', 'wfp', 'wfpvam', 'global_food',
        'food_price', 'foodprice', 'cereal', 'produce'
    ],
    'laundry': [
        'supermart', 'supermarket', 'laundry', 'detergent', 'soap',
        'retail', 'sales', 'product', 'cleaning', 'fmcg', 'store',
        'shop', 'merchandise', 'consumer'
    ],
    'maintenance': [
        'maintenance', 'electricity', 'device', 'utility', 'power',
        'energy', 'home', 'appliance', 'repair', 'bill', 'expense',
        'expenditure', 'personal_expense', 'spending', 'household'
    ],
}

# ────────────────────────────────────────────────────────────────────────────
# 4. COLUMN DETECTION KEYWORDS (Smart CSV Reader)
# ────────────────────────────────────────────────────────────────────────────
PRICE_COL_KEYWORDS = [
    'price', 'cost', 'rate', 'unit price', 'amount', 'value', 'sales', 'usdprice'
]

ITEM_COL_KEYWORDS = [
    'item', 'name', 'product', 'commodity', 'description', 'food',
    'label', 'cmname', 'category', 'sub category', 'subcategory', 'mktname'
]

CURRENCY_COL_KEYWORDS = ['currency', 'curr', 'cur']

# ────────────────────────────────────────────────────────────────────────────
# 5. PLANNING & BUDGET CONSTRAINTS
# ────────────────────────────────────────────────────────────────────────────
PLANNER_CONFIG = {
    'BUDGET_BUFFER': 1.3,           # Allow items up to 130% of daily budget
    'MAX_ITEMS_PREVIEW': 50,        # Limit dataset to first 50 cheapest items
    'MIN_BUDGET': 100.0,            # Minimum sensible budget (PKR)
    'MIN_DAYS': 1,                  # Minimum duration
    'MAX_DAYS': 365,                # Maximum duration
}

# ────────────────────────────────────────────────────────────────────────────
# 6. LOGGING CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────
LOGGING_CONFIG = {
    'level': 'INFO',                # DEBUG, INFO, WARNING, ERROR, CRITICAL
    'format': '%(asctime)s [%(levelname)s] %(message)s',
    'datefmt': '%Y-%m-%d %H:%M:%S',
}

# ────────────────────────────────────────────────────────────────────────────
# 7. ERROR MESSAGES (User-friendly, localized if needed)
# ────────────────────────────────────────────────────────────────────────────
ERROR_MESSAGES = {
    'BUDGET_MISSING': (
        '❌ **Budget not detected.** '
        'Example: *"I have 2000 rupees for 2 weeks"*'
    ),
    'DURATION_MISSING': (
        '❌ **Duration not found.** '
        'Say *"2 weeks"* or *"10 days"* or *"1 month"*'
    ),
    'CATEGORY_MISSING': (
        '❌ **Category not mentioned.** '
        'Say *"meal"*, *"laundry"*, or *"maintenance"*'
    ),
    'BUDGET_TOO_LOW': (
        f'❌ **Budget too low.** Minimum is Rs {PLANNER_CONFIG["MIN_BUDGET"]:.0f}'
    ),
    'DAYS_INVALID': (
        f'❌ **Duration invalid.** Must be 1-{PLANNER_CONFIG["MAX_DAYS"]} days'
    ),
    'NO_DATA': (
        '❌ **No dataset available.** Check files exist and are readable.'
    ),
    'API_KEY_MISSING': (
        '⚠️ **ANTHROPIC_API_KEY not found.** Using Python planner instead.'
    ),
    'API_ERROR': (
        '❌ **Claude API error.** Falling back to Python planner.'
    ),
}

# ────────────────────────────────────────────────────────────────────────────
# 8. KAGGLE DATASET INFO (For documentation & debugging)
# ────────────────────────────────────────────────────────────────────────────
KAGGLE_DATASETS = {
    'jboysen/global-food-prices': {
        'category': 'meal',
        'name': 'Global Food Prices Database',
        'link': 'https://www.kaggle.com/datasets/jboysen/global-food-prices',
        'key_columns': {'item': 'cmname', 'price': 'price'},
        'currency': 'USD',
    },
    # NEW: Adding a second meal dataset as requested.
    # Replace with an actual Kaggle dataset if available, or a local CSV path.
    'indian-food-prices-dataset': {
        'category': 'meal',
        'name': 'Indian Food Prices (Hypothetical)',
        'link': 'https://www.kaggle.com/datasets/example/indian-food-prices', # Placeholder link
        'key_columns': {'item': 'item_name', 'price': 'price_inr'}, # Adjust column names as per actual dataset
        'currency': 'INR',
    },
    'mohamedharris/supermart-grocery-sales-retail-analytics-dataset': {
        'category': 'laundry',
        'name': 'Supermart Grocery Sales',
        'link': 'https://www.kaggle.com/datasets/mohamedharris/supermart-grocery-sales-retail-analytics-dataset',
        'key_columns': {'item': 'Sub Category', 'price': 'Sales'},
        'currency': 'INR',
    },
    'sahideseker/personal-expense-classification-dataset': {
        'category': 'maintenance',
        'name': 'Personal Expense Classification',
        'link': 'https://www.kaggle.com/datasets/sahideseker/personal-expense-classification-dataset',
        'key_columns': {'item': 'Category', 'price': 'Amount'},
        'currency': 'USD',
    },
}

# ────────────────────────────────────────────────────────────────────────────
# 9. HELPER FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────

def get_category_config(category: str) -> dict:
    """Get metadata for a specific category."""
    if category not in CATEGORIES:
        raise ValueError(f"Unknown category: {category}")
    return CATEGORIES[category]


def get_exchange_rate(currency: str) -> float:
    """Get exchange rate to PKR for a given currency."""
    currency = currency.upper().strip()
    if currency == 'PKR':
        return 1.0
    if currency == 'INR':
        return EXCHANGE_RATES['INR_TO_PKR']
    if currency == 'USD':
        return EXCHANGE_RATES['USD_TO_PKR']
    return 1.0  # Default: assume PKR


def validate_budget(budget: float) -> tuple[bool, str]:
    """Validate budget value."""
    if budget is None:
        return False, ERROR_MESSAGES['BUDGET_MISSING']
    try:
        budget = float(budget)
    except (ValueError, TypeError):
        return False, ERROR_MESSAGES['BUDGET_MISSING']
    if budget <= 0:
        return False, f"Budget must be positive, got Rs {budget:.2f}"
    if budget < PLANNER_CONFIG['MIN_BUDGET']:
        return False, ERROR_MESSAGES['BUDGET_TOO_LOW']
    return True, ""


def validate_days(days: int) -> tuple[bool, str]:
    """Validate duration in days."""
    if days is None:
        return False, ERROR_MESSAGES['DURATION_MISSING']
    try:
        days = int(days)
    except (ValueError, TypeError):
        return False, ERROR_MESSAGES['DURATION_MISSING']
    if days <= 0:
        return False, f"Days must be positive, got {days}"
    if days > PLANNER_CONFIG['MAX_DAYS']:
        return False, ERROR_MESSAGES['DAYS_INVALID']
    return True, ""


def validate_category(category: str) -> tuple[bool, str]:
    """Validate expense category."""
    if category is None:
        return False, ERROR_MESSAGES['CATEGORY_MISSING']
    if category not in CATEGORIES:
        return False, ERROR_MESSAGES['CATEGORY_MISSING']
    return True, ""


# ────────────────────────────────────────────────────────────────────────────
# 10. PRINT CONFIGURATION ON IMPORT (For debugging)
# ────────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("✅ Config module loaded successfully")
    print(f"   Exchange rates: 1 INR = {EXCHANGE_RATES['INR_TO_PKR']} PKR | 1 USD = {EXCHANGE_RATES['USD_TO_PKR']} PKR")
    print(f"   Categories: {', '.join(CATEGORIES.keys())}")
    print(f"   Datasets: {len(KAGGLE_DATASETS)} Kaggle datasets configured")
