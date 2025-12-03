import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'deep_link_parser.dart';
import 'routing_types.dart';

/// A callback function that determines the route and payload based on deep link URL.
/// 
/// Returns a [SwiftRouting] object with route and payload, or null to use default handling.
/// 
/// Example:
/// ```dart
/// onDeepLink: ({required url, required route, required queryParams}) {
///   // Custom routing logic based on URL
///   if (route == '/product') {
///     return SwiftRouting(
///       route: '/product',
///       payload: {'productId': queryParams['id']},
///     );
///   }
///   return null; // Use default route parsing
/// }
/// ```
typedef DeepLinkCallback = SwiftRouting? Function({
  required String url,
  required String route,
  required Map<String, dynamic> queryParams,
});

/// Handles deep link URL processing and routing decisions.
class DeepLinkHandler {
  /// Checks for initial deep link when app is launched.
  /// 
  /// Returns the initial deep link URL if available, or null.
  static Future<String?> getInitialLink() async {
    try {
      // Use platform channel to get initial link
      const platform = MethodChannel('screen_launch_by_notfication/deep_link');
      final String? initialLink = await platform.invokeMethod('getInitialLink');
      return initialLink;
    } catch (e) {
      // Platform may not support deep linking or method not implemented
      debugPrint('[DeepLinkHandler] Error getting initial link: $e');
      return null;
    }
  }

  /// Sets up a stream to listen for deep link changes when app is running.
  /// 
  /// Returns a Stream that emits deep link URLs.
  static Stream<String> getLinkStream() {
    try {
      const platform = MethodChannel('screen_launch_by_notfication/deep_link');
      const eventChannel = EventChannel('screen_launch_by_notfication/deep_link_events');
      
      return eventChannel.receiveBroadcastStream().map((dynamic event) {
        if (event is String) {
          return event;
        }
        return event?.toString() ?? '';
      }).where((url) => url.isNotEmpty);
    } catch (e) {
      debugPrint('[DeepLinkHandler] Error setting up link stream: $e');
      return const Stream.empty();
    }
  }

  /// Processes a deep link URL and returns routing information.
  /// 
  /// [url] - The deep link URL to process
  /// [onDeepLink] - Optional callback for custom routing logic. If provided and returns null, will use default parsing.
  /// 
  /// Returns a [SwiftRouting] object with route and payload, or null if callback explicitly returns null.
  static SwiftRouting? processDeepLink(
    String url, {
    DeepLinkCallback? onDeepLink,
  }) {
    debugPrint('[DeepLinkHandler] Processing deep link: $url');
    
    // Parse the URL
    final parsed = DeepLinkParser.parse(url);
    
    // If custom callback is provided, use it
    if (onDeepLink != null) {
      try {
        final customRouting = onDeepLink(
          url: url,
          route: parsed.route,
          queryParams: parsed.queryParams,
        );
        
        if (customRouting != null) {
          // Safety check: if callback returned a URL-like route, use parsed route instead
          if (customRouting.route.contains('://')) {
            debugPrint('[DeepLinkHandler] ⚠️ Callback returned URL-like route "${customRouting.route}", using parsed route "${parsed.route}" instead');
            return SwiftRouting(
              route: parsed.route,
              payload: customRouting.payload ?? (parsed.queryParams.isNotEmpty ? parsed.queryParams : null),
            );
          }
          debugPrint('[DeepLinkHandler] Custom callback returned route: ${customRouting.route}');
          return customRouting;
        } else {
          // Callback returned null, skip navigation
          debugPrint('[DeepLinkHandler] Custom callback returned null, skipping navigation');
          return null;
        }
      } catch (e, stackTrace) {
        debugPrint('[DeepLinkHandler] Error in onDeepLink callback: $e');
        debugPrint('[DeepLinkHandler] Stack trace: $stackTrace');
        // On error, fall back to default parsing
      }
    }
    
    // Default: use parsed route and query params as payload (only if no callback or callback failed)
    return SwiftRouting(
      route: parsed.route,
      payload: parsed.queryParams.isNotEmpty ? parsed.queryParams : null,
    );
  }
}

