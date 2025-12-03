/// A class that represents a routing decision with route and payload.
/// 
/// Used for both notifications and deep links.
/// 
/// Example:
/// ```dart
/// SwiftRouting(
///   route: '/chatPage',
///   payload: {
///     'chatId': payload['chatId'],
///     'userId': payload['userId'],
///   },
/// )
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

