import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  final FirebaseFunctions functions;

  AiService({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  Future<List<String>> getReplySuggestions({
    required List<String> recentMessages,
    String language = 'English',
  }) async {
    final callable = functions.httpsCallable('getReplySuggestions');
    final result = await callable.call({
      'recentMessages': recentMessages,
      'language': language,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final list = (data['suggestions'] as List)
        .map((e) => e.toString())
        .toList();
    return list;
  }

  Future<String> translate({
    required String text,
    required String targetLang,
    List<String>? history,
    Map<String, dynamic>? meta,
  }) async {
    final callable = functions.httpsCallable('translateText');
    final result = await callable.call({
      'text': text,
      'targetLang': targetLang,
      if (history != null) 'history': history,
      if (meta != null) 'meta': meta,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['translatedText'] as String).trim();
  }
}
