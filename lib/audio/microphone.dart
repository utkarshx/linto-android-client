import 'dart:async';
import 'package:mic_stream/mic_stream.dart';

//TODO: Check Permissions

class MicrophoneInput {
  int _sampleRate;
  int _encoding;
  int _channels;

  //flags
  bool _isListening = false;

  Stream<List<int>> _micStream;
  StreamSubscription<List<int>> _listener;

  Function(List<double>) _frameSink;

  set frameSink(Function(List<double>) sink) {
    _frameSink = sink;
  }

  bool get isListening{
    return _isListening;
  }

  MicrophoneInput(int sampleRate, int encoding, int channels) {
    _sampleRate = sampleRate;
    _channels = channels;
  }

  void startListening() {
    if (!_isListening) {
      _micStream = microphone(sampleRate: _sampleRate, audioFormat: AudioFormat.ENCODING_PCM_16BIT);
      _listener = _micStream.listen((samples) => _frameSink(samples.map((v) => v.toDouble()).toList()));
      _isListening = true;
      print("start");
    }
  }
  void stopListening() {
    if (_isListening) {
      _listener.cancel();
      _isListening = false;
      print("stop");
    }
  }
}