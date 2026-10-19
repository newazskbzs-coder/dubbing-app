import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:subtitle/subtitle.dart';

void main() => runApp(const MaterialApp(home: SubtitleDubbingScreen()));

class SubtitleDubbingScreen extends StatefulWidget {
  const SubtitleDubbingScreen({super.key});

  @override
  State<SubtitleDubbingScreen> createState() => _SubtitleDubbingScreenState();
}

class _SubtitleDubbingScreenState extends State<SubtitleDubbingScreen> {
  late VideoPlayerController _videoController;
  final FlutterTts _tts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();

  List<Subtitle> _subtitles = [];
  String _currentSubtitleText = "";
  String _currentHindiText = "";
  int _lastSpokenIndex = -1;

  final String _rawSrt = '''
1
00:00:01,000 --> 00:00:04,000
Hello, welcome to this video.

2
00:00:05,000 --> 00:00:08,000
Today we are learning about live dubbing.
''';

  @override
  void initState() {
    super.initState();
    _initTts();
    _parseSubtitles();

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
    )..initialize().then((_) {
        setState(() {});
      });

    _videoController.addListener(_syncSubtitleWithVideo);
  }

  void _initTts() async {
    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
  }

  void _parseSubtitles() {
    var controller = SubtitleController(
      provider: SubtitleProvider.fromString(
        data: _rawSrt,
        type: SubtitleType.srt,
      ),
    );
    _subtitles = controller.subtitles;
  }

  void _syncSubtitleWithVideo() async {
    if (!_videoController.value.isPlaying) return;

    final currentDuration = _videoController.value.position;

    for (int i = 0; i < _subtitles.length; i++) {
      final sub = _subtitles[i];

      if (currentDuration >= sub.start && currentDuration <= sub.end) {
        if (_lastSpokenIndex != i) {
          _lastSpokenIndex = i;

          setState(() {
            _currentSubtitleText = sub.data;
          });

          var translation = await _translator.translate(sub.data, to: 'hi');
          setState(() {
            _currentHindiText = translation.text;
          });

          await _tts.stop();
          await _tts.speak(translation.text);
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_syncSubtitleWithVideo);
    _videoController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subtitle to Hindi Dubbed Player")),
      body: Column(
        children: [
          _videoController.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: VideoPlayer(_videoController),
                )
              : const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
          const SizedBox(height: 10),
          IconButton(
            iconSize: 40,
            icon: Icon(
              _videoController.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
            ),
            onPressed: () {
              setState(() {
                _videoController.value.isPlaying
                    ? _videoController.pause()
                    : _videoController.play();
              });
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Original Subtitle:", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                Text(_currentSubtitleText, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 15),
                const Text("Dubbed in Hindi:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text(_currentHindiText, style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
