import 'package:flutter/foundation.dart';

/// The phone's health data store as users know it: Apple Health on iPhone,
/// Health Connect on Android. Use it in every user-facing text that names
/// the store (fixed lists such as the FAQ name both).
String get healthStoreName => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Apple Health'
    : 'Health Connect';
