import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';

/// A callback function that determines the route based on notification launch status.
/// 
/// Returns the route to navigate to, or null to use the default initial route.
typedef NotificationRouteCallback = String? Function({
  required bool isFromNotification,
  required Map<String, dynamic> payload,
});

/// A widget that wraps MaterialApp and automatically handles notification-based routing.
/// 
/// This widget checks if the app was launched from a notification and routes
/// accordingly. It also handles navigation back to the initial screen when
/// navigating back from a notification screen.
/// 
/// Example:
/// ```dart
/// SwiftFlutterMaterial(
///   initialRoute: '/home',
///   routes: {
///     '/home': (context) => HomeScreen(),
///     '/notification': (context) => NotificationScreen(),
///   },
///   onNotificationLaunch: ({required isFromNotification, required payload}) {
///     if (isFromNotification) {
///       return '/notification';
///     }
///     return null; // Use initialRoute
///   },
/// )
/// ```
class SwiftFlutterMaterial extends StatefulWidget {
  /// The initial route when app is launched normally (not from notification).
  final String initialRoute;

  /// The route to navigate to when back is pressed from notification screen.
  /// If null, defaults to [initialRoute].
  final String? homeRoute;

  /// The routes configuration for the app.
  /// 
  /// For routes that need access to notification payload, use [routesWithPayload].
  final Map<String, WidgetBuilder>? routes;

  /// Routes with access to notification payload.
  /// 
  /// The builder receives the notification payload as the second parameter.
  /// If both [routes] and [routesWithPayload] are provided, [routesWithPayload] takes precedence.
  final Map<String, Widget Function(BuildContext, Map<String, dynamic>)>? routesWithPayload;

  /// Optional callback to determine route based on notification launch.
  /// If null, defaults to '/notification' when launched from notification.
  final NotificationRouteCallback? onNotificationLaunch;

  /// Optional callback when navigation back occurs from notification screen.
  /// If null, navigates to [homeRoute] or [initialRoute].
  final VoidCallback? onBackFromNotification;

  /// The title of the app.
  final String? title;

  /// Theme for the app.
  final ThemeData? theme;

  /// Dark theme for the app.
  final ThemeData? darkTheme;

  /// Theme mode.
  final ThemeMode? themeMode;

  /// Debug banner.
  final bool? debugShowCheckedModeBanner;

  /// Additional MaterialApp properties can be passed via this builder.
  final Widget Function(BuildContext, Widget?)? builder;

