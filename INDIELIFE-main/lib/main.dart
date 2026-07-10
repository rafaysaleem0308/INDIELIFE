import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Auth Screens ────────────────────────────────────────────────────────────
import 'package:hello/features/auth/screens/splash_screen.dart';
import 'package:hello/features/auth/screens/intro.dart';
import 'package:hello/features/auth/screens/login.dart';
import 'package:hello/features/auth/screens/signup.dart';
import 'package:hello/features/auth/screens/forgot_password.dart';

// ─── Home Screens ────────────────────────────────────────────────────────────
import 'package:hello/features/home/screens/user_home.dart';
import 'package:hello/features/home/screens/service_provider_home.dart';

// ─── Service Screens ─────────────────────────────────────────────────────────
import 'package:hello/features/services/screens/meal.dart';
import 'package:hello/features/services/screens/laundry.dart';
import 'package:hello/features/services/screens/accommodation.dart';
import 'package:hello/features/services/screens/maintenance.dart';
import 'package:hello/features/services/screens/community.dart';
import 'package:hello/features/services/screens/housing_home.dart';
import 'package:hello/features/services/screens/housing_favorites.dart';
import 'package:hello/features/services/screens/my_housing_bookings.dart';
import 'package:hello/features/services/screens/my_housing_visits.dart';
import 'package:hello/features/services/screens/owner_housing_dashboard.dart';
import 'package:hello/features/services/screens/laundry_provider_detail.dart';
import 'package:hello/features/services/screens/maintenance_provider_detail.dart';
import 'package:hello/features/services/screens/housing_detail.dart';

// ─── Service Provider Forms ──────────────────────────────────────────────────
import 'package:hello/features/services/screens/add_meal_service.dart';
import 'package:hello/features/services/screens/add_laundry_service.dart';
import 'package:hello/features/services/screens/add_hostel_service.dart';
import 'package:hello/features/services/screens/add_maintenance_service.dart';

// ─── Order Screens ───────────────────────────────────────────────────────────
import 'package:hello/features/orders/screens/checkout.dart';
import 'package:hello/features/orders/screens/track_order.dart';
import 'package:hello/features/orders/screens/cart_screen.dart';
import 'package:hello/features/orders/screens/orders_screen.dart';

// ─── Other Screens ───────────────────────────────────────────────────────────
import 'package:hello/features/profile/screens/profile.dart';
import 'package:hello/features/home/screens/global_search.dart';
import 'package:hello/features/chat/screens/chat_screen.dart';
import 'package:hello/features/chat/screens/my_chats_screen.dart';
import 'package:hello/features/notifications/screens/notifications_screen.dart';

