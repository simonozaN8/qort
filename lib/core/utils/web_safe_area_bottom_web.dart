import 'dart:html';

/// iPhone home indicator, kai Flutter MediaQuery grąžina 0 (PWA bug).
const _iosHomeIndicatorFallback = 34.0;

double readWebBottomSafeInset() {
  if (!_isIOSWeb) return 0;
  return _iosHomeIndicatorFallback;
}

bool get _isIOSWeb {
  final ua = window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      (ua.contains('macintosh') && ua.contains('mobile'));
}
