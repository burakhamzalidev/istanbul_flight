import 'dart:math' as math;
import 'dart:ui';

/// Daire ile eksen hizalı dikdörtgen kesişiyor mu?
/// Simit'in hitbox'ı daire, engellerinki dikdörtgen.
bool circleIntersectsRect(Offset center, double radius, Rect rect) {
  final nearestX = center.dx.clamp(rect.left, rect.right);
  final nearestY = center.dy.clamp(rect.top, rect.bottom);
  final dx = center.dx - nearestX;
  final dy = center.dy - nearestY;
  return dx * dx + dy * dy < radius * radius;
}

/// Daire kenarının dikdörtgene olan boşluğu (kesişiyorsa 0 veya negatif).
/// Kıl payı algılamada kullanılır.
double circleClearance(Offset center, double radius, Rect rect) {
  final nearestX = center.dx.clamp(rect.left, rect.right);
  final nearestY = center.dy.clamp(rect.top, rect.bottom);
  final dx = center.dx - nearestX;
  final dy = center.dy - nearestY;
  return math.sqrt(dx * dx + dy * dy) - radius;
}