// ─── Shared ──────────────────────────────────────────────────────────────────
import 'package:hello/shared/widgets/loading_screen.dart';
import 'package:hello/core/services/sos_service.dart';
import 'package:hello/core/services/location_service.dart';
import 'package:hello/core/constants/stripe_config.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SOSService().initialize();

  // Check device location on app startup (with timeout to avoid freezing)
  await LocationService.getCurrentLocation().timeout(
    const Duration(seconds: 5),
    onTimeout: () => null,
  );

  Stripe.publishableKey = StripeConfig.publishableKey;
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SOSService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'IndieLife',
      theme: _buildThemeData(),
      home: const SplashScreen(),

      // ─── Named Routes ────────────────────────────────────────────────────
      routes: {
        '/loading_screen': (context) => LoadingScreen(),
        '/splash': (context) => const SplashScreen(),
        '/intro': (context) => IntroScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/user-home': (context) => UserHome(),
        '/service-provider-home': (context) => ServiceProviderHome(),
        '/forgot_password': (context) => ForgotPasswordScreen(),
        '/add-meal-service': (context) => AddMealServiceForm(),
        '/add-laundry-service': (context) => AddLaundryServiceForm(),
        '/add-hostel-service': (context) => AddHostelServiceForm(),
        '/add-maintenance-service': (context) => AddMaintenanceServiceForm(),
        '/meal': (context) => MealScreen(),
        '/laundry': (context) => LaundryScreen(),
        '/accommodation': (context) => AccommodationScreen(),
        '/housing': (context) => const HousingHomeScreen(),
        '/housing-favorites': (context) => const HousingFavoritesScreen(),
        '/housing-bookings': (context) => const MyHousingBookingsScreen(),
        '/housing-visits': (context) => const MyHousingVisitsScreen(),
        '/owner-housing-dashboard': (context) => const OwnerHousingDashboard(),
        '/maintenance': (context) => MaintenanceScreen(),
        '/track_order': (context) => TrackOrderScreen(),
        '/community': (context) => CommunityScreen(),
        '/profile': (context) => ProfileScreen(),
        '/search': (context) => GlobalSearchScreen(),
        '/cart': (context) => CartScreen(),
        '/my-chats': (context) => MyChatsScreen(),
        '/notifications': (context) => NotificationsScreen(),
        '/orders': (context) => OrdersScreen(),
        '/chat': (context) {
          final args =
              (ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?) ??
              {};
          return ChatScreen(
            chatId: args['chatId'] ?? '',
            otherUserName: args['otherUserName'] ?? 'User',
            otherUserImage: args['otherUserImage'] ?? '',
            serviceName: args['serviceName'] ?? 'Service',
            receiverId: args['receiverId'] ?? '',
            serviceId: args['serviceId'] ?? '',
          );
        },
      },

      // ─── Dynamic Routes (screens requiring arguments) ────────────────────
      onGenerateRoute: (settings) {
        if (settings.name == '/checkout') {
          final args = settings.arguments;
          if (args == null || args is! Map<String, dynamic>) {
            return MaterialPageRoute(builder: (context) => UserHome());
          }

          final cartItems = args['cartItems'];
          final provider = args['provider'];
          if (cartItems == null || provider == null) {
            return MaterialPageRoute(builder: (context) => UserHome());
          }

          return MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              cartItems: List<Map<String, dynamic>>.from(cartItems),
              provider: Map<String, dynamic>.from(provider),
            ),
          );
        }

        // ─── SERVICE INFO ROUTES ──────────────────────────────────────────
        if (settings.name == '/meal_info') {
          final service = settings.arguments as Map<String, dynamic>?;
          if (service == null) {
            return MaterialPageRoute(builder: (context) => MealScreen());
          }
          return MaterialPageRoute(
            builder: (context) => MealScreen(),
            settings: RouteSettings(arguments: service),
          );
        }

        if (settings.name == '/laundry_info') {
          final service = settings.arguments as Map<String, dynamic>?;
          if (service == null) {
            return MaterialPageRoute(builder: (context) => LaundryScreen());
          }
          final providerId = service['serviceProviderId']?.toString() ?? '';
          return MaterialPageRoute(
            builder: (context) => LaundryProviderDetailScreen(
              providerId: providerId,
              initialData: service,
            ),
          );
        }

        if (settings.name == '/accommodation_info') {
          final service = settings.arguments as Map<String, dynamic>?;
          if (service == null) {
            return MaterialPageRoute(
              builder: (context) => const HousingHomeScreen(),
            );
          }
          final propertyId = service['_id']?.toString() ?? '';
          if (propertyId.isEmpty) {
            return MaterialPageRoute(
              builder: (context) => const HousingHomeScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => HousingDetailScreen(propertyId: propertyId),
          );
        }

        if (settings.name == '/maintenance_info') {
          final service = settings.arguments as Map<String, dynamic>?;
          if (service == null) {
            return MaterialPageRoute(builder: (context) => MaintenanceScreen());
          }
          return MaterialPageRoute(
            builder: (context) =>
                MaintenanceProviderDetailScreen(provider: service),
          );
        }

        return null;
      },
    );
  }

  ThemeData _buildThemeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      primaryColor: const Color(0xFFFF9D42),

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9D42),
        primary: const Color(0xFFFF9D42),
        secondary: const Color(0xFFFFB74D),
        surface: Colors.white,
      ),

      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF9D42), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9D42),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFFFF9D42).withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
