import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';
import 'deep_link_handler.dart' show DeepLinkHandler, DeepLinkCallback;
import 'deep_link_parser.dart';
import 'routing_types.dart';

/// A callback function that determines the route and payload based on notification launch status.
/// 
/// Returns a [SwiftRouting] object with route and payload, or null to use the default initial route.
/// 
/// Example:
/// ```dart
/// onNotificationLaunch: ({required isFromNotification, required payload}) {
///   if (isFromNotification) {
///     return SwiftRouting(
///       route: '/chatPage',
///       payload: {
///         'chatId': payload['chatId'],
///         'userId': payload['userId'],
///       },
///     );
///   }
///   return null; // Use initialRoute from MaterialApp/GetMaterialApp
/// }
/// ```
typedef NotificationRouteCallback = SwiftRouting? Function({
  required bool isFromNotification,
  required Map<String, dynamic> payload,
});

/// A widget that wraps MaterialApp or GetMaterialApp and automatically handles notification and deep link routing.
/// 
/// This widget checks if the app was launched from a notification or deep link and routes accordingly.
/// All app configuration (routes, initialRoute, themes, etc.) should be provided in the MaterialApp 
/// or GetMaterialApp. Only routing logic is handled via [onNotificationLaunch] and [onDeepLink].
/// 
/// Deep links take priority over notifications when both are present.
/// 
/// You can pass either:
/// 1. A [MaterialApp] via [materialApp] to auto-manage all MaterialApp properties
/// 2. A [GetMaterialApp] via [getMaterialApp] to auto-manage all GetMaterialApp properties
/// 
/// Example with MaterialApp:
/// ```dart
/// SwiftFlutterMaterial(
///   materialApp: MaterialApp(
///     title: 'My App',
///     theme: ThemeData.light(),
///     initialRoute: '/home',
///     routes: {
///       '/home': (context) => HomeScreen(),
///       '/notification': (context) => NotificationScreen(),
///       '/product': (context) => ProductScreen(),
///     },
///   ),
///   onNotificationLaunch: ({required isFromNotification, required payload}) {
///     if (isFromNotification) {
///       return SwiftRouting(
///         route: '/notification',
///         payload: payload,
///       );
///     }
///     return null; // Use initialRoute from MaterialApp
///   },
///   onDeepLink: ({required url, required route, required queryParams}) {
///     if (route == '/product') {
///       return SwiftRouting(
///         route: '/product',
///         payload: {'productId': queryParams['id']},
///       );
///     }
///     return null; // Skip navigation
///   },
/// )
/// ```
class SwiftFlutterMaterial extends StatefulWidget {
  /// Optional MaterialApp instance. All MaterialApp properties (routes, initialRoute, themes, etc.)
  /// should be configured in this MaterialApp instance.
  final MaterialApp? materialApp;

  /// Optional GetMaterialApp instance. All GetMaterialApp properties (getPages, initialRoute, themes, etc.)
  /// should be configured in this GetMaterialApp instance.
  final GetMaterialApp? getMaterialApp;

  /// Optional callback to determine route and payload based on notification launch.
  /// This callback is used for both initial notification launches and notifications received while the app is running.
  /// Return a [SwiftRouting] object with route and payload, or null to skip navigation.
  /// 
  /// Example:
  /// ```dart
  /// onNotificationLaunch: ({required isFromNotification, required payload}) {
  ///   if (isFromNotification) {
  ///     return SwiftRouting(
  ///       route: '/chatPage',
  ///       payload: {
  ///         'chatId': payload['chatId'],
  ///         'userId': payload['userId'],
  ///       },
  ///     );
  ///   }
  ///   return null; // Use initialRoute from MaterialApp/GetMaterialApp or skip navigation
  /// }
  /// ```
  final NotificationRouteCallback? onNotificationLaunch;

  /// Optional callback to determine route and payload based on deep link URL.
  /// If provided, this callback will be called when the app is launched from a deep link
  /// or when a deep link is received while the app is running.
  /// Return a [SwiftRouting] object with route and payload, or null to skip navigation.
  /// 
  /// Example:
  /// ```dart
  /// onDeepLink: ({required url, required route, required queryParams}) {
  ///   if (route == '/product') {
  ///     return SwiftRouting(
  ///       route: '/product',
  ///       payload: {'productId': queryParams['id']},
  ///     );
  ///   }
  ///   return null; // Skip navigation
  /// }
  /// ```
  final DeepLinkCallback? onDeepLink;

  const SwiftFlutterMaterial({
    super.key,
    this.materialApp,
    this.getMaterialApp,
    this.onNotificationLaunch,
    this.onDeepLink,
  }) : assert(
          materialApp != null || getMaterialApp != null,
          'Either materialApp or getMaterialApp must be provided',
        ),
        assert(
          materialApp == null || getMaterialApp == null,
          'Cannot provide both materialApp and getMaterialApp',
        );

  @override
  State<SwiftFlutterMaterial> createState() =>
      _SwiftFlutterMaterialState();
}

