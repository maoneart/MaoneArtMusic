import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  print('=== Testing YoutubeExplode Client Variations ===');
  final videoId = 'b0ZBBjViV8Y'; // NOAH - Separuh Aku

  final yt = YoutubeExplode();

  try {
    print('Fetching manifest for videoId: $videoId');
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    print('AudioStreams count: ${manifest.audioOnly.length}');

    for (final stream in manifest.audioOnly) {
      print('Tag: ${stream.tag}, Bitrate: ${stream.bitrate}, Container: ${stream.container.name}, Codec: ${stream.audioCodec}');
      print('URL: ${stream.url.toString().substring(0, 100)}...');
    }
  } catch (e, st) {
    print('Manifest error: $e');
    print(st);
  } finally {
    yt.close();
  }
}
