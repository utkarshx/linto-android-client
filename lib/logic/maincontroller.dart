import 'dart:convert';

import 'package:linto_flutter_client/logic/userpref.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:linto_flutter_client/client/client.dart';
import 'package:linto_flutter_client/audio/audiomanager.dart';
import 'package:linto_flutter_client/audio/audioPlayer.dart';
import 'package:linto_flutter_client/logic/uicontroller.dart';
import 'package:linto_flutter_client/audio/utils/wav.dart';
import 'package:linto_flutter_client/audio/tts.dart';
import 'package:linto_flutter_client/logic/transactions.dart';


/// MainController is the central controller of the app.
/// It links the UI, client and modules.
class MainController {
  static final  Map<String, String> _audioAssets = {
    'START' : 'sounds/detection.wav',
    'STOP': 'sounds/detectEnd.wav',
    'CANCELED' : 'sounds/canceled.wav'};

  final LinTOClient client = LinTOClient();           // Network connectivity
  final AudioManager audioManager = AudioManager();   // Audio input
  final Audio _audioPlayer = Audio();                 // Audio output
  final TTS _tts = TTS();                             // Text to speech
  VoiceUIController currentUI;                        // UI interface
  UserPreferences userPreferences = UserPreferences();// Persistent user preferences

  ClientState state = ClientState.INITIALIZING;       // App State

  Transaction _currentTransaction = Transaction("");  // Current transaction.

  /// Stop client session
  void disconnect() {
    // Disconnect from broker
    client.disconnect();
    // Cut Audio
    audioManager.stopDetecting();
    // Set flags
    state = ClientState.DISCONNECTED;
    currentUI.onDisconnect();
  }

  /// Request permission from device
  Future<bool> requestPermissions() async {
    if (! await Permission.microphone.status.isGranted) {
      if( ! await Permission.microphone.request().isGranted) {
        return false;
      }
    }
    if (! await Permission.mediaLibrary.status.isGranted) {
      if( ! await Permission.mediaLibrary.request().isGranted) {
        return false;
      }
    }
    return true;
  }

  void init() {
    if (state == ClientState.INITIALIZING) {
      audioManager.onReady = _onAudioReady;
      audioManager.initialize();
      _tts.initTts();
      _tts.startCallback = currentUI.onLintoSpeakingStart;
      _tts.stopCallback = currentUI.onLintoSpeakingStop;
      client.onMQTTMsg = _onMessage;
      state = ClientState.IDLE;
    } else if (state == ClientState.DISCONNECTED) {
      audioManager.startDetecting();
      state = ClientState.IDLE;
    }
  }

  /// Called on MQTT message received.
  void _onMessage(String topic, String msg) {
    var decodedMsg = jsonDecode(utf8.decode(msg.runes.toList()));
    String targetTopic = topic.split('/').last;
    if (targetTopic == 'say') {
      say(decodedMsg['value']);
      currentUI.onMessage('"${decodedMsg['value']}"');
    }
  }

  /// Synthesize speech
  void say(String value){
    //shutdown detection
    _tts.speak(value);
    //resolve
  }

  /// Simulate keyword spotted
  void triggerKeyWord() {
    audioManager.triggerKeyword();
  }

  /// Cancel utterance detection
  void abord() {
    if (state == ClientState.LISTENING) {
      audioManager.cancelUtterance();
    }
    state = ClientState.IDLE;
    if (! audioManager.isDetecting) {
      audioManager.startDetecting();
    }
  }

  /// Bind audio input callbacks
  void _onAudioReady() {
    audioManager.onKeyWordSpotted = _onKeywordSpotted;
    audioManager.onUtteranceStart = _onUtteranceStart;
    audioManager.onUtteranceEnd = _onUtteranceEnd;
    audioManager.onCanceled = _onUtteranceCanceled;
    audioManager.startDetecting();
    state = ClientState.IDLE;
  }

  void _onKeywordSpotted() {
    currentUI.onKeywordSpotted();
    _audioPlayer.playAsset(_audioAssets['START']);
    audioManager.detectUtterance();
    state = ClientState.LISTENING;
  }

  void _onUtteranceStart() {

    currentUI.onUtteranceStart();
  }

  void _onUtteranceEnd(List<int> signal) {
    currentUI.onUtteranceEnd();
    _audioPlayer.playAsset(_audioAssets['STOP']);
    client.sendMessage({'audio': rawSig2Wav(signal, 16000, 1, 16)});
    state = ClientState.REQUESTPENDING;
    currentUI.onRequestPending();
  }

  void _onUtteranceCanceled() {
    currentUI.onUtteranceCanceled();
    _audioPlayer.playAsset(_audioAssets['CANCELED']);
    state = ClientState.IDLE;
    audioManager.startDetecting();
  }
}

enum ClientState {
  INITIALIZING,
  IDLE,
  LISTENING,
  REQUESTPENDING,
  SPEAKING,
  DISCONNECTED
}