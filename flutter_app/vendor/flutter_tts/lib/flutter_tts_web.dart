import 'dart:async';
import 'dart:collection';
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

enum TtsState { playing, stopped, paused, continued }

class FlutterTtsPlugin {
  static const String PLATFORM_CHANNEL = "flutter_tts";
  static late MethodChannel channel;
  bool awaitSpeakCompletion = false;

  TtsState ttsState = TtsState.stopped;

  Completer? _speechCompleter;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;

  get isPaused => ttsState == TtsState.paused;

  get isContinued => ttsState == TtsState.continued;

  static void registerWith(Registrar registrar) {
    channel =
        MethodChannel(PLATFORM_CHANNEL, const StandardMethodCodec(), registrar);
    final instance = FlutterTtsPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  late js.JsObject synth;
  late js.JsObject utterance;
  List<dynamic>? voices;
  List<String?>? languages;
  Timer? t;
  bool supported = false;

  FlutterTtsPlugin() {
    try {
      utterance = new js.JsObject(
          js.context["SpeechSynthesisUtterance"] as js.JsFunction, [""]);
      synth = new js.JsObject.fromBrowserObject(
          js.context["speechSynthesis"] as js.JsObject);
      _listeners();
      supported = true;
    } catch (e) {
      print('Initialization of TTS failed. Functions are disabled. Error: $e');
    }
  }

  void _listeners() {
    utterance["onstart"] = (e) {
      ttsState = TtsState.playing;
      channel.invokeMethod("speak.onStart", null);
      var bLocal = (utterance['voice']?["localService"] ?? false);
      if (bLocal is bool && !bLocal) {
        t = Timer.periodic(Duration(seconds: 14), (t) {
          if (ttsState == TtsState.playing) {
            synth.callMethod('pause');
            synth.callMethod('resume');
          } else {
            t.cancel();
          }
        });
      }
    };
    // js.JsFunction.withThis((e) {
    //   ttsState = TtsState.playing;
    //   channel.invokeMethod("speak.onStart", null);
    // });
    utterance["onend"] = (e) {
      ttsState = TtsState.stopped;
      if (_speechCompleter != null) {
        _speechCompleter?.complete();
        _speechCompleter = null;
      }
      t?.cancel();
      channel.invokeMethod("speak.onComplete", null);
    };

    utterance["onpause"] = (e) {
      ttsState = TtsState.paused;
      channel.invokeMethod("speak.onPause", null);
    };

    utterance["onresume"] = (e) {
      ttsState = TtsState.continued;
      channel.invokeMethod("speak.onContinue", null);
    };

    utterance["onerror"] = (e) {
      ttsState = TtsState.stopped;
      var event = new js.JsObject.fromBrowserObject(e);
      if (_speechCompleter != null) {
        _speechCompleter = null;
      }
      t?.cancel();
      channel.invokeMethod("speak.onError", event["error"]);
    };
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (!supported) return;
    switch (call.method) {
      case 'speak':
        final text = call.arguments as String?;
        if (awaitSpeakCompletion) {
          _speechCompleter = Completer();
        }
        _speak(text);
        if (awaitSpeakCompletion) {
          return _speechCompleter?.future;
        }
        break;
      case 'awaitSpeakCompletion':
        awaitSpeakCompletion = (call.arguments as bool?) ?? false;
        return 1;
      case 'stop':
        _stop();
        return 1;
      case 'pause':
        _pause();
        return 1;
      case 'resume':
        _resume();
        return 1;
      case 'setLanguage':
        final language = call.arguments as String?;
        _setLanguage(language);
        return 1;
      case 'getLanguages':
        return _getLanguages();
      case 'getVoices':
        return getVoices();
      case 'setVoice':
        final tmpVoiceMap =
            Map<String, String>.from(call.arguments as LinkedHashMap);
        return _setVoice(tmpVoiceMap);
      case 'setSpeechRate':
        final rate = call.arguments as num;
        _setRate(rate);
        return 1;
      case 'setVolume':
        final volume = call.arguments as num?;
        _setVolume(volume);
        return 1;
      case 'setPitch':
        final pitch = call.arguments as num?;
        _setPitch(pitch);
        return 1;
      case 'isLanguageAvailable':
        final lang = call.arguments as String?;
        return _isLanguageAvailable(lang);
      default:
        throw PlatformException(
            code: 'Unimplemented',
            details: "The flutter_tts plugin for web doesn't implement "
                "the method '${call.method}'");
    }
  }

  void _speak(String? text) {
    // The original implementation only spoke if ttsState was already
    // 'stopped' or 'paused'. Combined with the delayed cancel() in the old
    // _stop() (see below), a quick stop()-then-speak() sequence — exactly
    // what happens every time the user taps the speaker icon again or
    // switches language — could leave ttsState stuck on 'playing' from a
    // previous utterance whose onend/onerror never fired in time. When
    // that happened, this guard silently dropped the new speak() call:
    // no audio, no error, nothing. We now always cancel synchronously and
    // unconditionally start the new utterance instead of trusting stale
    // internal state.
    synth.callMethod('cancel');
    ttsState = TtsState.stopped;
    utterance['text'] = text;
    synth.callMethod('speak', [utterance]);
  }

  void _stop() {
    // Previously this called pause() then scheduled cancel() 500ms later.
    // That delay could fire *after* a subsequent speak() had already
    // started, silently cancelling the new utterance the user just asked
    // for (no audio, no error). Cancelling immediately is predictable and
    // avoids that race.
    synth.callMethod('cancel');
    ttsState = TtsState.stopped;
  }

  void _pause() {
    if (ttsState == TtsState.playing || ttsState == TtsState.continued) {
      synth.callMethod('pause');
    }
  }

  void _resume() {
    if (ttsState == TtsState.paused) {
      synth.callMethod('resume');
      ttsState = TtsState.continued;
    }
  }

  void _setRate(num rate) => utterance['rate'] = rate;
  void _setVolume(num? volume) => utterance['volume'] = volume;
  void _setPitch(num? pitch) => utterance['pitch'] = pitch;
  void _setLanguage(String? language) => utterance['lang'] = language;
  void _setVoice(Map<String?, String?> voice) {
    final name = voice["name"];
    final locale = voice["locale"];
    if (name == null || name.isEmpty || locale == null || locale.isEmpty) {
      // Explicit clear request (app passes empty strings when no voice
      // matches the target language). Previously there was no way to
      // unpin a voice once set, so switching to a language with no
      // dedicated voice kept speaking in the *previous* language's voice
      // — usually mispronounced or completely silent for scripts that
      // voice can't read. Clearing lets setLanguage()/utterance.lang pick
      // the platform's own default voice for the new language instead.
      utterance['voice'] = null;
      return;
    }
    var tmpVoices = synth.callMethod("getVoices");
    var targetList = tmpVoices.where((e) {
      return name == e["name"] && locale == e["lang"];
    });
    if (targetList.isNotEmpty as bool) {
      utterance['voice'] = targetList.first;
    }
  }

  bool _isLanguageAvailable(String? language) {
    if (voices?.isEmpty ?? true) _setVoices();
    if (languages?.isEmpty ?? true) _setLanguages();
    for (var lang in languages!) {
      if (!language!.contains('-')) {
        lang = lang!.split('-').first;
      }
      if (lang!.toLowerCase() == language.toLowerCase()) return true;
    }
    return false;
  }

  List<String?>? _getLanguages() {
    if (voices?.isEmpty ?? true) _setVoices();
    if (languages?.isEmpty ?? true) _setLanguages();
    return languages;
  }

  void _setVoices() {
    voices = synth.callMethod("getVoices") as List<dynamic>;
  }

  getVoices() async {
    var tmpVoices = synth.callMethod("getVoices");
    var voiceList = <Map<String, String>>[];
    for (var voice in tmpVoices) {
      voiceList.add({
        "name": voice["name"] as String,
        "locale": voice["lang"] as String,
      });
    }
    return voiceList;
  }

  void _setLanguages() {
    var langs = Set<String?>();
    for (var v in voices!) {
      langs.add(v['lang'] as String?);
    }

    languages = langs.toList();
  }
}
