import 'dart:core';

/// A utility class for parsing deep link URLs and extracting route and payload information.
/// 
/// Supports various URL formats:
/// - Custom schemes: `myapp://home`, `myapp://profile?id=123`
/// - Universal links: `https://example.com/home`, `https://example.com/product/123`
/// - Path-based: `/home`, `/profile?id=123`
class DeepLinkParser {
  /// Parses a deep link URL and extracts route and payload information.
  /// 
  /// [url] - The deep link URL to parse (e.g., `myapp://home?id=123`, `https://example.com/profile/456`)
  /// 
  /// Returns a [DeepLinkResult] containing the parsed route and query parameters.
  /// 
  /// Example:
  /// ```dart
  /// final result = DeepLinkParser.parse('myapp://product?id=123&name=Widget');
  /// print(result.route); // '/product'
  /// print(result.queryParams); // {'id': '123', 'name': 'Widget'}
  /// ```
  static DeepLinkResult parse(String url) {
    if (url.isEmpty) {
      return DeepLinkResult(route: '/', queryParams: {});
    }

    // Remove whitespace
    url = url.trim();

    // Handle custom schemes (e.g., myapp://path/to/route?id=123)
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      // If parsing fails, treat as path-only
      return DeepLinkResult(route: url, queryParams: {});
    }

    // Extract path (route)
    // For custom schemes like notificationapp://product/123,
    // Uri.parse treats "product" as host, so we need to combine host and path
    String route;
    
    // Check if this is a custom scheme (not http/https)
    final isCustomScheme = uri.scheme.isNotEmpty && 
                          uri.scheme != 'http' && 
                          uri.scheme != 'https';
    
    if (isCustomScheme && uri.host.isNotEmpty) {
      // For custom schemes, host is part of the path
      // e.g., notificationapp://product/123 -> host="product", path="/123"
      // Combine host and path: /product/123
      final pathPart = uri.path.isEmpty || uri.path == '/' ? '' : uri.path;
      route = '/${uri.host}$pathPart';
    } else {
      // Standard URL (http/https) or no host
      route = uri.path.isEmpty ? '/' : uri.path;
      // Ensure route starts with /
      if (!route.startsWith('/')) {
        route = '/$route';
      }
    }

    // Extract query parameters
    final queryParams = <String, dynamic>{};
    uri.queryParameters.forEach((key, value) {
      queryParams[key] = value;
    });

    return DeepLinkResult(route: route, queryParams: queryParams);
  }

  /// Normalizes a route to ensure it starts with a forward slash.
  static String normalizeRoute(String route) {
    if (route.isEmpty) {
      return '/';
    }
    
    // Remove leading slash if present
    String normalized = route.startsWith('/') ? route.substring(1) : route;
    
    // Add leading slash back
    return '/$normalized';
  }

  /// Extracts the domain from a URL (for universal links).
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? null : uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Extracts the scheme from a URL.
  static String? extractScheme(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme.isEmpty ? null : uri.scheme;
    } catch (e) {
      return null;
    }
  }
}

/// Result of parsing a deep link URL.
class DeepLinkResult {
  /// The route path (e.g., '/home', '/product', '/profile')
  final String route;

  /// Query parameters extracted from the URL (e.g., {'id': '123', 'name': 'Widget'})
  final Map<String, dynamic> queryParams;

  /// Creates a [DeepLinkResult] with the parsed route and query parameters.
  const DeepLinkResult({
    required this.route,
    this.queryParams = const {},
  });

  /// Returns true if there are any query parameters.
  bool get hasQueryParams => queryParams.isNotEmpty;

  /// Converts query parameters to a payload map (alias for queryParams).
  Map<String, dynamic> get payload => queryParams;

  @override
  String toString() {
    return 'DeepLinkResult(route: $route, queryParams: $queryParams)';
  }
}

