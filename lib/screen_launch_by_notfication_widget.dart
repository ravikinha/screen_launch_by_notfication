import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

/// A class that represents a routing decision with route and payload.
/// 
/// Use this class to return route and payload information from [NotificationRouteCallback].
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
///   // You can also return a route without payload
///   return SwiftRouting(
///     route: '/notificationScreen',
///     payload: null,
///   );
/// }
/// ```
class SwiftRouting {
  /// The route name to navigate to
  final String route;
  
  /// The payload data to pass to the route (optional)
  final Map<String, dynamic>? payload;
  
  const SwiftRouting({
    required this.route,
    this.payload,
  });
}

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

/// A callback function that handles notification taps when app is already running.
/// 
/// This is called when the user taps a notification while the app is open (foreground or background).
/// You can use this to navigate to the appropriate screen.
typedef OnNotificationTapCallback = void Function({
  required Map<String, dynamic> payload,
});

/// A widget that wraps MaterialApp or GetMaterialApp and automatically handles notification-based routing.
/// 
/// This widget checks if the app was launched from a notification and routes
/// accordingly. All app configuration (routes, initialRoute, themes, etc.) should be
/// provided in the MaterialApp or GetMaterialApp. Only notification-specific routing
/// logic is handled via [onNotificationLaunch].
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
/// )
/// ```
/// 
/// Example with GetMaterialApp:
/// ```dart
/// SwiftFlutterMaterial(
///   getMaterialApp: GetMaterialApp(
///     title: 'My App',
///     theme: ThemeData.light(),
///     initialRoute: '/home',
///     getPages: [
///       GetPage(name: '/home', page: () => HomeScreen()),
///       GetPage(name: '/notification', page: () => NotificationScreen()),
///     ],
///   ),
///   onNotificationLaunch: ({required isFromNotification, required payload}) {
///     if (isFromNotification) {
///       return SwiftRouting(
///         route: '/notification',
///         payload: payload,
///       );
///     }
///     return null; // Use initialRoute from GetMaterialApp
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
  /// If provided, this callback will be called when the app is launched from a notification.
  /// Return a map with 'route' (String) and 'payload' (Map<String, dynamic>) keys,
  /// or null to use the initialRoute from the app.
  /// 
  /// Example:
  /// ```dart
  /// onNotificationLaunch: ({required isFromNotification, required payload}) {
  ///   if (isFromNotification) {
  ///     return {
  ///       'route': '/chatPage',
  ///       'payload': {
  ///         'chatId': payload['chatId'],
  ///         'userId': payload['userId'],
  ///       },
  ///     };
  ///   }
  ///   return null; // Use initialRoute from MaterialApp/GetMaterialApp
  /// }
  /// ```
  final NotificationRouteCallback? onNotificationLaunch;

  /// Optional callback to handle notification taps when app is already running.
  /// This is called when the user taps a notification while the app is open (foreground or background).
  /// You can use this to navigate to the appropriate screen.
  /// 
  /// Example:
  /// ```dart
  /// onNotificationTap: ({required payload}) {
  ///   Navigator.pushNamed(context, '/notification', arguments: payload);
  /// }
  /// ```
  final OnNotificationTapCallback? onNotificationTap;

  const SwiftFlutterMaterial({
    super.key,
    this.materialApp,
    this.getMaterialApp,
    this.onNotificationLaunch,
    this.onNotificationTap,
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeRoute();
    _setupNotificationListener();
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
      
      if (widget.onNotificationTap != null) {
        // Use custom callback
        try {
          widget.onNotificationTap!(payload: payload);
        } catch (e, stackTrace) {
          debugPrint('[SwiftFlutterMaterial] Error in onNotificationTap callback: $e');
          debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
        }
      } else {
        // Default behavior: try to navigate to '/notification' route
        // Use post-frame callback to ensure navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToNotificationRoute(payload);
        });
      }
    });
  }
  
  void _navigateToNotificationRoute(Map<String, dynamic> payload) {
    try {
      String? targetRoute;
      
      // Use onNotificationLaunch callback if provided (same logic as initial launch)
      if (widget.onNotificationLaunch != null) {
        debugPrint('[SwiftFlutterMaterial] Using onNotificationLaunch callback to determine route');
        debugPrint('[SwiftFlutterMaterial] Payload for routing: $payload');
        
        try {
          // Call callback with isFromNotification=true since this is a notification tap
          final result = widget.onNotificationLaunch!(
            isFromNotification: true,
            payload: payload,
          );
          
          if (result != null) {
            targetRoute = result.route;
            // Use payload from callback result, or keep original payload if null
            payload = result.payload ?? payload;
            debugPrint('[SwiftFlutterMaterial] Callback returned route: $targetRoute');
            debugPrint('[SwiftFlutterMaterial] Callback returned payload: $payload');
          } else {
            debugPrint('[SwiftFlutterMaterial] Callback returned null, skipping navigation');
            return;
          }
        } catch (e, stackTrace) {
          debugPrint('[SwiftFlutterMaterial] Error in onNotificationLaunch callback: $e');
          debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
          return; // Don't navigate if callback fails
        }
      } else {
        // Default behavior: try to navigate to '/notification' route
        final routes = widget.materialApp?.routes ?? widget.getMaterialApp?.routes;
        final getPages = widget.getMaterialApp?.getPages;
        
        bool hasNotificationRoute = false;
        if (routes != null && routes.containsKey('/notification')) {
          hasNotificationRoute = true;
        } else if (getPages != null && getPages.any((page) => page.name == '/notification')) {
          hasNotificationRoute = true;
        }
        
        if (!hasNotificationRoute) {
          debugPrint('[SwiftFlutterMaterial] Notification route not found, skipping navigation');
          return;
        }
        
        targetRoute = '/notification';
      }
      
      // If callback returned null, don't navigate (use default behavior)
      if (targetRoute == null) {
        debugPrint('[SwiftFlutterMaterial] Callback returned null, skipping navigation');
        return;
      }
      
      // Navigate to the determined route
      if (widget.getMaterialApp != null) {
        // Use GetX navigation
        debugPrint('[SwiftFlutterMaterial] Navigating to $targetRoute using GetX');
        try {
          Get.toNamed(targetRoute, arguments: payload.isNotEmpty ? payload : null);
        } catch (e) {
          debugPrint('[SwiftFlutterMaterial] GetX navigation error: $e');
          // Fallback: try using navigator key if GetX fails
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            navigator.pushNamed(targetRoute, arguments: payload.isNotEmpty ? payload : null);
          }
        }
      } else {
        // Use MaterialApp navigation
        // Try to get navigator from the MaterialApp's navigatorKey first
        final materialAppNavigatorKey = widget.materialApp?.navigatorKey ?? _navigatorKey;
        final navigator = materialAppNavigatorKey.currentState;
        
        if (navigator != null) {
          debugPrint('[SwiftFlutterMaterial] Navigating to $targetRoute using MaterialApp Navigator');
          navigator.pushNamed(targetRoute, arguments: payload.isNotEmpty ? payload : null);
        } else {
          debugPrint('[SwiftFlutterMaterial] Navigator not available yet, will retry');
          // Retry after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            final retryNavigator = materialAppNavigatorKey.currentState;
            if (retryNavigator != null) {
              debugPrint('[SwiftFlutterMaterial] Retrying navigation to $targetRoute');
              retryNavigator.pushNamed(targetRoute!, arguments: payload.isNotEmpty ? payload : null);
            } else {
              debugPrint('[SwiftFlutterMaterial] Navigator still not available after retry');
            }
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SwiftFlutterMaterial] Error navigating to notification route: $e');
      debugPrint('[SwiftFlutterMaterial] Stack trace: $stackTrace');
    }
  }
  
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
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
    
    bool isFromNotification = false;
    Map<String, dynamic> payload = {};
    
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

    // Always process routing logic, even if plugin failed
      String? route;
      final initialRoute = _getInitialRoute();
      final routes = _getRoutes();
      final getPages = _getGetPages();
      
      // Also check GetMaterialApp routes if available
      final getMaterialAppRoutes = widget.getMaterialApp?.routes;

    // Always call the callback if provided, regardless of isFromNotification or plugin errors
        if (widget.onNotificationLaunch != null) {
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

      final finalRoute = route;
      debugPrint('[SwiftFlutterMaterial] Final computed route: $finalRoute');

      setState(() {
        _computedInitialRoute = finalRoute;
        _notificationPayload = payload;
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
      // Default: allow custom route generation if needed
      effectiveOnGenerateRoute = (settings) => null;
    }

    // Create onGenerateInitialRoutes that passes payload to initial route
    List<Route<dynamic>> Function(String)? effectiveOnGenerateInitialRoutes;
    if (materialApp.onGenerateInitialRoutes != null) {
      effectiveOnGenerateInitialRoutes = materialApp.onGenerateInitialRoutes;
    } else {
      // Default: generate initial route with payload
      effectiveOnGenerateInitialRoutes = (String initialRoute) {
        final route = MaterialPageRoute<dynamic>(
          settings: RouteSettings(
            name: initialRoute,
            arguments: notificationPayload.isNotEmpty ? notificationPayload : null,
          ),
          builder: (context) {
            final builder = enhancedRoutes[initialRoute];
            if (builder != null) {
              return builder(context);
            }
            // Fallback to home if route not found
            return materialApp.home ?? const Scaffold(body: Center(child: Text('Route not found')));
          },
        );
        return [route];
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
      useInheritedMediaQuery: materialApp.useInheritedMediaQuery,
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


