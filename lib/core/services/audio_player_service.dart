import 'package:audioplayers/audioplayers.dart';
import 'sound_service.dart';

class AudioPlayerService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(String asset) async {
    final enabled = await SoundService.isSoundEnabled();
    if (!enabled) return;

    await _player.play(AssetSource(asset));
  }
}