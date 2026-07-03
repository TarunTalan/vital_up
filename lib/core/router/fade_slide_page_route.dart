import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A custom page route that provides a smooth slide and fade transition.
///
/// When a page is pushed (entry):
/// - It slides in slightly from the right (12% of screen width) to center.
/// - It fades in from 0.0 to 1.0.
///
/// When another page is pushed on top of it (exit/cover):
/// - It slides slightly to the left (6% of screen width) to create depth.
/// - It fades out to 60% opacity.
///
/// The reverse animation behaves exactly in reverse.
class FadeSlidePageRoute<T> extends CustomTransitionPage<T> {
  FadeSlidePageRoute({
    required super.child,
    required super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Modern, subtle entry slide from right to left
            final slideIn = Tween<Offset>(
              begin: const Offset(0.12, 0.0), // Subtle movement for premium look
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            // Primary fade in
            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ));

            // Subtle exit slide to the left when another screen is pushed
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.06, 0.0), // Parallax effect
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            // Fade out when covered
            final fadeOut = Tween<double>(
              begin: 1.0,
              end: 0.6,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ));

            return SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: fadeIn,
                child: SlideTransition(
                  position: slideOut,
                  child: FadeTransition(
                    opacity: fadeOut,
                    child: child,
                  ),
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
        );
}
