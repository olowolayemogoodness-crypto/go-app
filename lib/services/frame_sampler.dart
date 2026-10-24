import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Client-side frame sampler (PRD F4).
/// Input: raw still images captured during the check-in window (max 12 used).
/// Steps: resize to max 768 px wide, drop frames >92% similar to the previous kept
/// frame, always keep first and last, JPEG quality 70, return data URLs.
class FrameSampler {
  static const int maxFrames = 12;
  static const double similarityDrop = 0.92;

  static Future<List<String>> prepare(List<Uint8List> raw) async {
    if (raw.isEmpty) return [];
    final decoded = <img.Image>[];
    for (final bytes in raw) {
      final im = img.decodeImage(bytes);
      if (im == null) continue;
      decoded.add(im.width > 768 ? img.copyResize(im, width: 768) : im);
    }
    if (decoded.isEmpty) return [];

    // Evenly pick up to maxFrames.
    List<img.Image> picked = decoded;
    if (decoded.length > maxFrames) {
      picked = List.generate(maxFrames, (i) {
        final idx = (i * (decoded.length - 1) / (maxFrames - 1)).round();
        return decoded[idx];
      });
    }

    final kept = <img.Image>[];
    List<int>? lastSig;
    for (var i = 0; i < picked.length; i++) {
      final sig = _signature(picked[i]);
      final isEdge = i == 0 || i == picked.length - 1;
      if (lastSig == null || isEdge || _similarity(lastSig, sig) <= similarityDrop) {
        kept.add(picked[i]);
        lastSig = sig;
      }
    }

    return kept
        .map((im) => 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(im, quality: 70))}')
        .toList();
  }

  /// 16x16 grayscale thumbnail.
  static List<int> _signature(img.Image im) {
    final small = img.copyResize(im, width: 16, height: 16);
    final out = <int>[];
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        final p = small.getPixel(x, y);
        out.add(((p.r + p.g + p.b) / 3).round());
      }
    }
    return out;
  }

  static double _similarity(List<int> a, List<int> b) {
    var sum = 0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return 1 - (sum / a.length) / 255.0;
  }
}
