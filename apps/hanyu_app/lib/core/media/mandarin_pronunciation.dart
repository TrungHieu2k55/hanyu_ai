import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum PronunciationResult { played, busy, noVoice, unavailable }

class MandarinPronunciation {
  MandarinPronunciation._();

  static final instance = MandarinPronunciation._();
  static const _setupTimeout = Duration(seconds: 4);

  late final _tts = FlutterTts();
  bool _speaking = false;

  Future<PronunciationResult> speak(String hanzi) async {
    if (_speaking) return PronunciationResult.busy;
    _speaking = true;
    try {
      return await _play(hanzi);
    } on TimeoutException {
      try {
        await _tts.stop().timeout(const Duration(seconds: 1));
      } on Exception {
        // The platform may already have stopped processing this request.
      }
      return PronunciationResult.unavailable;
    } on PlatformException {
      return PronunciationResult.unavailable;
    } on MissingPluginException {
      return PronunciationResult.unavailable;
    } finally {
      _speaking = false;
    }
  }

  Future<PronunciationResult> _play(String hanzi) async {
    final available = await _tts.getLanguages.timeout(_setupTimeout);
    final languages = <String, String>{
      if (available is List)
        for (final tag in available.whereType<String>())
          tag.toLowerCase().replaceAll('_', '-'): tag,
    };
    final language = [
      'zh-cn',
      'cmn-cn',
      'zh-hans-cn',
      'zh-hans',
      'zh-tw',
      'cmn-tw',
      'zh-hant-tw',
      'cmn',
      'zh',
    ].map((tag) => languages[tag]).nonNulls.firstOrNull;
    if (language == null) return PronunciationResult.noVoice;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts
          .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ])
          .timeout(_setupTimeout);
    }
    await _tts.awaitSpeakCompletion(true).timeout(_setupTimeout);
    final selected = await _tts.setLanguage(language).timeout(_setupTimeout);
    if (selected == 0 || selected == false) {
      return PronunciationResult.noVoice;
    }
    final result = await _tts.speak(hanzi).timeout(const Duration(seconds: 12));
    return result == 0 || result == false
        ? PronunciationResult.unavailable
        : PronunciationResult.played;
  }
}
