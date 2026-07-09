import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/core/services/session_manager.dart';
import 'dart:io';
import 'dart:async';

// ─── RESPONSE VALIDATION CLASS ─────────────────────────────────────────────
class ApiResponse {
  static Map<String, dynamic> validate(
    dynamic responseData, {
    List<String>? requiredFields,
  }) {
    // Null check
    if (responseData == null) {
      return {'isValid': false, 'error': 'Response is null', 'data': {}};
    }

    // Type check - must be Map
    if (responseData is! Map) {
      return {'isValid': false, 'error': 'Response format invalid', 'data': {}};
    }

    // Check required fields
    if (requiredFields != null) {
      for (String field in requiredFields) {
        if (!responseData.containsKey(field) || responseData[field] == null) {
          return {
            'isValid': false,
            'error': 'Missing required field: $field',
            'data': {},
          };
        }
      }
    }

    return {'isValid': true, 'error': null, 'data': responseData};
  }

  static dynamic safeGet(
    Map<String, dynamic> map,
    String key, {
    dynamic defaultValue,
  }) {
    return map.containsKey(key) && map[key] != null ? map[key] : defaultValue;
  }
}

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceAll(RegExp(r'/$'), '');
    }

    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000";
    }
    return "http://localhost:3000";
  }

  static String resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return '';
    final trimmed = imageUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$baseUrl$normalizedPath';
  }

  // ================================
  // OTP SIGNUP FUNCTIONS
  // ================================

  // --------------------- SEND OTP FOR SIGNUP ---------------------
  static Future<Map<String, dynamic>> sendOtpSignup(
    String email,
    String role,
  ) async {
    try {
      print("Sending OTP for signup: $email, role: $role");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp-signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'role': role}),
      ).timeout(const Duration(seconds: 20));

      print("Send OTP status: ${response.statusCode}");
      print("Send OTP body: ${response.body}");

      final responseData = json.decode(response.body);

      // ─── VALIDATE RESPONSE ─────────────────────────────────────────
      final validation = ApiResponse.validate(
        responseData,
        requiredFields: ['status', 'message'],
      );

      if (!validation['isValid']) {
        return {
          'status': 'error',
          'message': validation['error'] ?? 'Invalid response format',
        };
      }

      return {
        'status': ApiResponse.safeGet(
          responseData,
          'status',
          defaultValue: 'error',
        ),
        'message': ApiResponse.safeGet(
          responseData,
          'message',
          defaultValue: 'Failed to send OTP',
        ),
        'suggestion': ApiResponse.safeGet(
          responseData,
          'suggestion',
          defaultValue: null,
        ),
        'existingAccountType': ApiResponse.safeGet(
          responseData,
          'existingAccountType',
          defaultValue: null,
        ),
      };
    } catch (error) {
      print("Send OTP error: $error");
      return {
        'status': 'error',
        'message':
            'OTP email is taking too long. Please try again in a moment.',
      };
    }
  }

  // ==================== JWT TOKEN DECODING ====================
  // ==================== JWT TOKEN DECODING ====================
  static Future<Map<String, dynamic>> decodeJwtToken() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {};
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        return {};
      }

      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = json.decode(decoded);

      print('Decoded token payload: $payloadMap');

      // FIX: Extract the correct user ID field
      final userId =
          payloadMap['userId'] ?? payloadMap['id'] ?? payloadMap['_id'];
      final username =
          payloadMap['username'] ??
          payloadMap['firstName'] ??
          payloadMap['name'] ??
          '';

      return {
        '_id': userId ?? '',
        'userId': userId ?? '',
        'id': userId ?? '',
        'firstName': payloadMap['firstName'] ?? '',
        'lastName': payloadMap['lastName'] ?? '',
        'email': payloadMap['email'] ?? '',
        'phone': payloadMap['phone'] ?? '',
        'city': payloadMap['city'] ?? '',
        'role': payloadMap['role'] ?? '',
        'spSubRole': payloadMap['spSubRole'] ?? '',
        'username': username,
      };
    } catch (e) {
      print('Error decoding token: $e');
      return {};
    }
  }

  // --------------------- VERIFY OTP FOR SIGNUP ---------------------
  static Future<Map<String, dynamic>> verifyOtpSignup(
    String email,
    String otp,
  ) async {
    try {
      print("Verifying OTP for: $email");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp-signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      ).timeout(const Duration(seconds: 20));

      print("Verify OTP status: ${response.statusCode}");
      print("Verify OTP body: ${response.body}");

      final responseData = json.decode(response.body);

      // ─── VALIDATE RESPONSE ─────────────────────────────────────────
      final validation = ApiResponse.validate(
        responseData,
        requiredFields: ['status', 'message'],
      );

      if (!validation['isValid']) {
        return {
          'status': 'error',
          'message': validation['error'] ?? 'Invalid response format',
        };
      }

      return {
        'status': ApiResponse.safeGet(
          responseData,
          'status',
          defaultValue: 'error',
        ),
        'message': ApiResponse.safeGet(
          responseData,
          'message',
          defaultValue: 'Failed to verify OTP',
        ),
        'role': ApiResponse.safeGet(responseData, 'role', defaultValue: ''),
      };
    } catch (error) {
      print("Verify OTP error: $error");
      return {
        'status': 'error',
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // ================================
  // USER & SERVICE PROVIDER SIGNUP
  // ================================

  // --------------------- USER SIGNUP ---------------------
  static Future<Map<String, dynamic>> userSignup(
    Map<String, dynamic> userData,
  ) async {
    try {
      print("Attempting user signup for: ${userData['email']}");

      final response = await http.post(
        Uri.parse('$baseUrl/signup/user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      print("User signup status: ${response.statusCode}");
      print("User signup body: ${response.body}");

      final responseData = json.decode(response.body);

      // ─── VALIDATE RESPONSE ─────────────────────────────────────────
      final validation = ApiResponse.validate(responseData);
      if (!validation['isValid']) {
        return {
          'success': false,
          'message': validation['error'] ?? 'Invalid response format',
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (ApiResponse.safeGet(responseData, 'success', defaultValue: true)) {
          final token =
              ApiResponse.safeGet(responseData, 'token') ??
              ApiResponse.safeGet(responseData, 'accessToken');

          if (token != null) {
            await _saveToken(token);
          }

          final user = ApiResponse.safeGet(
            responseData,
            'user',
            defaultValue: {},
          );
          if (user.isNotEmpty) {
            await saveUserSession(user);
          }

          // Save to SessionManager for persistent login
          if (token != null) {
            await SessionManager.createSession(
              accessToken: token,
              refreshToken: ApiResponse.safeGet(
                responseData,
                'refreshToken',
                defaultValue: '',
              ),
              userData: user,
            );
          }

          return {
            'success': true,
            'message': ApiResponse.safeGet(
              responseData,
              'message',
              defaultValue: 'User registered successfully',
            ),
            'token': token,
            'user': user,
          };
        } else {
          return {
            'success': false,
            'message':
                ApiResponse.safeGet(responseData, 'error') ??
                ApiResponse.safeGet(
                  responseData,
                  'message',
                  defaultValue: 'User registration failed',
                ),
          };
        }
      } else {
        return {
          'success': false,
          'message':
              ApiResponse.safeGet(responseData, 'error') ??
              ApiResponse.safeGet(
                responseData,
                'message',
                defaultValue: 'User registration failed',
              ),
        };
      }
    } catch (error) {
      print("User signup error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // --------------------- SERVICE PROVIDER SIGNUP ---------------------
  static Future<Map<String, dynamic>> serviceProviderSignup(
    Map<String, dynamic> spData,
  ) async {
    try {
      print("Attempting service provider signup for: ${spData['email']}");

      // Add district fields to the data
      final spDataWithDistrict = {
        ...spData,
        'districtName': spData['districtName'] ?? '',
        'districtNazim': spData['districtNazim'] ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/signup/service-provider'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(spDataWithDistrict),
      );

      print("Service provider signup status: ${response.statusCode}");
      print("Service provider signup body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (responseData['success'] != false) {
          if (responseData.containsKey('token')) {
            await _saveToken(responseData['token']);
          }
          if (responseData.containsKey('user')) {
            await saveUserSession(responseData['user']);
          }

          // Save to SessionManager for persistent login
          if (responseData['accessToken'] != null ||
              responseData['token'] != null) {
            await SessionManager.createSession(
              accessToken: responseData['accessToken'] ?? responseData['token'],
              refreshToken: responseData['refreshToken'] ?? '',
              userData: responseData['user'] ?? {},
            );
          }

          return {
            'success': true,
            'message':
                responseData['message'] ??
                'Service Provider registered successfully',
            'token': responseData['token'],
            'user': responseData['user'],
          };
        } else {
          return {
            'success': false,
            'message':
                responseData['error'] ?? 'Service Provider registration failed',
          };
        }
      } else {
        return {
          'success': false,
          'message':
              responseData['error'] ??
              responseData['message'] ??
              'Service Provider registration failed',
        };
      }
    } catch (error) {
      print("Service provider signup error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // --------------------- GENERIC SIGNUP (Handles both user and service provider) ---------------------
  static Future<Map<String, dynamic>> signup(
    Map<String, dynamic> data,
    String role,
  ) async {
    if (role == 'User') {
      return await userSignup(data);
    } else {
      return await serviceProviderSignup(data);
    }
  }

  // ================================
  // LOGIN (AUTO ROLE DETECTION)
  // ================================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      print("🔐 Attempting login for: $email");
      final normalizedEmail = email
          .toLowerCase()
          .trim(); // Normalize email before sending

      // First, try user login
      final userResponse = await http
          .post(
            Uri.parse('$baseUrl/signup/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': normalizedEmail, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print("👤 User login status: ${userResponse.statusCode}");
      print("👤 User login body: ${userResponse.body}");

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        if (userData['success'] == true) {
          final token = userData['token'] ?? userData['accessToken'];
          if (token != null) await _saveToken(token);
          await saveUserSession(userData['user']);

          // Save to SessionManager (new secure storage)
          if (userData['accessToken'] != null || userData['token'] != null) {
            await SessionManager.createSession(
              accessToken: userData['accessToken'] ?? userData['token'],
              refreshToken: userData['refreshToken'] ?? '',
              userData: userData['user'],
            );
          }

          // FIX: Convert role to lowercase for consistency
          final role =
              userData['user']['role']?.toString().toLowerCase() ?? 'user';

          return {
            'success': true,
            'message': userData['message'] ?? 'Login successful',
            'user': userData['user'],
            'role': role,
          };
        }
      }

      // If user login fails, try service provider login
      final spResponse = await http
          .post(
            Uri.parse('$baseUrl/signup/service-provider/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': normalizedEmail, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      print("🏢 Service provider login status: ${spResponse.statusCode}");
      print("🏢 Service provider login body: ${spResponse.body}");

      if (spResponse.statusCode == 200) {
        final spData = json.decode(spResponse.body);
        if (spData['success'] == true) {
          final token = spData['token'] ?? spData['accessToken'];
          if (token != null) await _saveToken(token);
          await saveUserSession(spData['user']);

          // Save to SessionManager (new secure storage)
          if (spData['accessToken'] != null || spData['token'] != null) {
            await SessionManager.createSession(
              accessToken: spData['accessToken'] ?? spData['token'],
              refreshToken: spData['refreshToken'] ?? '',
              userData: spData['user'],
            );
          }

          // FIX: Convert role to lowercase for consistency
          final role = 'service_provider';

          return {
            'success': true,
            'message': spData['message'] ?? 'Login successful',
            'user': spData['user'],
            'role': role,
          };
        } else {
          print("❌ Service provider login failed: ${spData['message']}");
        }
      } else {
        print("❌ Service provider login HTTP error: ${spResponse.statusCode}");
      }

      if (spResponse.statusCode != 200) {
        final errorData = json.decode(spResponse.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Invalid email or password',
          'statusCode': spResponse.statusCode,
        };
      }

      // If both fail, try to get more specific error
      if (userResponse.statusCode != 200) {
        final errorData = json.decode(userResponse.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Invalid email or password',
          'statusCode': userResponse.statusCode,
        };
      }

      print("❌ Both login attempts failed");
      return {'success': false, 'message': 'Invalid email or password'};
    } catch (error) {
      print("🔥 Login error detail: $error");

      String errorMessage = 'An unexpected error occurred. Please try again.';

      // Check for network-related strings in the error message
      final errorString = error.toString();
      if (errorString.contains('SocketException') ||
          errorString.contains('No route to host') ||
          errorString.contains('Connection refused')) {
        errorMessage =
            'Network Error: Cannot reach the server.\n\n'
            '• Ensure phone & PC are on the same Wi-Fi\n'
            '• Check if Windows Firewall allows port 3000\n'
            '• For Emulator: use 10.0.2.2. For physical: use your machine\'s IPv4';
      } else if (error is TimeoutException) {
        errorMessage =
            'Connection timed out. The server is taking too long to respond.';
      }

      return {'success': false, 'message': errorMessage};
    }
  }
  // ================================
  // SERVICE MANAGEMENT
  // ================================

  // --------------------- GET SERVICES FOR CURRENT SERVICE PROVIDER ---------------------
  static Future<List<Map<String, dynamic>>> getServices() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('$baseUrl/api/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get services status: ${response.statusCode}");
      print("Get services body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['services'] ?? []);
      } else {
        throw Exception('Failed to load services: ${response.statusCode}');
      }
    } catch (error) {
      print("Get services error: $error");
      return [];
    }
  }

  // --------------------- ADD SERVICE ---------------------
  // --------------------- ADD SERVICE GENERIC ---------------------
  static Future<Map<String, dynamic>> addService(
    Map<String, dynamic> serviceData,
  ) async {
    return _postService(serviceData);
  }

  // --------------------- SPECIFIC ADD SERVICE METHODS ---------------------
  static Future<Map<String, dynamic>> addHousingService(
    Map<String, dynamic> data,
  ) async {
    return _postService({
      ...data,
      'serviceType': 'Hostel/Flat Accommodation', // Enforce type
    });
  }

  static Future<Map<String, dynamic>> addMaintenanceService(
    Map<String, dynamic> data,
  ) async {
    return _postService({
      ...data,
      'serviceType': 'Maintenance', // Enforce type
    });
  }

  static Future<Map<String, dynamic>> addLaundryService(
    Map<String, dynamic> data,
  ) async {
    return _postService({
      ...data,
      'serviceType': 'Laundry', // Enforce type
    });
  }

  static Future<Map<String, dynamic>> addMealService(
    Map<String, dynamic> data,
  ) async {
    return _postService({
      ...data,
      'serviceType': 'Meal Provider', // Enforce type
    });
  }

  // Helper for posting service data
  static Future<Map<String, dynamic>> _postService(
    Map<String, dynamic> serviceData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/services'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(serviceData),
      );

      print("Add service status: ${response.statusCode}");
      print("Add service body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Service added successfully',
          'service': responseData['service'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to add service',
        };
      }
    } catch (error) {
      print("Add service error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // --------------------- DELETE SERVICE ---------------------
  static Future<Map<String, dynamic>> deleteService(String serviceId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};
      final response = await http.delete(
        Uri.parse('$baseUrl/api/services/$serviceId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = json.decode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- UPDATE SERVICE ---------------------
  static Future<Map<String, dynamic>> updateService(
    String serviceId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};
      final response = await http.put(
        Uri.parse('$baseUrl/api/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? '',
          'service': data['service'],
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- UPLOAD SERVICE IMAGE ---------------------
  static Future<Map<String, dynamic>> uploadServiceImage(
    String serviceId,
    File imageFile,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/services/$serviceId/upload-image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('serviceImage', imageFile.path),
      );
      var streamed = await request.send();
      var response = await http.Response.fromStream(streamed);
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'imageUrl': data['imageUrl'],
          'service': data['service'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- GET SERVICE BY ID ---------------------
  static Future<Map<String, dynamic>> getServiceById(String serviceId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'service': responseData['service']};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to fetch service',
        };
      }
    } catch (error) {
      print("Get service by ID error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // --------------------- GET SERVICES BY TYPE ---------------------
  static Future<List<Map<String, dynamic>>> getServicesByType(
    String serviceType,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/services/type/$serviceType'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['services'] ?? []);
      } else {
        throw Exception('Failed to load services by type');
      }
    } catch (error) {
      print("Get services by type error: $error");
      return [];
    }
  }

  // --------------------- SEARCH SERVICES ---------------------
  static Future<List<Map<String, dynamic>>> searchServices(
    String query,
    String? serviceType,
  ) async {
    try {
      String url = '$baseUrl/api/services/search?query=$query';
      if (serviceType != null && serviceType.isNotEmpty) {
        url += '&type=$serviceType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['services'] ?? []);
      } else {
        throw Exception('Failed to search services');
      }
    } catch (error) {
      print("Search services error: $error");
      return [];
    }
  }

  // --------------------- GET FEATURED SERVICES (RECOMMENDATIONS) ---------------------
  static Future<List<Map<String, dynamic>>> getFeaturedServices({
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/services/recommendations/featured?limit=$limit',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['services'] ?? []);
      } else {
        throw Exception('Failed to load featured services');
      }
    } catch (error) {
      print("Get featured services error: $error");
      return [];
    }
  }

  // --------------------- GET TOP RATED SERVICES ---------------------
  static Future<List<Map<String, dynamic>>> getTopRatedServices({
    int limit = 8,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/services/recommendations/top-rated?limit=$limit',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['services'] ?? []);
      } else {
        throw Exception('Failed to load top rated services');
      }
    } catch (error) {
      print("Get top rated services error: $error");
      return [];
    }
  }

  // --------------------- GET PERSONALIZED RECOMMENDATIONS ---------------------
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    int limit = 10,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('$baseUrl/api/recommendations/personalized?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(
          responseData['recommendations'] ?? [],
        );
      } else {
        throw Exception('Failed to load personalized recommendations');
      }
    } catch (error) {
      print("Get personalized recommendations error: $error");
      return [];
    }
  }

  // --------------------- TRACK USER INTERACTION ---------------------
  static Future<bool> trackInteraction({
    required String interactionType,
    String? serviceId,
    String? serviceType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/recommendations/track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'interactionType': interactionType,
          'serviceId': serviceId,
          'serviceType': serviceType,
          'metadata': metadata,
        }),
      );

      return response.statusCode == 201;
    } catch (error) {
      print("Track interaction error: $error");
      return false;
    }
  }

  // ================================
  // FORGOT PASSWORD
  // ================================

  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final responseData = json.decode(response.body);

      return response.statusCode == 200
          ? {
              'success': true,
              'message': responseData['message'] ?? 'OTP sent successfully',
            }
          : {
              'success': false,
              'message': responseData['message'] ?? 'Failed to send OTP',
            };
    } catch (error) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );
      final responseData = json.decode(response.body);

      return response.statusCode == 200 && responseData['status'] == 'verified'
          ? {
              'success': true,
              'message': responseData['message'] ?? 'OTP verified successfully',
            }
          : {
              'success': false,
              'message': responseData['message'] ?? 'Invalid OTP',
            };
    } catch (error) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'newPassword': newPassword}),
      );
      final responseData = json.decode(response.body);

      return response.statusCode == 200 && responseData['status'] == 'success'
          ? {
              'success': true,
              'message':
                  responseData['message'] ?? 'Password reset successfully',
            }
          : {
              'success': false,
              'message': responseData['message'] ?? 'Password reset failed',
            };
    } catch (error) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // ================================
  // MEAL PROVIDER SPECIFIC METHODS
  // ================================

  // GET ALL MEAL PROVIDERS
  // static Future<Map<String, dynamic>> getMealProviders({
  //   String? city,
  //   String? cuisine,
  //   double? minRating,
  //   String sortBy = 'rating',
  //   String sortOrder = 'desc',
  // }) async {
  //   try {
  //     // Build query parameters
  //     final params = <String, String>{};
  //     if (city != null && city.isNotEmpty) params['city'] = city;
  //     if (cuisine != null && cuisine.isNotEmpty) params['cuisine'] = cuisine;
  //     if (minRating != null) params['minRating'] = minRating.toString();
  //     params['sortBy'] = sortBy;
  //     params['sortOrder'] = sortOrder;

  //     final uri = Uri.parse(
  //       '$baseUrl/api/services/meal-providers',
  //     ).replace(queryParameters: params);

  //     print("Fetching meal providers from: ${uri.toString()}");

  //     final response = await http.get(
  //       uri,
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     print("Get meal providers status: ${response.statusCode}");
  //     print("Get meal providers body: ${response.body}");

  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //       return {
  //         'success': true,
  //         'mealProviders': responseData['mealProviders'] ?? [],
  //         'total': responseData['total'] ?? 0,
  //       };
  //     } else {
  //       final errorData = json.decode(response.body);
  //       return {
  //         'success': false,
  //         'message': errorData['message'] ?? 'Failed to fetch meal providers',
  //       };
  //     }
  //   } catch (error) {
  //     print("Get meal providers error: $error");
  //     return {
  //       'success': false,
  //       'message': 'Network error: Please check your connection',
  //     };
  //   }
  // }
  static Future<Map<String, dynamic>> getMealProviders({
    String? city,
    String? cuisine,
    double? minRating,
    String sortBy = 'rating',
    String sortOrder = 'desc',
  }) async {
    try {
      // Build query parameters
      final params = <String, String>{};
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (cuisine != null && cuisine.isNotEmpty) params['cuisine'] = cuisine;
      if (minRating != null) params['minRating'] = minRating.toString();
      params['sortBy'] = sortBy;
      params['sortOrder'] = sortOrder;

      final uri = Uri.parse(
        '$baseUrl/api/services/meal-providers',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'mealProviders': responseData['mealProviders'] ?? [],
          'total': responseData['total'] ?? 0,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch meal providers',
        };
      }
    } catch (error) {
      print("Get meal providers error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }
  // Add these methods to your existing ApiService class in api_service.dart

  // Get service provider by ID
  static Future<Map<String, dynamic>> getServiceProviderById(
    String spId,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/signup/service-provider/by-user/$spId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get service provider by ID status: ${response.statusCode}");
      print("Get service provider by ID body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'provider': responseData['serviceProvider']};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to fetch provider',
        };
      }
    } catch (error) {
      print("Get service provider by ID error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // Get user by ID
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/signup/user/profile/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get user by ID status: ${response.statusCode}");
      print("Get user by ID body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': responseData['user']};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to fetch user',
        };
      }
    } catch (error) {
      print("Get user by ID error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // Get meal provider with user ID
  static Future<Map<String, dynamic>> getMealProviderWithUserId(
    String spId,
  ) async {
    try {
      // First try to get service provider details
      final spResult = await getServiceProviderById(spId);

      if (spResult['success'] == true && spResult['provider'] != null) {
        final provider = spResult['provider'];

        // If provider has userId, get the user details
        if (provider['userId'] != null) {
          final userResult = await getUserById(provider['userId'].toString());

          if (userResult['success'] == true && userResult['user'] != null) {
            return {
              'success': true,
              'provider': provider,
              'user': userResult['user'],
            };
          }
        }

        return {'success': true, 'provider': provider, 'user': null};
      }

      return spResult;
    } catch (error) {
      print("Get meal provider with user ID error: $error");
      return {
        'success': false,
        'message': 'Error fetching provider data: $error',
      };
    }
  }

  // GET SPECIFIC MEAL PROVIDER WITH MEALS
  static Future<Map<String, dynamic>> getMealProviderDetails(
    String providerId,
  ) async {
    try {
      print("Fetching meal provider details for: $providerId");

      final response = await http.get(
        Uri.parse('$baseUrl/api/services/meal-provider/$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      print("Get meal provider details status: ${response.statusCode}");
      print("Get meal provider details body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'provider': responseData['provider'],
          'meals': responseData['meals'] ?? [],
          'totalMeals': responseData['totalMeals'] ?? 0,
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Meal provider not found'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to fetch meal provider details',
        };
      }
    } catch (error) {
      print("Get meal provider details error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET ALL MEALS (BROWSING)
  static Future<Map<String, dynamic>> getAllMeals({
    String? cuisine,
    String? mealType,
    double? minPrice,
    double? maxPrice,
    bool? isVegetarian,
    String? city,
    String sortBy = 'rating',
    String sortOrder = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Build query parameters
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

      if (cuisine != null && cuisine.isNotEmpty) params['cuisine'] = cuisine;
      if (mealType != null && mealType.isNotEmpty) {
        params['mealType'] = mealType;
      }
      if (minPrice != null) params['minPrice'] = minPrice.toString();
      if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
      if (isVegetarian != null) {
        params['isVegetarian'] = isVegetarian.toString();
      }
      if (city != null && city.isNotEmpty) params['city'] = city;

      final uri = Uri.parse(
        '$baseUrl/api/services/meals',
      ).replace(queryParameters: params);

      print("Fetching meals from: ${uri.toString()}");

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print("Get meals status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'meals': responseData['meals'] ?? [],
          'total': responseData['total'] ?? 0,
          'page': responseData['page'] ?? 1,
          'totalPages': responseData['totalPages'] ?? 1,
          'hasMore': responseData['hasMore'] ?? false,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch meals',
        };
      }
    } catch (error) {
      print("Get meals error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // UPDATE MEAL SERVICE
  static Future<Map<String, dynamic>> updateMealService(
    String serviceId,
    Map<String, dynamic> mealData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(mealData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Meal updated successfully',
          'service': responseData['service'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update meal',
        };
      }
    } catch (error) {
      print("Update meal service error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // DELETE MEAL SERVICE
  static Future<Map<String, dynamic>> deleteMealService(
    String serviceId,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/services/$serviceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Meal deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to delete meal',
        };
      }
    } catch (error) {
      print("Delete meal service error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // SEARCH MEALS
  static Future<Map<String, dynamic>> searchMeals(
    String query, {
    String? cuisine,
    String? city,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      // Build query parameters
      final params = <String, String>{'query': query};
      if (cuisine != null && cuisine.isNotEmpty) params['cuisine'] = cuisine;
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (minPrice != null) params['minPrice'] = minPrice.toString();
      if (maxPrice != null) params['maxPrice'] = maxPrice.toString();

      final uri = Uri.parse(
        '$baseUrl/api/services/search',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Filter to only include meal providers
        final meals =
            List<Map<String, dynamic>>.from(responseData['services'] ?? [])
                .where((service) => service['serviceType'] == 'Meal Provider')
                .toList();

        return {'success': true, 'meals': meals, 'total': meals.length};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to search meals',
        };
      }
    } catch (error) {
      print("Search meals error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  static Future<Map<String, dynamic>> placeOrder(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      print('Sending order data: ${json.encode(orderData)}');

      // Use the /create endpoint instead of root /
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(orderData),
      );

      print('Order response status: ${response.statusCode}');
      print('Order response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'order': data['order'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to place order',
        };
      }
    } catch (e) {
      print('Place order error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- CREATE HIRE REQUEST ---------------------
  static Future<Map<String, dynamic>> createHireRequest(
    Map<String, dynamic> hireData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      print('Create hire request data: $hireData');

      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/hire'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(hireData),
      );

      print("Create hire request status: ${response.statusCode}");
      print("Create hire request body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message':
              responseData['message'] ?? 'Hire request sent successfully',
          'order': responseData['order'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to send hire request',
        };
      }
    } catch (e) {
      print('Create hire request error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- UPLOAD PROFILE IMAGE ---------------------
  static Future<Map<String, dynamic>> uploadProfileImage(
    String userId,
    File imageFile,
    String role,
  ) async {
    try {
      final token = await getToken();
      if (token == null)
        return {'success': false, 'message': 'User not logged in'};

      final isServiceProvider = role.toLowerCase() == 'service_provider';
      final endpoint = isServiceProvider
          ? '$baseUrl/signup/service-provider/profile/$userId/image'
          : '$baseUrl/signup/user/profile/$userId/image';

      var request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        await http.MultipartFile.fromPath('profileImage', imageFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['user'] != null) {
          await saveUserSession(responseData['user']);
        }
        return {
          'success': true,
          'message': responseData['message'] ?? 'Image updated',
          'imageUrl': responseData['imageUrl'],
          'user': responseData['user'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to upload',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --------------------- UPDATE USER PROFILE ---------------------
  static Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> updateData,
    String role,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final isServiceProvider = role.toLowerCase() == 'service_provider';
      final endpoint = isServiceProvider
          ? '$baseUrl/signup/service-provider/profile/$userId'
          : '$baseUrl/signup/user/profile/$userId';

      print("Updating profile at: $endpoint");

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateData),
      );

      print("Update profile status: ${response.statusCode}");
      print("Update profile body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['user'] != null) {
          await saveUserSession(responseData['user']);
        } else if (responseData['serviceProvider'] != null) {
          // Handle case where SP profile update returns 'serviceProvider' key but we need 'user' for session
          // Actually, backend for SP returns 'user' key too with mapped data (checked in Step 75)
          // But just in case, we rely on 'user' key being present as per backend code
        }

        return {
          'success': true,
          'message': responseData['message'] ?? 'Profile updated successfully',
          'user': responseData['user'] ?? responseData['serviceProvider'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update profile',
        };
      }
    } catch (error) {
      print("Update profile error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  static Future<Map<String, dynamic>> updateAvailability(
    bool isAvailable,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.patch(
        Uri.parse('$baseUrl/signup/service-provider/availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'isAvailable': isAvailable}),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final userData = await getUserData();
        userData['isAvailable'] = isAvailable;
        await saveUserDataToStorage(userData);
        return {'success': true, 'isAvailable': responseData['isAvailable']};
      }
      return {
        'success': false,
        'message': responseData['message'] ?? 'Error updating status',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> findUserByEmail(String email) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/find-by-email/$email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Find user by email status: ${response.statusCode}");
      print("Find user by email body: ${response.body}");

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': responseData['user']};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'User not found',
        };
      }
    } catch (error) {
      print("Find user by email error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET CUSTOMER ORDERS
  static Future<Map<String, dynamic>> getCustomerOrders({
    String? status,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Build query parameters
      final params = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (status != null && status.isNotEmpty && status != 'all') {
        params['status'] = status;
      }

      final uri = Uri.parse(
        '$baseUrl/api/orders/customer',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get customer orders status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'orders': responseData['orders'] ?? [],
          'total': responseData['total'] ?? 0,
          'page': responseData['page'] ?? 1,
          'totalPages': responseData['totalPages'] ?? 1,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch orders',
        };
      }
    } catch (error) {
      print("Get customer orders error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET CUSTOMER HOUSING BOOKINGS
  static Future<Map<String, dynamic>> getCustomerHousingBookings() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final uri = Uri.parse('$baseUrl/api/housing/booking/my-bookings');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get customer housing bookings status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Format housing bookings to match order structure
        final bookings =
            (responseData['bookings'] as List?)?.map((b) {
              return {
                ...b,
                'bookingType': 'housing',
                'orderNumber': b['bookingNumber'] ?? 'N/A',
                'createdAt': b['createdAt'] ?? DateTime.now().toIso8601String(),
              };
            }).toList() ??
            [];

        return {
          'success': true,
          'bookings': bookings,
          'total': responseData['total'] ?? 0,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch housing bookings',
        };
      }
    } catch (error) {
      print("Get customer housing bookings error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET PROVIDER ORDERS
  static Future<Map<String, dynamic>> getProviderOrders({
    String? status,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Build query parameters
      final params = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (status != null && status.isNotEmpty && status != 'all') {
        params['status'] = status;
      }

      final uri = Uri.parse(
        '$baseUrl/api/orders/provider',
      ).replace(queryParameters: params);

      print("Fetching provider orders from: ${uri.toString()}");

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get provider orders status: ${response.statusCode}");
      print("Get provider orders body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'orders': responseData['orders'] ?? [],
          'total': responseData['total'] ?? 0,
          'page': responseData['page'] ?? 1,
          'totalPages': responseData['totalPages'] ?? 1,
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Not authorized as service provider',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch orders',
        };
      }
    } catch (error) {
      print("Get provider orders error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET ORDER DETAILS
  static Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {'success': true, 'order': responseData['order']};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Order not found'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch order details',
        };
      }
    } catch (error) {
      print("Get order details error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // UPDATE ORDER STATUS (for providers)
  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
    String? notes,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status, 'notes': notes}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Order status updated',
          'order': responseData['order'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update order status',
        };
      }
    } catch (error) {
      print("Update order status error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // CANCEL ORDER (for customers)
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'reason': reason}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Order cancelled',
          'order': responseData['order'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to cancel order',
        };
      }
    } catch (error) {
      print("Cancel order error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // SEND MESSAGE IN ORDER
  static Future<Map<String, dynamic>> sendOrderMessage(
    String orderId,
    String message,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'message': message}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Message sent',
          'messageData': responseData['messageData'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to send message',
        };
      }
    } catch (error) {
      print("Send order message error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // RATE ORDER
  static Future<Map<String, dynamic>> rateOrder(
    String orderId,
    int rating,
    String? review,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'rating': rating, 'review': review}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Thank you for your review!',
          'order': responseData['order'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to submit rating',
        };
      }
    } catch (error) {
      print("Rate order error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // GET PROVIDER ORDER STATISTICS
  static Future<Map<String, dynamic>> getProviderOrderStats() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final uri = Uri.parse('$baseUrl/api/orders/stats/provider');

      print("Fetching provider stats from: ${uri.toString()}");

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Get provider stats status: ${response.statusCode}");
      print("Get provider stats body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {'success': true, 'stats': responseData['stats'] ?? {}};
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Not authorized as service provider',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch statistics',
        };
      }
    } catch (error) {
      print("Get provider stats error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // ================================
  // SHARED PREFERENCES
  // ================================

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> saveUserSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', json.encode(user));
  }

  static Future<String?> getToken() async {
    try {
      // First try SessionManager (secure storage)
      final secureToken = await SessionManager.getAccessToken();
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
      // Fallback to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      return token;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      // Also save to secure storage
      await SessionManager.saveTokens(accessToken: token, refreshToken: '');
    } catch (e) {
      // Silently fail
    }
  }

  // ================================
  // GENERIC GET METHOD FOR API CALLS
  // ================================
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      // Build full URL - handle both /api prefixed and non-prefixed paths
      String url;
      if (endpoint.startsWith('http')) {
        url = endpoint;
      } else if (endpoint.startsWith('/api/') ||
          endpoint.startsWith('/signup/') ||
          endpoint.startsWith('/auth')) {
        // These endpoints don't need /api prefix
        url = '$baseUrl$endpoint';
      } else {
        // Default endpoints get /api prefix
        url = '$baseUrl/api$endpoint';
      }

      final headers = {'Content-Type': 'application/json'};

      // Try to get token for authorization
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('GET request to: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('GET response status: ${response.statusCode}');
      print('GET response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData is Map<String, dynamic>
            ? responseData
            : {'data': responseData};
      } else {
        return {
          'success': false,
          'message': 'API Error: ${response.statusCode}',
        };
      }
    } catch (error) {
      print('GET error: $error');
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // static Future<Map<String, dynamic>> getUserDataFromToken() async {
  //   try {
  //     final token = await getToken();
  //     if (token == null) {
  //       return {};
  //     }

  //     // Decode the JWT token to get user data
  //     final parts = token.split('.');
  //     if (parts.length != 3) {
  //       return {};
  //     }

  //     final payload = parts[1];
  //     final normalized = base64Url.normalize(payload);
  //     final decoded = utf8.decode(base64Url.decode(normalized));
  //     final payloadMap = json.decode(decoded);

  //     print('Decoded token payload: $payloadMap');

  //     return {
  //       '_id': payloadMap['id'] ?? payloadMap['_id'],
  //       'firstName': payloadMap['firstName'],
  //       'lastName': payloadMap['lastName'],
  //       'email': payloadMap['email'],
  //       'phone': payloadMap['phone'],
  //       'city': payloadMap['city'],
  //       'role': payloadMap['role'],
  //     };
  //   } catch (e) {
  //     print('Error decoding token: $e');
  //     return {};
  //   }
  // }

  // In api_service.dart
  // static Future<Map<String, dynamic>> getUserData() async {
  //   try {
  //     final token = await getToken();
  //     if (token == null || token.isEmpty) {
  //       print('No token found');
  //       return {};
  //     }

  //     print('Getting user data with token...');

  //     // Try multiple endpoints since /api/users/me returns 404
  //     List<String> endpoints = [
  //       '/signup/user/me', // CHANGED: Use your actual endpoint from routes
  //       '/api/users/current',
  //       '/api/users/profile',
  //       '/api/auth/me',
  //       '/api/me',
  //     ];

  //     for (String endpoint in endpoints) {
  //       try {
  //         final response = await http.get(
  //           Uri.parse('$baseUrl$endpoint'),
  //           headers: {
  //             'Authorization': 'Bearer $token',
  //             'Content-Type': 'application/json',
  //           },
  //         );

  //         print('Trying endpoint: $endpoint');
  //         print('Response status: ${response.statusCode}');

  //         if (response.statusCode == 200) {
  //           final data = json.decode(response.body);
  //           print('✅ User data obtained from $endpoint');
  //           print('User data response: $data');

  //           if (data['success'] == true && data['user'] != null) {
  //             return data['user'] is Map<String, dynamic> ? data['user'] : {};
  //           }
  //           return data is Map<String, dynamic> ? data : {};
  //         }
  //       } catch (e) {
  //         print('Error with endpoint $endpoint: $e');
  //         continue;
  //       }
  //     }

  //     // If all endpoints fail, try to decode token
  //     print('🔄 All endpoints failed, trying token decode...');
  //     try {
  //       final decodedToken = await decodeJwtToken();
  //       if (decodedToken.isNotEmpty) {
  //         // FIX: Ensure we return all possible ID fields
  //         final userId =
  //             decodedToken['userId'] ??
  //             decodedToken['id'] ??
  //             decodedToken['_id'];
  //         return {
  //           '_id': userId ?? '',
  //           'id': userId ?? '',
  //           'userId': userId ?? '',
  //           'email': decodedToken['email'] ?? '',
  //           'username': decodedToken['username'] ?? '',
  //           'firstName': decodedToken['firstName'] ?? '',
  //           'lastName': decodedToken['lastName'] ?? '',
  //           'role': decodedToken['role'] ?? '',
  //           'phone': decodedToken['phone'] ?? '',
  //           'city': decodedToken['city'] ?? '',
  //         };
  //       }
  //     } catch (e) {
  //       print('Token decode failed: $e');
  //     }

  //     print('❌ All attempts to get user data failed');
  //     return {};
  //   } catch (e) {
  //     print('Error in getUserData: $e');
  //     return {};
  //   }
  // }
  static Future<Map<String, dynamic>> getUserData() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        print('❌ No token found');
        return {};
      }

      print('🔍 Getting user data with token...');

      // Try API endpoints first for fresh data
      List<String> endpoints = [
        '/signup/service-provider/me',
        '/signup/user/me',
        '/api/service-provider/me',
        '/api/users/me',
        '/api/auth/me',
      ];

      for (String endpoint in endpoints) {
        try {
          print('🔄 Trying endpoint: $baseUrl$endpoint');

          final response = await http.get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          print('📊 Response status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('✅ Success from $endpoint');

            Map<String, dynamic> user = {};

            if (data['user'] != null) {
              user = data['user'] is Map<String, dynamic> ? data['user'] : {};
            } else if (data['data'] != null) {
              user = data['data'] is Map<String, dynamic> ? data['data'] : {};
            } else if (data is Map<String, dynamic>) {
              user = data;
            }

            // Save to storage for future use ONLY if data was found
            if (user.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_data', json.encode(user));
              print('💾 Saved fresh user data to storage');
            }

            return user;
          }
        } catch (e) {
          print('Error with endpoint $endpoint: $e');
          continue;
        }
      }

      // Fallback to storage if API fails
      final prefs = await SharedPreferences.getInstance();
      final storedUser = prefs.getString('user_data');
      if (storedUser != null && storedUser.isNotEmpty) {
        try {
          final userMap = json.decode(storedUser);
          print('✅ Got user from storage (fallback): $userMap');
          return userMap;
        } catch (e) {
          print('Error parsing stored user: $e');
        }
      }

      // As last resort, decode token
      print('🔄 Falling back to token decode...');
      try {
        final decodedToken = await decodeJwtToken();
        if (decodedToken.isNotEmpty) {
          // Ensure consistent field names
          final userId =
              decodedToken['userId'] ??
              decodedToken['id'] ??
              decodedToken['_id'];
          final userData = {
            '_id': userId ?? '',
            'id': userId ?? '',
            'userId': userId ?? '',
            'email': decodedToken['email'] ?? '',
            'firstName': decodedToken['firstName'] ?? '',
            'lastName': decodedToken['lastName'] ?? '',
            'username': decodedToken['username'] ?? '',
            'phone': decodedToken['phone'] ?? '',
            'city': decodedToken['city'] ?? '',
            'role': decodedToken['role'] ?? '',
            'spSubRole': decodedToken['spSubRole'] ?? '',
          };

          await prefs.setString('user_data', json.encode(userData));
          return userData;
        }
      } catch (e) {
        print('Token decode failed: $e');
      }

      print('❌ All attempts failed');
      return {};
    } catch (e) {
      print('Error in getUserData: $e');
      return {};
    }
  }

  static Future<void> saveUserDataToStorage(
    Map<String, dynamic> userData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(userData));
      print('User data saved to storage');
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  static Future<Map<String, dynamic>> getSavedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        return json.decode(userJson);
      }
      return {};
    } catch (e) {
      print('Error getting saved user data: $e');
      return {};
    }
  }

  static Future<String?> getUserIdFromToken() async {
    try {
      final decodedToken = await decodeJwtToken();
      if (decodedToken.isNotEmpty) {
        return decodedToken['userId'] ??
            decodedToken['id'] ??
            decodedToken['_id'];
      }
      return null;
    } catch (e) {
      print('Error getting user ID from token: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    // Full secure logout
    await SessionManager.logout();
    // Also clear legacy storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_data');
    await prefs.remove('userData');
  }

  // ================================
  // CONVENIENCE METHODS
  // ================================

  static Future<String?> getCurrentEmail() async {
    final userData = await getUserData();
    return userData['email'];
  }

  static Future<String?> getCurrentRole() async {
    final userData = await getUserData();
    return userData['role'];
  }

  static Future<String?> getCurrentUserId() async {
    final userData = await getUserData();
    return userData['id'] ?? userData['userId'];
  }

  static Future<bool> isLoggedIn() async {
    // Check secure storage first
    final isSecure = await SessionManager.isLoggedIn();
    if (isSecure) return true;
    // Fallback to legacy check
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // --------------------- GET SERVICE PROVIDER ID ---------------------
  static Future<String?> getServiceProviderId() async {
    final userData = await getUserData();
    return userData['id'] ?? userData['spId'];
  }

  // --------------------- GET SERVICE PROVIDER ROLE ---------------------
  static Future<String?> getServiceProviderRole() async {
    final userData = await getUserData();
    return userData['spSubRole'];
  }

  // --------------------- CHECK IF USER IS SERVICE PROVIDER ---------------------
  static Future<bool> isServiceProvider() async {
    final userData = await getUserData();
    return userData['role'] == 'service_provider';
  }

  // --------------------- CHECK IF USER IS REGULAR USER ---------------------
  static Future<bool> isRegularUser() async {
    final userData = await getUserData();
    return userData['role'] == 'user';
  }
  // ================================
  // LAUNDRY PROVIDER SPECIFIC METHODS
  // ================================

  static Future<Map<String, dynamic>> getLaundryProviders({
    String? city,
    String sortBy = 'rating',
    String sortOrder = 'desc',
  }) async {
    try {
      final params = <String, String>{};
      if (city != null && city.isNotEmpty) params['city'] = city;
      params['sortBy'] = sortBy;
      params['sortOrder'] = sortOrder;

      final uri = Uri.parse(
        '$baseUrl/api/services/laundry-providers',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'laundryProviders': responseData['laundryProviders'] ?? [],
          'total': responseData['total'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch laundry providers',
        };
      }
    } catch (error) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getLaundryProviderDetails(
    String providerId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/services/laundry-provider/$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'provider': responseData['provider'],
          'services': responseData['services'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch provider details',
        };
      }
    } catch (error) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // --------------------- GET SERVICE PROVIDERS BY TYPE ---------------------
  static Future<Map<String, dynamic>> getServiceProvidersByType(
    String type, {
    String? city,
    String? sortBy,
    String? accommodationType,
    bool? isShared,
    int? availableRooms,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final params = <String, String>{'type': type};
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (sortBy != null) params['sortBy'] = sortBy;

      // Housing specific filters
      if (accommodationType != null)
        params['accommodationType'] = accommodationType;
      if (isShared != null) params['isShared'] = isShared.toString();
      if (availableRooms != null)
        params['availableRooms'] = availableRooms.toString();
      if (minPrice != null) params['minPrice'] = minPrice.toString();
      if (maxPrice != null) params['maxPrice'] = maxPrice.toString();

      final uri = Uri.parse(
        '$baseUrl/api/services/providers-by-type',
      ).replace(queryParameters: params);

      print("Fetching providers by type from: ${uri.toString()}");

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'providers': responseData['providers'] ?? [],
          'total': responseData['total'] ?? 0,
        };
      } else {
        return {'success': false, 'message': 'Failed to load providers'};
      }
    } catch (error) {
      print("Get providers by type error: $error");
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // --------------------- CART METHODS ---------------------

  // ================================
  // CHAT METHODS
  // ================================

  static Future<Map<String, dynamic>> startChat(
    String providerId,
    String serviceId,
  ) async {
    try {
      final token = await getToken();
      final url = '$baseUrl/api/chat/start';
      final body = json.encode({
        'providerId': providerId,
        'serviceId': serviceId,
      });

      print("Starting chat: POST $url");
      print("Body: $body");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print("Start chat response: ${response.statusCode}");
      print("Response body: ${response.body}");

      return json.decode(response.body);
    } catch (e) {
      print("Start chat exception: $e");
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    String chatId,
    String content,
    String receiverId,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'chatId': chatId,
          'content': content,
          'receiverId': receiverId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      print("Send message error: $e");
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getMessages(String chatId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/messages/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      print("Get messages error: $e");
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getMyChats() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/my-chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      print("Get my chats error: $e");
      return {'success': false, 'message': 'Network error'};
    }
  }

  // --- REVIEW SYSTEM ---
  static Future<Map<String, dynamic>> submitReview(
    String orderId,
    double rating,
    String comment,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'orderId': orderId,
          'rating': rating,
          'comment': comment,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      print("Submit review error: $e");
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<List<Map<String, dynamic>>> getProviderReviews(
    String spId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reviews/provider/$spId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['reviews']);
      }
      return [];
    } catch (e) {
      print("Get provider reviews error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getServiceReviews(
    String serviceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reviews/service/$serviceId'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['reviews']);
      }
      return [];
    } catch (e) {
      print("Get service reviews error: $e");
      return [];
    }
  }

  // ================================
  // NOTIFICATION FUNCTIONS
  // ================================

  /// Fetch notifications with pagination
  static Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'notifications': [], 'unreadCount': 0};
    } catch (e) {
      print("Get notifications error: $e");
      return {'success': false, 'notifications': [], 'unreadCount': 0};
    }
  }

  /// Get unread notification count (for badge)
  static Future<int> getUnreadNotificationCount() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print("Get unread count error: $e");
      return 0;
    }
  }

  /// Mark notification(s) as read. Pass notificationId to mark one, or null to mark all.
  static Future<bool> markNotificationsRead({String? notificationId}) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(
          notificationId != null ? {'notificationId': notificationId} : {},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Mark notifications read error: $e");
      return false;
    }
  }

  /// Delete a single notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Delete notification error: $e");
      return false;
    }
  }

  /// Clear all notifications
  static Future<bool> clearAllNotifications() async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Clear notifications error: $e");
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HOUSING API METHODS
  // ════════════════════════════════════════════════════════════════════════════

  /// List approved properties with filters
  static Future<Map<String, dynamic>> getHousingProperties({
    String? city,
    String? area,
    String? propertyType,
    String? furnished,
    String? genderPreference,
    String? roomType,
    double? minPrice,
    double? maxPrice,
    String? search,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
    double? radius,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (area != null && area.isNotEmpty) params['area'] = area;
      if (propertyType != null) params['propertyType'] = propertyType;
      if (furnished != null) params['furnished'] = furnished;
      if (genderPreference != null)
        params['genderPreference'] = genderPreference;
      if (roomType != null) params['roomType'] = roomType;
      if (minPrice != null) params['minPrice'] = minPrice.toString();
      if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (sortBy != null) params['sortBy'] = sortBy;
      if (sortOrder != null) params['sortOrder'] = sortOrder;
      if (lat != null) params['lat'] = lat.toString();
      if (lng != null) params['lng'] = lng.toString();
      if (radius != null) params['radius'] = radius.toString();

      final uri = Uri.parse(
        '$baseUrl/api/housing',
      ).replace(queryParameters: params);
      print("Fetching housing properties: ${uri.toString()}");

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Failed to load properties'};
    } catch (e) {
      print("Get housing properties error: $e");
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get single property detail
  static Future<Map<String, dynamic>> getHousingPropertyDetail(
    String id,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Property not found'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Create a new property (owner only)
  static Future<Map<String, dynamic>> createHousingProperty(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/housing'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update property
  static Future<Map<String, dynamic>> updateHousingProperty(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/api/housing/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete property
  static Future<Map<String, dynamic>> deleteHousingProperty(String id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/housing/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get owner's properties
  static Future<Map<String, dynamic>> getMyHousingProperties() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/owner/my-properties'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load properties'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get owner stats
  static Future<Map<String, dynamic>> getHousingOwnerStats() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/owner/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load stats'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Create housing booking
  static Future<Map<String, dynamic>> createHousingBooking(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/housing/booking'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get tenant's bookings
  static Future<Map<String, dynamic>> getMyHousingBookings() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/booking/my-bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load bookings'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get owner's received bookings
  static Future<Map<String, dynamic>> getOwnerHousingBookings() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/booking/owner-bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load bookings'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update booking status
  static Future<Map<String, dynamic>> updateHousingBookingStatus(
    String id,
    String status, {
    String? notes,
  }) async {
    try {
      final token = await getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/housing/booking/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status, 'notes': notes}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Schedule a visit
  static Future<Map<String, dynamic>> scheduleHousingVisit(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/housing/visit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get user's visits
  static Future<Map<String, dynamic>> getMyHousingVisits() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/visit/my-visits'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load visits'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get owner's visit requests
  static Future<Map<String, dynamic>> getOwnerHousingVisits() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/visit/owner-visits'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load visits'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update visit status
  static Future<Map<String, dynamic>> updateHousingVisitStatus(
    String id,
    String status, {
    String? notes,
    String? rescheduledDate,
    String? rescheduledTime,
  }) async {
    try {
      final token = await getToken();
      final body = <String, dynamic>{'status': status};
      if (notes != null) body['notes'] = notes;
      if (rescheduledDate != null) body['rescheduledDate'] = rescheduledDate;
      if (rescheduledTime != null) body['rescheduledTime'] = rescheduledTime;

      final response = await http.patch(
        Uri.parse('$baseUrl/api/housing/visit/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Toggle favorite
  static Future<Map<String, dynamic>> toggleHousingFavorite(
    String propertyId,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/housing/favorite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'propertyId': propertyId}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get favorite properties
  static Future<Map<String, dynamic>> getMyHousingFavorites() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/favorite/my-favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return {'success': false, 'message': 'Failed to load favorites'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Check if property is favorited
  static Future<bool> checkHousingFavorite(String propertyId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/housing/favorite/check/$propertyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isFavorited'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  // ================================
  // CART FUNCTIONS
  // ================================

  static Future<Map<String, dynamic>> getCart() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/cart'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data; // { success: true, cart: {...} }
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to load cart',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addToCart(
    Map<String, dynamic> itemData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(itemData),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else if (response.statusCode == 409) {
        // Conflict (provider mismatch)
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to add item',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateCartItem(
    String itemId,
    int quantity, {
    String? instructions,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.put(
        Uri.parse('$baseUrl/api/cart/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'itemId': itemId,
          'quantity': quantity,
          'instructions': instructions,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update item',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeFromCart(String itemId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/cart/remove/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to remove item',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> clearCart() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.delete(
        Uri.parse('$baseUrl/api/cart/clear'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to clear cart',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Checkout validation/preparation
  static Future<Map<String, dynamic>> checkoutCart(
    Map<String, dynamic> checkoutData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/place-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(checkoutData),
      );

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================================
  // STRIPE PAYMENT METHODS
  // ================================

  /// Create a Stripe PaymentIntent via backend.
  /// Returns: { success, clientSecret, paymentId, amount, commission }
  static Future<Map<String, dynamic>> createPaymentIntent({
    required String bookingId,
    required String serviceType,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'bookingId': bookingId, 'serviceType': serviceType}),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Confirm a Stripe payment with the backend (backend verifies with Stripe API)
  static Future<Map<String, dynamic>> confirmPayment(
    String stripePaymentIntentId,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'stripePaymentIntentId': stripePaymentIntentId}),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Release escrow funds for a payment (provider gets paid)
  static Future<Map<String, dynamic>> releaseEscrow(String paymentId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/release-escrow/$paymentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get wallet info for current user (provider)
  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get payment history for current user
  static Future<Map<String, dynamic>> getMyPayments() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/my-payments'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ================================
  // COMMUNITY FUNCTIONS
  // ================================

  /// Get community posts with pagination and filtering
  static Future<Map<String, dynamic>> getCommunityPosts({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        params['category'] = category;
      }

      final uri = Uri.parse(
        '$baseUrl/api/community/posts',
      ).replace(queryParameters: params);

      print('Fetching community posts from: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('Community posts status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'posts': responseData['posts'] ?? [],
          'total': responseData['total'] ?? 0,
          'page': responseData['page'] ?? page,
          'totalPages': responseData['totalPages'] ?? 1,
          'hasMore': responseData['hasMore'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to load community posts',
          'posts': [],
        };
      }
    } catch (error) {
      print('Get community posts error: $error');
      return {
        'success': false,
        'message': 'Network error: $error',
        'posts': [],
      };
    }
  }

  /// Create a new community post
  static Future<Map<String, dynamic>> createCommunityPost(
    Map<String, dynamic> postData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(postData),
      );

      print('Create post status: ${response.statusCode}');
      final responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Post created successfully',
          'post': responseData['post'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to create post',
        };
      }
    } catch (error) {
      print('Create post error: $error');
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  /// Like/Unlike a community post
  static Future<Map<String, dynamic>> toggleLikePost(String postId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'liked': responseData['liked'] ?? false,
          'likeCount': responseData['likeCount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to like post',
        };
      }
    } catch (error) {
      print('Toggle like post error: $error');
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  /// Add comment to community post
  static Future<Map<String, dynamic>> addCommentToPost(
    String postId,
    String comment,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'comment': comment}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Comment added successfully',
          'comment': responseData['comment'],
          'commentCount': responseData['commentCount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to add comment',
        };
      }
    } catch (error) {
      print('Add comment error: $error');
      return {'success': false, 'message': 'Network error: $error'};
    }
  }
}
