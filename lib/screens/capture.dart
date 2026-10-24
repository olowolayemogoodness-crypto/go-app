import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/frame_sampler.dart';
import '../widgets/common.dart';
import 'verdict.dart';

/// Live camera capture. Gallery upload is not offered (camera only).
/// We take a still every few seconds for up to ~30 s, then the sampler keeps up to 12 frames.
class CaptureScreen extends StatefulWidget {
  final String pledgeId;
  final String actId;
  final String codeWord;
  const CaptureScreen({super.key, required this.pledgeId, required this.actId, required this.codeWord});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Phase { init, ready, recording, verifying, error }

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _cam;
  _Phase _phase = _Phase.init;
  String _error = '';
  final List<Uint8List> _shots = [];
  Timer? _timer;
  int _elapsed = 0;
  static const int _everySec = 3;
  static const int _maxSec = 30;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('no camera');
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      final c = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _cam = c;
        _phase = _Phase.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'We could not open the camera. Allow camera access, or open this page in Chrome or Safari '
            '(in-app browsers like WhatsApp and Instagram often block it).';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _shot() async {
    if (_taking || _cam == null) return;
    _taking = true;
    try {
      final f = await _cam!.takePicture();
      _shots.add(await f.readAsBytes());
    } catch (_) {
      // Skip a failed frame.
    } finally {
      _taking = false;
    }
  }

  Future<void> _start() async {
    _shots.clear();
    _elapsed = 0;
    setState(() => _phase = _Phase.recording);
    await _shot();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      _elapsed++;
      if (mounted) setState(() {});
      if (_elapsed % _everySec == 0) await _shot();
      if (_elapsed >= _maxSec) _finish();
    });
  }

  bool _finishing = false;

  Future<void> _finish() async {
    if (_phase != _Phase.recording || _finishing) return;
    _finishing = true;
    _timer?.cancel();
    await _shot(); // final frame
    if (_shots.length < 2) {
      _finishing = false;
      setState(() => _phase = _Phase.ready);
      if (mounted) showSnack(context, 'Too short. Please record at least a few seconds.');
      return;
    }
    setState(() => _phase = _Phase.verifying);
    try {
      final frames = await FrameSampler.prepare(_shots);
      if (frames.isEmpty) throw ApiError('Could not read the camera frames. Please retry.');
      final r = await Api.verify(widget.pledgeId, widget.actId, frames);
      if (!mounted) return;
      await Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => VerdictScreen(pledgeId: widget.pledgeId, actId: widget.actId, result: r)));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PageShell(
      title: 'Check in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Show your activity and the code word: '),
                  TextSpan(text: widget.codeWord, style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                style: t.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_phase == _Phase.init) const Center(child: CircularProgressIndicator()),
          if (_cam != null && (_phase == _Phase.ready || _phase == _Phase.recording))
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(aspectRatio: _cam!.value.aspectRatio, child: CameraPreview(_cam!)),
            ),
          const SizedBox(height: 12),
          if (_phase == _Phase.ready)
            FilledButton(onPressed: _start, child: const Text('Start recording')),
          if (_phase == _Phase.recording) ...[
            Semantics(
              liveRegion: true,
              child: Text('Recording: $_elapsed s of $_maxSec s. Keep the activity and code word in view.',
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _finish, child: const Text('Done')),
          ],
          if (_phase == _Phase.verifying) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            const Text('Checking your evidence. This usually takes under 20 seconds.',
                textAlign: TextAlign.center),
          ],
          if (_phase == _Phase.error) ...[
            Text(_error),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => Navigator.pop(context), child: const Text('Back to home')),
          ],
          const SizedBox(height: 8),
          const Text('Tip: good lighting helps the checker. Your photos are sent for checking only and are not stored.',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