class _SwiftFlutterMaterialState
    extends State<SwiftFlutterMaterial> {
  final ScreenLaunchByNotfication _plugin = ScreenLaunchByNotfication();
  String? _computedInitialRoute;
  Map<String, dynamic> _notificationPayload = {};
  bool _isInitialized = false;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<String>? _deepLinkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeRoute();
    _setupNotificationListener();
    _setupDeepLinkListener();
  }
  
  void _setupNotificationListener() {
    // Listen for notification taps when app is already running
    _notificationSubscription = _plugin.getNotificationStream().listen((event) {
      debugPrint('[SwiftFlutterMaterial] Notification tapped while app is running');
      debugPrint('[SwiftFlutterMaterial] Payload: ${event['payload']}');
      
      // Parse payload
      final payloadString = event['payload']?.toString() ?? '{}';
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(payloadString) as Map<String, dynamic>;
      } catch (e) {
        payload = {'raw': payloadString};
      }
      
      // Use onNotificationLaunch callback if provided (same logic as initial launch)
      if (widget.onNotificationLaunch != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final result = widget.onNotificationLaunch!(
            isFromNotification: true,
            payload: payload,
          );
          
          if (result != null) {
              _navigateToRoute(result.route, result.payload);
          } else {
            debugPrint('[SwiftFlutterMaterial] Callback returned null, skipping navigation');
          }
        } catch (e, stackTrace) {
          debugPrint('[SwiftFlutterMaterial] Error in onNotificationLaunch callback: $e');
          debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
        }
        });
      } else {
        debugPrint('[SwiftFlutterMaterial] No onNotificationLaunch callback provided, skipping navigation');
      }
    });
  }
  
  void _setupDeepLinkListener() {
    // Listen for deep link changes when app is already running
    _deepLinkSubscription = DeepLinkHandler.getLinkStream().listen((url) {
      debugPrint('[SwiftFlutterMaterial] Deep link received while app is running: $url');
      
      // Use onDeepLink callback if provided
      if (widget.onDeepLink != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final parsed = DeepLinkParser.parse(url);
            final result = widget.onDeepLink!(
              url: url,
              route: parsed.route,
              queryParams: parsed.queryParams,
          );
          
          if (result != null) {
              _navigateToRoute(result.route, result.payload);
          } else {
            debugPrint('[SwiftFlutterMaterial] Callback returned null, skipping navigation');
          }
        } catch (e, stackTrace) {
            debugPrint('[SwiftFlutterMaterial] Error in onDeepLink callback: $e');
          debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
        }
        });
      } else {
        // Default behavior: use automatic parsing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final routing = DeepLinkHandler.processDeepLink(url);
          if (routing != null && routing.route.isNotEmpty) {
            _navigateToRoute(routing.route, routing.payload);
          }
        });
      }
    });
  }
  
  /// Navigate to a route with optional payload
  void _navigateToRoute(String route, Map<String, dynamic>? payload) {
    if (route.isEmpty) {
      debugPrint('[SwiftFlutterMaterial] Empty route, skipping navigation');
        return;
      }
      
    try {
      // Navigate to the determined route
      if (widget.getMaterialApp != null) {
        // Use GetX navigation
        debugPrint('[SwiftFlutterMaterial] Navigating to $route using GetX');
        try {
          Get.toNamed(route, arguments: payload?.isNotEmpty == true ? payload : null);
        } catch (e) {
          debugPrint('[SwiftFlutterMaterial] GetX navigation error: $e');
          // Fallback: try using navigator key if GetX fails
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            navigator.pushNamed(route, arguments: payload?.isNotEmpty == true ? payload : null);
          }
        }
      } else {
        // Use MaterialApp navigation
        final materialAppNavigatorKey = widget.materialApp?.navigatorKey ?? _navigatorKey;
        final navigator = materialAppNavigatorKey.currentState;
        
        if (navigator != null) {
          debugPrint('[SwiftFlutterMaterial] Navigating to $route using MaterialApp Navigator');
          navigator.pushNamed(route, arguments: payload?.isNotEmpty == true ? payload : null);
        } else {
          debugPrint('[SwiftFlutterMaterial] Navigator not available yet, will retry');
          // Retry after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            final retryNavigator = materialAppNavigatorKey.currentState;
            if (retryNavigator != null) {
              debugPrint('[SwiftFlutterMaterial] Retrying navigation to $route');
              retryNavigator.pushNamed(route, arguments: payload?.isNotEmpty == true ? payload : null);
            } else {
              debugPrint('[SwiftFlutterMaterial] Navigator still not available after retry');
            }
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SwiftFlutterMaterial] Error navigating to route: $e');
      debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
    }
  }
  
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }
  
  /// Sanitizes a route - if it's a URL, parses it and returns the route. Otherwise returns the route as-is.
  /// This ensures we NEVER use a URL as a route name.
  String _sanitizeRoute(String route, {String? originalUrl, Map<String, dynamic>? queryParams}) {
    // If route is not a URL, just normalize it
    if (!route.contains('://')) {
      return DeepLinkParser.normalizeRoute(route);
    }
    
    // Route is a URL - parse it
    try {
      // If we have the original URL, use that for parsing
      final urlToParse = originalUrl ?? route;
      final parsed = DeepLinkParser.parse(urlToParse);
      
      // If parsed route is still a URL, something is very wrong
      if (parsed.route.contains('://')) {
        // Last resort: try to extract route from URL manually
        try {
          final uri = Uri.parse(urlToParse);
          if (uri.host.isNotEmpty) {
            final manualRoute = '/${uri.host}${uri.path}';
            if (!manualRoute.contains('://')) {
              return DeepLinkParser.normalizeRoute(manualRoute);
            }
          }
        } catch (e) {
          // Manual extraction failed
        }
        // If everything fails, return a safe default
        return '/';
      }
      
      return DeepLinkParser.normalizeRoute(parsed.route);
    } catch (e) {
      // If parsing fails, return a safe default
      return '/';
    }
  }

  /// Extracts the initial route from MaterialApp or GetMaterialApp
  String _getInitialRoute() {
    if (widget.materialApp != null) {
      // Try to get initialRoute from MaterialApp
      if (widget.materialApp!.initialRoute != null) {
        return widget.materialApp!.initialRoute!;
      }
      // If MaterialApp has home instead of initialRoute, use default
      if (widget.materialApp!.home != null) {
        return '/';
      }
    } else if (widget.getMaterialApp != null) {
      // Try to get initialRoute from GetMaterialApp
      if (widget.getMaterialApp!.initialRoute != null) {
        return widget.getMaterialApp!.initialRoute!;
      }
      // If GetMaterialApp has home instead of initialRoute, use default
      if (widget.getMaterialApp!.home != null) {
        return '/';
      }
    }
    return '/';
  }

  /// Gets routes from MaterialApp
  Map<String, WidgetBuilder>? _getRoutes() {
    if (widget.materialApp != null && widget.materialApp!.routes != null) {
      return Map<String, WidgetBuilder>.from(widget.materialApp!.routes!);
    }
    return null;
  }

  /// Gets getPages from GetMaterialApp
  List<GetPage>? _getGetPages() {
    if (widget.getMaterialApp != null && widget.getMaterialApp!.getPages != null) {
      return List<GetPage>.from(widget.getMaterialApp!.getPages!);
    }
    return null;
  }

  Future<void> _initializeRoute() async {
    debugPrint('[SwiftFlutterMaterial] Starting route initialization...');
    debugPrint('[SwiftFlutterMaterial] onNotificationLaunch callback provided: ${widget.onNotificationLaunch != null}');
    debugPrint('[SwiftFlutterMaterial] onDeepLink callback provided: ${widget.onDeepLink != null}');
    
    // Check for initial deep link first (deep links take priority over notifications)
    String? initialDeepLink;
    try {
      initialDeepLink = await DeepLinkHandler.getInitialLink();
      if (initialDeepLink != null && initialDeepLink.isNotEmpty) {
        debugPrint('[SwiftFlutterMaterial] Initial deep link found: $initialDeepLink');
      }
    } catch (e) {
      debugPrint('[SwiftFlutterMaterial] Error getting initial deep link: $e');
      initialDeepLink = null;
    }
    
    bool isFromNotification = false;
    Map<String, dynamic> payload = {};
    
    // Only check notifications if no deep link was found
    if (initialDeepLink == null || initialDeepLink.isEmpty) {
    try {
      final result = await _plugin.isFromNotification();
      isFromNotification = result['isFromNotification'] ?? false;
      final payloadString = result['payload'] ?? '{}';

      try {
        payload = jsonDecode(payloadString) as Map<String, dynamic>;
      } catch (e) {
        // If payload is not valid JSON, create a simple map
        payload = {'raw': payloadString};
      }

      debugPrint('[SwiftFlutterMaterial] Notification check: isFromNotification=$isFromNotification, payload=$payload');
    } catch (e, stackTrace) {
      // If plugin fails (e.g., MissingPluginException), treat as normal launch
      debugPrint('[SwiftFlutterMaterial] Plugin error (treating as normal launch): $e');
      debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
      isFromNotification = false;
      payload = {};
      }
    } else {
      debugPrint('[SwiftFlutterMaterial] Deep link found, skipping notification check');
    }

    // Always process routing logic, even if plugin failed
      String? route;
      final initialRoute = _getInitialRoute();
      final routes = _getRoutes();
      final getPages = _getGetPages();
      
      // Also check GetMaterialApp routes if available
      final getMaterialAppRoutes = widget.getMaterialApp?.routes;

    // Priority 1: Handle deep link if present
    if (initialDeepLink != null && initialDeepLink.isNotEmpty) {
      debugPrint('[SwiftFlutterMaterial] Processing initial deep link: "$initialDeepLink"');
      
      // First, parse the URL directly to see what we get
      final directParsed = DeepLinkParser.parse(initialDeepLink);
      debugPrint('[SwiftFlutterMaterial] Direct parse result: route="${directParsed.route}", queryParams=${directParsed.queryParams}');
      
      // CRITICAL: If parser returned a URL (should never happen, but just in case), reject it
      if (directParsed.route.contains('://')) {
        debugPrint('[SwiftFlutterMaterial] ❌❌❌ PARSER ERROR: Parser returned URL as route! This is a bug. Rejecting deep link.');
        debugPrint('[SwiftFlutterMaterial] Parser returned: "${directParsed.route}"');
        // Skip deep link processing and use initialRoute
        route = initialRoute;
      } else {
        final deepLinkRouting = DeepLinkHandler.processDeepLink(
          initialDeepLink,
          onDeepLink: widget.onDeepLink,
        );
      
        debugPrint('[SwiftFlutterMaterial] DeepLinkHandler returned: ${deepLinkRouting != null ? "route=${deepLinkRouting.route}, payload=${deepLinkRouting.payload}" : "null"}');
        
        if (deepLinkRouting != null) {
        debugPrint('[SwiftFlutterMaterial] Deep link routing result: route="${deepLinkRouting.route}", payload=${deepLinkRouting.payload}');
        debugPrint('[SwiftFlutterMaterial] Original deep link URL: "$initialDeepLink"');
        
        // Use the route from DeepLinkHandler (this should already have callback applied)
        var deepLinkRoute = deepLinkRouting.route;
        // CRITICAL FIX: Update outer scope payload variable, don't create a new local variable
        payload = deepLinkRouting.payload ?? <String, dynamic>{};
        
        debugPrint('[SwiftFlutterMaterial] Route from DeepLinkHandler: "$deepLinkRoute"');
        debugPrint('[SwiftFlutterMaterial] Payload from DeepLinkHandler: $payload');
        
        // CRITICAL: If route is a URL, something went wrong - parse it
        if (deepLinkRoute.contains('://')) {
          debugPrint('[SwiftFlutterMaterial] ⚠️ Route from DeepLinkHandler is a URL! Parsing it.');
          deepLinkRoute = directParsed.route;
          payload = directParsed.queryParams;
          
          // Try callback again with parsed route
          if (widget.onDeepLink != null) {
            try {
              final correctedRouting = widget.onDeepLink!(
                url: initialDeepLink,
                route: deepLinkRoute,
                queryParams: payload,
              );
              if (correctedRouting != null && !correctedRouting.route.contains('://')) {
                deepLinkRoute = correctedRouting.route;
                payload = correctedRouting.payload ?? payload;
                debugPrint('[SwiftFlutterMaterial] Callback returned route: "$deepLinkRoute"');
              }
            } catch (e) {
              debugPrint('[SwiftFlutterMaterial] Callback error: $e');
            }
          }
        }
        
        // IMPORTANT: deepLinkRoute should now be the final route from callback (e.g., /product)
        // But DeepLinkHandler might have returned the parsed route (e.g., /product/123) if callback returned null
        // So we need to ensure callback is called and its result is used
        // Let's ALWAYS try the callback one more time to be sure we get the correct route
        if (widget.onDeepLink != null && !deepLinkRoute.contains('://')) {
          try {
            final parsed = DeepLinkParser.parse(initialDeepLink);
            final callbackRouting = widget.onDeepLink!(
              url: initialDeepLink,
              route: parsed.route,
              queryParams: parsed.queryParams,
            );
            
            if (callbackRouting != null && !callbackRouting.route.contains('://')) {
              final callbackRoute = DeepLinkParser.normalizeRoute(callbackRouting.route);
              debugPrint('[SwiftFlutterMaterial] Callback returned route: "$callbackRoute" (original was: "$deepLinkRoute")');
              // Use callback route if it's different and valid
              deepLinkRoute = callbackRoute;
              payload = callbackRouting.payload ?? parsed.queryParams;
            }
          } catch (e) {
            debugPrint('[SwiftFlutterMaterial] Error calling callback: $e');
          }
        }
        
        // Check if route contains URL pattern (://) - this means callback returned wrong route or parsing failed
        if (deepLinkRoute.contains('://')) {
          debugPrint('[SwiftFlutterMaterial] ⚠️ Route contains URL pattern, re-parsing original deep link: $initialDeepLink');
          // Re-parse the original deep link URL
          final reParsed = DeepLinkParser.parse(initialDeepLink);
          debugPrint('[SwiftFlutterMaterial] Re-parsed result: route=${reParsed.route}, queryParams=${reParsed.queryParams}');
          
          // If callback is provided, try processing again with the correctly parsed route
          if (widget.onDeepLink != null) {
            try {
              final reParsedRouting = widget.onDeepLink!(
                url: initialDeepLink,
                route: reParsed.route,
                queryParams: reParsed.queryParams,
              );
              if (reParsedRouting != null) {
                deepLinkRoute = reParsedRouting.route;
                payload = reParsedRouting.payload ?? reParsed.queryParams;
                debugPrint('[SwiftFlutterMaterial] Re-processed route from callback: $deepLinkRoute');
                
                // Double-check: if still contains URL pattern, use parsed route directly
                if (deepLinkRoute.contains('://')) {
                  debugPrint('[SwiftFlutterMaterial] ⚠️ Callback still returned URL-like route, using parsed route: ${reParsed.route}');
                  deepLinkRoute = reParsed.route;
                  payload = reParsed.queryParams;
                }
              } else {
                // Callback returned null, use parsed route
                deepLinkRoute = reParsed.route;
                payload = reParsed.queryParams;
                debugPrint('[SwiftFlutterMaterial] Callback returned null, using parsed route: $deepLinkRoute');
              }
            } catch (e, stackTrace) {
              debugPrint('[SwiftFlutterMaterial] Error re-processing deep link: $e');
              debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
              // On error, use parsed route
              deepLinkRoute = reParsed.route;
              payload = reParsed.queryParams;
            }
          } else {
            // No callback, use re-parsed route and query params
            deepLinkRoute = reParsed.route;
            payload = reParsed.queryParams;
            debugPrint('[SwiftFlutterMaterial] No callback, using parsed route: $deepLinkRoute');
          }
        }
        
        // Final safety check: ensure route is not a URL
        if (deepLinkRoute.contains('://')) {
          debugPrint('[SwiftFlutterMaterial] ⚠️ CRITICAL: Route still contains URL pattern after all checks: $deepLinkRoute');
          debugPrint('[SwiftFlutterMaterial] Re-parsing original URL one more time: $initialDeepLink');
          final emergencyParsed = DeepLinkParser.parse(initialDeepLink);
          deepLinkRoute = emergencyParsed.route;
          payload = emergencyParsed.queryParams;
          debugPrint('[SwiftFlutterMaterial] Emergency parsed route: $deepLinkRoute');
          
          // Try callback one more time if available
          if (widget.onDeepLink != null) {
            try {
              final emergencyRouting = widget.onDeepLink!(
                url: initialDeepLink,
                route: emergencyParsed.route,
                queryParams: emergencyParsed.queryParams,
              );
              if (emergencyRouting != null && !emergencyRouting.route.contains('://')) {
                deepLinkRoute = emergencyRouting.route;
                payload = emergencyRouting.payload ?? emergencyParsed.queryParams;
                debugPrint('[SwiftFlutterMaterial] Emergency callback returned route: $deepLinkRoute');
              }
            } catch (e) {
              debugPrint('[SwiftFlutterMaterial] Emergency callback error: $e');
            }
          }
        }
        
        // CRITICAL: Before normalizing, check if route is a URL. If so, parse it instead of normalizing
        if (deepLinkRoute.contains('://')) {
          debugPrint('[SwiftFlutterMaterial] ❌ Route is a URL before normalization: "$deepLinkRoute"');
          debugPrint('[SwiftFlutterMaterial] Parsing URL instead of normalizing');
          // Parse the route as if it were a URL (it might be the full URL)
          final urlParsed = DeepLinkParser.parse(deepLinkRoute);
          deepLinkRoute = urlParsed.route;
          payload = urlParsed.queryParams;
          debugPrint('[SwiftFlutterMaterial] Parsed route from URL: "$deepLinkRoute"');
          
          // If callback exists, try it one more time with the parsed route
          if (widget.onDeepLink != null && !deepLinkRoute.contains('://')) {
            try {
              final finalRouting = widget.onDeepLink!(
                url: initialDeepLink,
                route: deepLinkRoute,
                queryParams: payload,
              );
              if (finalRouting != null && !finalRouting.route.contains('://')) {
                deepLinkRoute = finalRouting.route;
                payload = finalRouting.payload ?? payload;
                debugPrint('[SwiftFlutterMaterial] Final callback returned route: "$deepLinkRoute"');
              }
            } catch (e) {
              debugPrint('[SwiftFlutterMaterial] Final callback error: $e');
            }
          }
        }
        
        // Normalize route to ensure it starts with / (only if it's not a URL)
        if (!deepLinkRoute.contains('://')) {
          deepLinkRoute = DeepLinkParser.normalizeRoute(deepLinkRoute);
          debugPrint('[SwiftFlutterMaterial] Final normalized deep link route: "$deepLinkRoute"');
        } else {
          debugPrint('[SwiftFlutterMaterial] ❌ Route is still a URL after parsing, cannot normalize: "$deepLinkRoute"');
        }
        
        // Final check: if route still looks like a URL, use directly parsed route and ignore everything else
        if (deepLinkRoute.contains('://')) {
          debugPrint('[SwiftFlutterMaterial] ❌ Route is still a URL after all processing: "$deepLinkRoute"');
          debugPrint('[SwiftFlutterMaterial] Using directly parsed route from original URL as last resort');
          // Use the directly parsed route we got at the start
          final lastResortParsed = DeepLinkParser.parse(initialDeepLink);
          deepLinkRoute = lastResortParsed.route;
          payload = lastResortParsed.queryParams;
          debugPrint('[SwiftFlutterMaterial] Last resort parsed route: "$deepLinkRoute"');
          
          // If this is still a URL, something is very wrong - reject it
          if (deepLinkRoute.contains('://')) {
            debugPrint('[SwiftFlutterMaterial] ❌❌❌ PARSER RETURNED URL! This should never happen. Using initialRoute.');
            route = initialRoute;
          } else {
            // Use the parsed route
            deepLinkRoute = DeepLinkParser.normalizeRoute(deepLinkRoute);
            debugPrint('[SwiftFlutterMaterial] Using last resort route: "$deepLinkRoute"');
          }
        }
        
        // Validate that the route exists in routes (only if it's not a URL)
        if (!deepLinkRoute.contains('://')) {
          // CRITICAL FIX: If route doesn't exist, try callback one more time to get the correct route
          // This handles cases like /product/123 -> /product
          final routeExists = routes?.containsKey(deepLinkRoute) == true ||
                             getPages?.any((page) => page.name == deepLinkRoute) == true ||
                             getMaterialAppRoutes?.containsKey(deepLinkRoute) == true;
          
          if (routeExists) {
            route = deepLinkRoute;
            debugPrint('[SwiftFlutterMaterial] ✅ Deep link routing: route=$route, payload=$payload');
          } else {
            // Route doesn't exist - try callback to get the correct route
            debugPrint('[SwiftFlutterMaterial] ⚠️ Deep link route "$deepLinkRoute" not found in routes');
            debugPrint('[SwiftFlutterMaterial] Available routes: ${routes?.keys.toList() ?? []}');
            debugPrint('[SwiftFlutterMaterial] Available getPages: ${getPages?.map((p) => p.name).toList() ?? []}');
            
            // Try callback one more time to convert route (e.g., /product/123 -> /product)
            if (widget.onDeepLink != null && initialDeepLink != null) {
              try {
                final parsed = DeepLinkParser.parse(initialDeepLink!);
                final callbackRouting = widget.onDeepLink!(
                  url: initialDeepLink!,
                  route: parsed.route,
                  queryParams: parsed.queryParams,
                );
                
                if (callbackRouting != null && !callbackRouting.route.contains('://')) {
                  final callbackRoute = DeepLinkParser.normalizeRoute(callbackRouting.route);
                  // Check if callback route exists
                  final callbackRouteExists = routes?.containsKey(callbackRoute) == true ||
                                            getPages?.any((page) => page.name == callbackRoute) == true ||
                                            getMaterialAppRoutes?.containsKey(callbackRoute) == true;
                  
                  if (callbackRouteExists) {
                    route = callbackRoute;
                    payload = callbackRouting.payload ?? parsed.queryParams;
                    debugPrint('[SwiftFlutterMaterial] ✅ Callback converted route "$deepLinkRoute" to "$route"');
                  } else {
                    debugPrint('[SwiftFlutterMaterial] ⚠️ Callback route "$callbackRoute" also not found, using initialRoute');
                    route = initialRoute;
                  }
                } else {
                  debugPrint('[SwiftFlutterMaterial] Callback returned null or URL, using initialRoute');
                  route = initialRoute;
                }
              } catch (e) {
                debugPrint('[SwiftFlutterMaterial] Error in callback: $e');
                route = initialRoute;
              }
            } else {
              route = initialRoute;
            }
          }
        } else {
          // Route is still a URL somehow - reject it
          debugPrint('[SwiftFlutterMaterial] ❌ Route is still a URL, rejecting: "$deepLinkRoute"');
          route = initialRoute;
        }
        } else {
          // Callback returned null, skip navigation and use initialRoute
          debugPrint('[SwiftFlutterMaterial] Deep link callback returned null, using initialRoute');
          route = initialRoute;
        }
      }
    }
    // Priority 2: Handle notification if no deep link
    else if (widget.onNotificationLaunch != null) {
        debugPrint('[SwiftFlutterMaterial] Calling onNotificationLaunch callback');
        debugPrint('[SwiftFlutterMaterial] isFromNotification: $isFromNotification');
        debugPrint('[SwiftFlutterMaterial] payload: $payload');
        
        try {
          final result = widget.onNotificationLaunch!(
            isFromNotification: isFromNotification,
            payload: payload,
          );
          
          if (result != null) {
            route = result.route;
            // Use payload from callback result, or keep original payload if null
            payload = result.payload ?? payload;
            debugPrint('[SwiftFlutterMaterial] Callback returned route: $route');
            debugPrint('[SwiftFlutterMaterial] Callback returned payload: $payload');
        } else {
            debugPrint('[SwiftFlutterMaterial] Callback returned null, using initialRoute');
            route = null; // Will use initialRoute below
          }
        } catch (e, stackTrace) {
          debugPrint('[SwiftFlutterMaterial] Error in onNotificationLaunch callback: $e');
          debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
          route = initialRoute; // Fallback to initialRoute on error
        }
        
        // If callback returns null, use initialRoute
        route = route ?? initialRoute;
      } else if (isFromNotification) {
        // Default behavior when no callback: check if '/notification' route exists
        bool hasNotificationRoute = false;
        if (routes != null && routes.containsKey('/notification')) {
          hasNotificationRoute = true;
        } else if (getMaterialAppRoutes != null && getMaterialAppRoutes.containsKey('/notification')) {
          hasNotificationRoute = true;
        } else if (getPages != null && 
                   getPages.any((page) => page.name == '/notification')) {
          hasNotificationRoute = true;
        }
        
        route = hasNotificationRoute ? '/notification' : initialRoute;
      } else {
        route = initialRoute; // Use initialRoute from app
      }

    // Final safety check: ALWAYS sanitize the route before using it
    // BUT: Don't sanitize if route is already valid and doesn't contain '://'
    String? safeRoute = route;
    if (safeRoute != null && safeRoute.contains('://')) {
      // Only sanitize if route is a URL
      safeRoute = _sanitizeRoute(safeRoute, originalUrl: initialDeepLink, queryParams: payload);
      // If sanitization returned '/', it means the route was invalid, use initialRoute
      if (safeRoute == '/' && route != '/' && route != initialRoute) {
        safeRoute = initialRoute;
      }
    }
    // If route doesn't contain '://', use it as-is (it's already valid)
    
    final finalRoute = safeRoute ?? initialRoute;
    
    // One more check: if finalRoute is a URL, sanitize it
    String finalSafeRoute = finalRoute;
    if (finalRoute.contains('://')) {
      finalSafeRoute = _sanitizeRoute(finalRoute, originalUrl: initialDeepLink);
      // If finalRoute was a URL and sanitization returned '/', use initialRoute instead
      if (finalSafeRoute == '/' && finalRoute.contains('://')) {
        finalSafeRoute = initialRoute.isNotEmpty && !initialRoute.contains('://') 
            ? initialRoute 
            : '/';
      }
    }
    // If finalRoute doesn't contain '://', use it as-is
    
    debugPrint('[SwiftFlutterMaterial] Setting _computedInitialRoute to: "$finalSafeRoute" (original route was: "$route")');
    debugPrint('[SwiftFlutterMaterial] Setting _notificationPayload to: $payload');

    // CRITICAL: Set payload synchronously BEFORE setState to ensure it's available when widget rebuilds
    _notificationPayload = Map<String, dynamic>.from(payload);
    _computedInitialRoute = finalSafeRoute;

      setState(() {
      _computedInitialRoute = finalSafeRoute;
      _notificationPayload = Map<String, dynamic>.from(payload);
        _isInitialized = true;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show a loading screen while checking notification status
      final loadingTitle = widget.materialApp?.title ?? 
                          widget.getMaterialApp?.title ?? 
                          'Flutter App';
      final loadingDebugBanner = widget.materialApp?.debugShowCheckedModeBanner ?? 
                                 widget.getMaterialApp?.debugShowCheckedModeBanner ?? 
                                 false;
      
      if (widget.getMaterialApp != null) {
        return GetMaterialApp(
          title: loadingTitle,
          debugShowCheckedModeBanner: loadingDebugBanner,
          home: const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
      
      return MaterialApp(
        title: loadingTitle,
        debugShowCheckedModeBanner: loadingDebugBanner,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (widget.getMaterialApp != null) {
      return _NotificationAwareGetMaterialApp(
        initialRoute: _computedInitialRoute!,
        getMaterialApp: widget.getMaterialApp!,
        notificationPayload: _notificationPayload,
        navigatorKey: _navigatorKey,
      );
    } else {
    return _NotificationAwareMaterialApp(
      initialRoute: _computedInitialRoute!,
        materialApp: widget.materialApp!,
      notificationPayload: _notificationPayload,
      navigatorKey: _navigatorKey,
    );
    }
  }
}

class _NotificationAwareMaterialApp extends StatelessWidget {
  final String initialRoute;
  final MaterialApp materialApp;
  final Map<String, dynamic> notificationPayload;
  final GlobalKey<NavigatorState> navigatorKey;

  const _NotificationAwareMaterialApp({
    required this.initialRoute,
    required this.materialApp,
    required this.notificationPayload,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    // Build the enhanced routes with notification support
    final enhancedRoutes = _buildRoutes();
    
    // Use custom onGenerateRoute if provided, otherwise use default
    Route<dynamic>? Function(RouteSettings)? effectiveOnGenerateRoute;
    if (materialApp.onGenerateRoute != null) {
      effectiveOnGenerateRoute = materialApp.onGenerateRoute;
    } else {
      // Default: generate route from routes map or return null
      effectiveOnGenerateRoute = (RouteSettings settings) {
        final builder = enhancedRoutes[settings.name];
        if (builder != null) {
          return MaterialPageRoute<dynamic>(
            settings: settings,
            builder: builder,
          );
        }
        return null;
      };
    }

    // Create onGenerateInitialRoutes that passes payload to initial route
    List<Route<dynamic>> Function(String)? effectiveOnGenerateInitialRoutes;
    if (materialApp.onGenerateInitialRoutes != null) {
      effectiveOnGenerateInitialRoutes = materialApp.onGenerateInitialRoutes;
    } else {
      // Default: generate initial route with payload
      effectiveOnGenerateInitialRoutes = (String initialRouteName) {
        debugPrint('[SwiftFlutterMaterial] onGenerateInitialRoutes called with: "$initialRouteName"');
        debugPrint('[SwiftFlutterMaterial] Expected initialRoute (from widget): "$initialRoute"');
        
        // CRITICAL FIX: Use the initialRoute from widget instead of initialRouteName parameter
        // The initialRouteName might be wrong (e.g., /product/123), but initialRoute is correct (e.g., /product)
        String routeToUse = initialRoute; // Use widget's initialRoute, not the parameter!
        
        // Only if initialRouteName doesn't contain '://' and is different from initialRoute, check it
        // But prioritize initialRoute from widget
        if (initialRouteName.contains('://')) {
          // Route is a URL - parse it, but still use initialRoute from widget
          debugPrint('[SwiftFlutterMaterial] ⚠️ initialRouteName is a URL: "$initialRouteName", using widget initialRoute: "$initialRoute"');
          // routeToUse is already set to initialRoute above
        } else if (initialRouteName != initialRoute && !initialRouteName.contains('://')) {
          // If they're different and initialRouteName is not a URL, check if initialRouteName exists
          // But still prefer initialRoute
          debugPrint('[SwiftFlutterMaterial] initialRouteName "$initialRouteName" differs from widget initialRoute "$initialRoute"');
          // Check if initialRouteName exists in routes
          if (enhancedRoutes.containsKey(initialRouteName)) {
            debugPrint('[SwiftFlutterMaterial] initialRouteName exists, but using widget initialRoute: "$initialRoute"');
            // Still use initialRoute from widget to be safe
          }
        }
        
        // Normalize route to ensure it starts with /
        final normalizedRoute = DeepLinkParser.normalizeRoute(routeToUse);
        debugPrint('[SwiftFlutterMaterial] Using normalized route: "$normalizedRoute"');
        
        // Final safety check: if normalized route is still a URL, reject it completely
        if (normalizedRoute.contains('://')) {
          // Last resort: use home or a safe default
          final fallbackRoute = materialApp.home ?? Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Invalid route: $normalizedRoute'),
                  const Text('Route cannot be a URL'),
                ],
              ),
            ),
          );
          return [MaterialPageRoute(builder: (_) => fallbackRoute)];
        }
        
        debugPrint('[SwiftFlutterMaterial] notificationPayload in onGenerateInitialRoutes: $notificationPayload');
        debugPrint('[SwiftFlutterMaterial] notificationPayload isNotEmpty: ${notificationPayload.isNotEmpty}');
        
        final routeSettings = RouteSettings(
          name: normalizedRoute,
          arguments: notificationPayload.isNotEmpty ? notificationPayload : null,
        );
        
        debugPrint('[SwiftFlutterMaterial] routeSettings.arguments: ${routeSettings.arguments}');
        
        // First, try to find the route in enhancedRoutes (try both normalized and original)
        var builder = enhancedRoutes[normalizedRoute];
        if (builder == null && normalizedRoute != initialRouteName && normalizedRoute != routeToUse) {
          builder = enhancedRoutes[initialRouteName];
          if (builder == null) {
            builder = enhancedRoutes[routeToUse];
          }
        }
        if (builder != null) {
          debugPrint('[SwiftFlutterMaterial] ✅ Found route builder for: $normalizedRoute');
          debugPrint('[SwiftFlutterMaterial] Creating MaterialPageRoute with arguments: ${routeSettings.arguments}');
          final route = MaterialPageRoute<dynamic>(
            settings: routeSettings,
            builder: builder,
        );
        return [route];
        }
        
        // If not found, try using onGenerateRoute as fallback
        if (effectiveOnGenerateRoute != null) {
          debugPrint('[SwiftFlutterMaterial] Route not in routes map, trying onGenerateRoute');
          final generatedRoute = effectiveOnGenerateRoute(routeSettings);
          if (generatedRoute != null) {
            debugPrint('[SwiftFlutterMaterial] ✅ Generated route via onGenerateRoute');
            return [generatedRoute];
          }
        }
        
        // Last resort: fallback to home or show error
        debugPrint('[SwiftFlutterMaterial] ⚠️ Route "$normalizedRoute" not found, falling back to home');
        final fallbackRoute = MaterialPageRoute<dynamic>(
          settings: routeSettings,
          builder: (context) => materialApp.home ?? Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Route not founds: $normalizedRoute'),
                  Text('Available routesss: ${enhancedRoutes.keys.join(", ")}'),
                ],
              ),
            ),
          ),
        );
        return [fallbackRoute];
      };
    }

    return MaterialApp(
      key: materialApp.key,
      navigatorKey: materialApp.navigatorKey ?? navigatorKey,
      title: materialApp.title ?? 'Flutter App',
      initialRoute: initialRoute,
      routes: enhancedRoutes,
      theme: materialApp.theme,
      darkTheme: materialApp.darkTheme,
      themeMode: materialApp.themeMode,
      debugShowCheckedModeBanner: materialApp.debugShowCheckedModeBanner,
      builder: materialApp.builder,
      color: materialApp.color,
      locale: materialApp.locale,
      localizationsDelegates: materialApp.localizationsDelegates,
      supportedLocales: materialApp.supportedLocales,
      onGenerateRoute: effectiveOnGenerateRoute,
      onGenerateInitialRoutes: effectiveOnGenerateInitialRoutes,
      onUnknownRoute: materialApp.onUnknownRoute,
      navigatorObservers: materialApp.navigatorObservers ?? const [],
      restorationScopeId: materialApp.restorationScopeId,
      scrollBehavior: materialApp.scrollBehavior,
      shortcuts: materialApp.shortcuts,
      actions: materialApp.actions,
      home: materialApp.home,
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    final enhancedRoutes = <String, WidgetBuilder>{};
    
    // Use routes from MaterialApp
    if (materialApp.routes != null) {
      materialApp.routes!.forEach((route, builder) {
        enhancedRoutes[route] = builder;
      });
    }
    
    return enhancedRoutes;
  }
}