  const ScreenLaunchByNotificationApp({
    super.key,
    required this.initialRoute,
    this.homeRoute,
    this.routes,
    this.routesWithPayload,
    this.onNotificationLaunch,
    this.onBackFromNotification,
    this.title,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.debugShowCheckedModeBanner,
    this.builder,
  }) : assert(
          routes != null || routesWithPayload != null,
          'Either routes or routesWithPayload must be provided',
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

  @override
  void initState() {
    super.initState();
    _initializeRoute();
  }

  Future<void> _initializeRoute() async {
    try {
      final result = await _plugin.isFromNotification();
      final isFromNotification = result['isFromNotification'] ?? false;
      final payloadString = result['payload'] ?? '{}';

      Map<String, dynamic> payload = {};
      try {
        payload = jsonDecode(payloadString) as Map<String, dynamic>;
      } catch (e) {
        // If payload is not valid JSON, create a simple map
        payload = {'raw': payloadString};
      }

      String? route;

      if (isFromNotification) {
        // Use custom callback if provided, otherwise default to '/notification'
        if (widget.onNotificationLaunch != null) {
          route = widget.onNotificationLaunch!(
            isFromNotification: isFromNotification,
            payload: payload,
          );
        } else {
          // Default behavior: check if '/notification' route exists
          route = widget.routes!.containsKey('/notification')
              ? '/notification'
              : widget.initialRoute;
        }
      } else {
        route = null; // Use initialRoute
      }

      setState(() {
        _computedInitialRoute = route ?? widget.initialRoute;
        _notificationPayload = payload;
        _isInitialized = true;
      });
    } catch (e) {
      // If there's an error, fall back to initial route
      setState(() {
        _computedInitialRoute = widget.initialRoute;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show a loading screen while checking notification status
      return MaterialApp(
        title: widget.title ?? 'Flutter App',
        debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner ?? false,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _NotificationAwareMaterialApp(
      initialRoute: _computedInitialRoute!,
      homeRoute: widget.homeRoute ?? widget.initialRoute,
      routes: widget.routes,
      routesWithPayload: widget.routesWithPayload,
      notificationPayload: _notificationPayload,
      onBackFromNotification: widget.onBackFromNotification,
      title: widget.title,
      theme: widget.theme,
      darkTheme: widget.darkTheme,
      themeMode: widget.themeMode,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      builder: widget.builder,
    );
  }
}

class _NotificationAwareMaterialApp extends StatelessWidget {
  final String initialRoute;
  final String homeRoute;
  final Map<String, WidgetBuilder>? routes;
  final Map<String, Widget Function(BuildContext, Map<String, dynamic>)>? routesWithPayload;
  final Map<String, dynamic> notificationPayload;
  final VoidCallback? onBackFromNotification;
  final String? title;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;
  final bool? debugShowCheckedModeBanner;
  final Widget Function(BuildContext, Widget?)? builder;

  const _NotificationAwareMaterialApp({
    required this.initialRoute,
    required this.homeRoute,
    this.routes,
    this.routesWithPayload,
    required this.notificationPayload,
    this.onBackFromNotification,
    this.title,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.debugShowCheckedModeBanner,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title ?? 'Flutter App',
      initialRoute: initialRoute,
      routes: _buildRoutes(),
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner ?? false,
      builder: builder,
      onGenerateRoute: (settings) {
        // Allow custom route generation if needed
        return null;
      },
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    final enhancedRoutes = <String, WidgetBuilder>{};
    
    // Use routesWithPayload if provided, otherwise use routes
    if (routesWithPayload != null) {
      routesWithPayload!.forEach((route, builder) {
        enhancedRoutes[route] = (context) {
          final widget = builder(context, notificationPayload);
          
          // Wrap notification routes with back navigation handler
          if (route != initialRoute && _isNotificationRoute(route)) {
            return _NotificationRouteWrapper(
              child: widget,
              homeRoute: homeRoute,
              onBack: onBackFromNotification,
            );
          }
          
          return widget;
        };
      });
    } else if (routes != null) {
      routes!.forEach((route, builder) {
        enhancedRoutes[route] = (context) {
          final widget = builder(context);
          
          // Wrap notification routes with back navigation handler
          if (route != initialRoute && _isNotificationRoute(route)) {
            return _NotificationRouteWrapper(
              child: widget,
              homeRoute: homeRoute,
              onBack: onBackFromNotification,
            );
          }
          
          return widget;
        };
      });
    }
    
    return enhancedRoutes;
  }

  bool _isNotificationRoute(String route) {
    // Consider it a notification route if it's not the initial route
    // and contains 'notification' or is a known notification route
    return route != initialRoute && 
           (route.contains('notification') || 
            route.contains('Notification') ||
            route == '/notification');
  }
}

class _NotificationRouteWrapper extends StatelessWidget {
  final Widget child;
  final String homeRoute;
  final VoidCallback? onBack;

  const _NotificationRouteWrapper({
    required this.child,
    required this.homeRoute,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // When back button is pressed from notification screen
        if (onBack != null) {
          onBack!();
        } else {
          // Default: navigate to home route and clear the navigation stack
          // This ensures we go to home instead of exiting the app
          Navigator.of(context).pushNamedAndRemoveUntil(
            homeRoute,
            (route) => false, // Remove all previous routes
          );
        }
      },
      child: child,
    );
  }
}

