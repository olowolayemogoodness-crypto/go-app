import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../services/reading.dart';

const _bg = Color(0xFFFFF9F2);
const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _green = Color(0xFF2E9E6B);
const _line = Color(0xFFE9DFD2);

/// Reads a PDF and credits a page only after real, active time on it.
class ReaderScreen extends StatefulWidget {
  final Book book;
  final String path;
  const ReaderScreen({super.key, required this.book, required this.path});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  late final PdfController _c;
  Timer? _tick;
  int _page = 1;
  int _secs = 0;
  int _today = 0;
  bool _resumed = true;
  DateTime _touch = DateTime.now();
  StreamSubscription<int>? _sub;

  Book get _b => widget.book;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _page = _b.lastPage.clamp(1, _b.pages == 0 ? 1 : _b.pages);
    _c = PdfController(document: PdfDocument.openFile(widget.path), initialPage: _page);
    _sub = Reading.pagesToday().listen((n) {
      if (mounted) setState(() => _today = n);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _resumed = s == AppLifecycleState.resumed;
    if (_resumed) _touch = DateTime.now();
  }

  bool get _active => _resumed && DateTime.now().difference(_touch).inSeconds < Reading.idleSeconds;
  bool get _counted => _b.counted.contains(_page);

  void _onTick() {
    if (!mounted) return;
    if (_active && !_counted) {
      _secs++;
      if (_secs >= Reading.minSeconds) {
        _secs = 0;
        final p = _page;
        Reading.credit(_b, p).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _sub?.cancel();
    _b.lastPage = _page;
    Reading.update(_b);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counted = _counted;
    final active = _active;
    final status = counted
        ? 'Page counted'
        : active
            ? 'Counting this page...'
            : 'Paused. Touch the screen to continue.';
    final value = counted ? 1.0 : (_secs / Reading.minSeconds).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text(_b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('$_today today', style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: _orange))),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _touch = DateTime.now(),
            onPointerMove: (_) => _touch = DateTime.now(),
            onPointerSignal: (_) => _touch = DateTime.now(),
            child: PdfView(
              controller: _c,
              onPageChanged: (p) {
                setState(() {
                  _page = p;
                  _secs = 0;
                  _touch = DateTime.now();
                });
                _b.lastPage = p;
              },
              onDocumentLoaded: (d) {
                if (_b.pages != d.pagesCount) {
                  _b.pages = d.pagesCount;
                  Reading.update(_b);
                }
                setState(() {});
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _line))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(counted ? Icons.check_circle_rounded : (active ? Icons.timer_outlined : Icons.pause_circle_outline_rounded),
                    size: 18, color: counted ? _green : (active ? _orange : _muted)),
                const SizedBox(width: 8),
                Expanded(child: Text(status, style: GoogleFonts.lexend(fontSize: 13, color: _ink))),
                Text('Page $_page of ${_b.pages}', style: GoogleFonts.lexend(fontSize: 12, color: _muted)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: _line, valueColor: AlwaysStoppedAnimation(counted ? _green : _orange)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