class _NotificationAwareGetMaterialApp extends StatelessWidget {
  final String initialRoute;
  final GetMaterialApp getMaterialApp;
  final Map<String, dynamic> notificationPayload;
  final GlobalKey<NavigatorState> navigatorKey;

  const _NotificationAwareGetMaterialApp({
    required this.initialRoute,
    required this.getMaterialApp,
    required this.notificationPayload,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    // Build the enhanced getPages with notification support
    final enhancedGetPages = _buildGetPages();
    
    // Validate that initialRoute exists in routes or getPages
    final validatedInitialRoute = _validateInitialRoute(enhancedGetPages);
    
    // Preserve all route-related properties from original GetMaterialApp
    // GetMaterialApp can use: routes (MaterialApp), getPages (GetX), home, or onGenerateRoute
    final hasGetPages = enhancedGetPages.isNotEmpty;
    final hasOriginalRoutes = getMaterialApp.routes != null && getMaterialApp.routes!.isNotEmpty;
    final hasOriginalHome = getMaterialApp.home != null;
    final hasOriginalInitialRoute = getMaterialApp.initialRoute != null;
    
    // Determine which route configuration to use
    // Priority: getPages > routes > home
    // If we have getPages or routes, we should use initialRoute
    // Always use the computed initialRoute if we have routes/getPages
    final useInitialRoute = hasGetPages || hasOriginalRoutes;

    // For GetMaterialApp, we'll use onGenerateRoute to inject payload for initial route
    Route<dynamic>? Function(RouteSettings)? effectiveOnGenerateRoute;
    if (getMaterialApp.onGenerateRoute != null) {
      effectiveOnGenerateRoute = getMaterialApp.onGenerateRoute;
    } else if (notificationPayload.isNotEmpty && useInitialRoute) {
      // Default: generate route with payload for GetMaterialApp
      effectiveOnGenerateRoute = (RouteSettings settings) {
        // If this is the initial route and we have payload, inject it
        if (settings.name == validatedInitialRoute && settings.arguments == null) {
          return GetPageRoute(
            settings: RouteSettings(
              name: settings.name,
              arguments: notificationPayload.isNotEmpty ? notificationPayload : null,
            ),
            page: () {
              // Try to find the page in getPages
              if (enhancedGetPages.isNotEmpty) {
                try {
                  final page = enhancedGetPages.firstWhere(
                    (p) => p.name == settings.name,
                  );
                  return page.page();
                } catch (e) {
                  // If page not found, return first page
                  return enhancedGetPages.first.page();
                }
              }
              // Fallback
              return const Scaffold(body: Center(child: Text('Route not found')));
            },
          );
        }
        // For other routes, use default GetX routing
        return null;
      };
    } else {
      effectiveOnGenerateRoute = getMaterialApp.onGenerateRoute;
    }

    return GetMaterialApp(
      key: getMaterialApp.key,
      title: getMaterialApp.title ?? 'Flutter App',
      initialRoute: useInitialRoute ? validatedInitialRoute : (hasOriginalInitialRoute ? getMaterialApp.initialRoute : null),
      routes: getMaterialApp.routes ?? const {}, // Preserve MaterialApp routes
      getPages: hasGetPages ? enhancedGetPages : getMaterialApp.getPages,
      home: useInitialRoute ? null : getMaterialApp.home,
      onGenerateRoute: effectiveOnGenerateRoute,
      onGenerateInitialRoutes: getMaterialApp.onGenerateInitialRoutes,
      onUnknownRoute: getMaterialApp.onUnknownRoute,
      theme: getMaterialApp.theme,
      darkTheme: getMaterialApp.darkTheme,
      themeMode: getMaterialApp.themeMode,
      debugShowCheckedModeBanner: getMaterialApp.debugShowCheckedModeBanner,
      builder: getMaterialApp.builder,
      color: getMaterialApp.color,
      locale: getMaterialApp.locale,
      localizationsDelegates: getMaterialApp.localizationsDelegates,
      supportedLocales: getMaterialApp.supportedLocales,
      defaultTransition: getMaterialApp.defaultTransition,
      unknownRoute: getMaterialApp.unknownRoute,
      navigatorObservers: getMaterialApp.navigatorObservers ?? const [],
      routingCallback: getMaterialApp.routingCallback,
      onReady: getMaterialApp.onReady,
      onDispose: getMaterialApp.onDispose,
      navigatorKey: getMaterialApp.navigatorKey ?? navigatorKey,
      shortcuts: getMaterialApp.shortcuts,
      actions: getMaterialApp.actions,
      useInheritedMediaQuery: getMaterialApp.useInheritedMediaQuery,
    );
  }

  List<GetPage> _buildGetPages() {
    // Use getPages directly from GetMaterialApp
    if (getMaterialApp.getPages != null) {
      return List<GetPage>.from(getMaterialApp.getPages!);
    }
    return [];
  }

  /// Validates that the initialRoute exists in routes or getPages.
  /// If not, falls back to the original initialRoute from GetMaterialApp.
  String _validateInitialRoute(List<GetPage> getPages) {
    debugPrint('[SwiftFlutterMaterial] Validating route: $initialRoute');
    debugPrint('[SwiftFlutterMaterial] Available getPages: ${getPages.map((p) => p.name).toList()}');
    debugPrint('[SwiftFlutterMaterial] Available routes: ${getMaterialApp.routes?.keys.toList() ?? []}');
    
    // Check if the computed initialRoute exists in getPages
    if (getPages.isNotEmpty) {
      final routeExists = getPages.any((page) => page.name == initialRoute);
      if (routeExists) {
        debugPrint('[SwiftFlutterMaterial] Route found in getPages: $initialRoute');
        return initialRoute;
      }
    }
    
    // Check if the computed initialRoute exists in MaterialApp routes
    if (getMaterialApp.routes != null && getMaterialApp.routes!.containsKey(initialRoute)) {
      debugPrint('[SwiftFlutterMaterial] Route found in routes: $initialRoute');
      return initialRoute;
    }
    
    // Fall back to original initialRoute from GetMaterialApp
    if (getMaterialApp.initialRoute != null) {
      // Check if original route exists in getPages
      if (getPages.isNotEmpty) {
        final originalExists = getPages.any((page) => page.name == getMaterialApp.initialRoute);
        if (originalExists) {
          return getMaterialApp.initialRoute!;
        }
      }
      // Check if original route exists in MaterialApp routes
      if (getMaterialApp.routes != null && getMaterialApp.routes!.containsKey(getMaterialApp.initialRoute!)) {
        return getMaterialApp.initialRoute!;
      }
    }
    
    // If neither exists, try to find the first page or first route
    if (getPages.isNotEmpty) {
      return getPages.first.name;
    }
    if (getMaterialApp.routes != null && getMaterialApp.routes!.isNotEmpty) {
      return getMaterialApp.routes!.keys.first;
        }
    
    // Last resort: return the computed route (will use original initialRoute if validation fails)
    debugPrint('[SwiftFlutterMaterial] Using computed route as fallback: $initialRoute');
    return initialRoute;
  }
}


