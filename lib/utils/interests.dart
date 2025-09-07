import 'package:flutter/material.dart';

/// Grouped interests used for selection in profile editing.
const Map<String, List<String>> categorizedInterests = {
  'Outdoors': [
    'Hiking',
    'Camping',
    'Surfing',
    'Cycling',
    'Running',
  ],
  'Creative': [
    'Photography',
    'Painting',
    'Music',
    'Writing',
    'Design',
  ],
  'Food & Drink': [
    'Coffee',
    'Tea',
    'Baking',
    'Cooking',
    'Wine',
  ],
  'Tech & Games': [
    'Gaming',
    'Coding',
    'AI',
    'Startups',
    'Crypto',
  ],
  'Fitness': [
    'Gym',
    'Yoga',
    'Pilates',
    'CrossFit',
    'Martial Arts',
  ],
};

/// Returns a color for a given interest name.
Color getColorForInterest(String interest) {
  final normalized = interest.toLowerCase();
  if (['hiking', 'camping', 'surfing', 'cycling', 'running'].contains(normalized)) {
    return Colors.green;
  }
  if (['photography', 'painting', 'music', 'writing', 'design'].contains(normalized)) {
    return Colors.purple;
  }
  if (['coffee', 'tea', 'baking', 'cooking', 'wine'].contains(normalized)) {
    return Colors.orange;
  }
  if (['gaming', 'coding', 'ai', 'startups', 'crypto'].contains(normalized)) {
    return Colors.blue;
  }
  if (['gym', 'yoga', 'pilates', 'crossfit', 'martial arts'].contains(normalized)) {
    return Colors.redAccent;
  }
  return Colors.grey;
}

/// Slightly darkens a given color for better contrast on dark backgrounds.
Color darkenColor(Color color, [double amount = .2]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

/// Returns a simple emoji for an interest.
String getEmojiForInterest(String interest) {
  switch (interest.toLowerCase()) {
    case 'hiking':
      return '🥾';
    case 'camping':
      return '🏕️';
    case 'surfing':
      return '🏄';
    case 'cycling':
      return '🚴';
    case 'running':
      return '🏃';
    case 'photography':
      return '📸';
    case 'painting':
      return '🎨';
    case 'music':
      return '🎵';
    case 'writing':
      return '✍️';
    case 'design':
      return '🧩';
    case 'coffee':
      return '☕️';
    case 'tea':
      return '🫖';
    case 'baking':
      return '🧁';
    case 'cooking':
      return '🍳';
    case 'wine':
      return '🍷';
    case 'gaming':
      return '🎮';
    case 'coding':
      return '🧑‍💻';
    case 'ai':
      return '🤖';
    case 'startups':
      return '🚀';
    case 'crypto':
      return '🪙';
    case 'gym':
      return '🏋️';
    case 'yoga':
      return '🧘';
    case 'pilates':
      return '🧘';
    case 'crossfit':
      return '🏋️';
    case 'martial arts':
      return '🥋';
    default:
      return '🏷️';
  }
}


