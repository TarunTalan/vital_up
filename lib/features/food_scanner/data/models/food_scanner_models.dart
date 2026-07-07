import 'package:flutter/material.dart';

class DishItem {
  final String id;
  final String name;
  final int calories;

  const DishItem({this.id = '', required this.name, required this.calories});
}

class MacroMain {
  final String name;
  final int grams;
  final int percent;
  final Color color;

  const MacroMain({
    required this.name,
    required this.grams,
    required this.percent,
    required this.color,
  });
}

class MacroDetail {
  final String name;
  final int grams;
  final String unit;

  const MacroDetail({required this.name, required this.grams, this.unit = 'g'});
}

class MealPopupData {
  final String title;
  final String time;
  final List<String> points;

  const MealPopupData({
    required this.title,
    required this.time,
    required this.points,
  });
}
