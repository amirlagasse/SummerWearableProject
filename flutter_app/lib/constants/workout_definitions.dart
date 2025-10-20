import 'package:flutter/material.dart';

class WorkoutDefinition {
  const WorkoutDefinition({required this.name, required this.icon});

  final String name;
  final IconData icon;
}

const List<WorkoutDefinition> workoutDefinitions = [
  WorkoutDefinition(name: 'Bike', icon: Icons.directions_bike),
  WorkoutDefinition(name: 'Run', icon: Icons.directions_run),
  WorkoutDefinition(name: 'Row', icon: Icons.rowing),
  WorkoutDefinition(name: 'Lift', icon: Icons.fitness_center),
  WorkoutDefinition(name: 'Yoga', icon: Icons.self_improvement),
  WorkoutDefinition(name: 'Swim', icon: Icons.pool),
  WorkoutDefinition(name: 'Walk', icon: Icons.directions_walk),
  WorkoutDefinition(name: 'Stretch', icon: Icons.accessibility_new),
  WorkoutDefinition(name: 'HIIT', icon: Icons.flash_on),
  WorkoutDefinition(name: 'Other', icon: Icons.more_horiz),
];
