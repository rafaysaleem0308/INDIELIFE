import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

/// Service to interact with Flask AI Budget Recommendation API
class AIBudgetService {
  static const String _configuredAIBaseUrl =
      'https://indielife-ai-model.onrender.com';

  static String get flaskBaseUrl => _configuredAIBaseUrl;

  /// Get AI budget recommendation based on budget, days, and category
  static Future<Map<String, dynamic>> getAIRecommendation({
    required double budget,
    required int days,
    required String category,
  }) async {
    try {
      debugPrint('🤖 Fetching AI recommendation from Flask API');
      debugPrint('Budget: Rs $budget, Days: $days, Category: $category');

      final response = await http
          .post(
            Uri.parse('$flaskBaseUrl/api/ai-budget-recommendation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'budget': budget,
              'days': days,
              'category': category,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          ); // Increased for large Kaggle datasets

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ AI Recommendation received successfully');
          return {
            'success': true,
            'plan': data['plan'] ?? {},
            'recommendations': data['recommendations'] ?? [],
            'insights': data['insights'] ?? {},
            'statistics': data['statistics'] ?? {},
          };
        } else {
          return {
            'success': false,
            'error': data['error'] ?? 'Unknown error from AI service',
          };
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid request parameters',
        };
      } else {
        return {
          'success': false,
          'error': 'Server error (${response.statusCode})',
        };
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Cannot connect to AI service. Please check your connection.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      return {
        'success': false,
        'error': 'Request timeout. AI service is taking too long.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Get AI budget plan from natural language text.
  /// Example input: "I have 5000 PKR for 2 weeks for meals"
  static Future<Map<String, dynamic>> getAIRecommendationFromText({
    required String text,
  }) async {
    try {
      debugPrint('🤖 Fetching AI recommendation from text input');
      debugPrint('Input: $text');

      final response = await http
          .post(
            Uri.parse('$flaskBaseUrl/api/chat-plan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('Response Status: ${response.statusCode}');

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'plan': data['plan'] ?? {},
          'chat_messages': data['chat_messages'] ?? [],
          'nlp_analysis': data['nlp_analysis'] ?? {},
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Could not process your request',
        'suggestion': data['suggestion'],
      };
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Cannot connect to AI service. Please check your connection.',
        'isNetworkError': true,
      };
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      return {
        'success': false,
        'error': 'Request timeout. AI service is taking too long.',
        'isNetworkError': true,
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  /// Get all available datasets/items for a category
  static Future<Map<String, dynamic>> getCategoryDataset(
    String category,
  ) async {
    try {
      debugPrint('📊 Fetching $category dataset');

      final response = await http
          .get(
            Uri.parse('$flaskBaseUrl/api/datasets/$category'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': true,
          'category': data['category'] ?? category,
          'items': data['items'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {'success': false, 'error': 'Failed to fetch dataset'};
      }
    } catch (e) {
      debugPrint('❌ Error fetching dataset: $e');
      return {
        'success': false,
        'error': 'An error occurred while fetching data',
      };
    }
  }

  /// Get statistics for all categories
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      debugPrint('📈 Fetching statistics');

      final response = await http
          .get(
            Uri.parse('$flaskBaseUrl/api/stats'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 60),
          ); // Increased timeout for heavy data

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {'success': true, 'statistics': data};
      } else {
        return {'success': false, 'error': 'Failed to fetch statistics'};
      }
    } catch (e) {
      debugPrint('❌ Error fetching statistics: $e');
      return {'success': false, 'error': 'An error occurred'};
    }
  }

  /// Check if Flask API is healthy
  static Future<bool> isAPIHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$flaskBaseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️  API health check failed: $e');
      return false;
    }
  }
}
