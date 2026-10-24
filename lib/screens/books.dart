import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/reading.dart';
import 'reader.dart';

const _bg = Color(0xFFFFF9F2);
const _ink = Color(0xFF1B1B1F);
const _muted = Color(0xFF6C6C75);
const _orange = Color(0xFFE08813);
const _soft = Color(0xFFFFF0DA);
const _line = Color(0xFFE9DFD2);
const _purple = Color(0xFF8A5BD6);

/// Reading shelf: your PDFs and how many pages you really read today.
class BooksScreen extends StatefulWidget {
  final int goal;
  final VoidCallback? onCamera;
  const BooksScreen({super.key, this.goal = 20, this.onCamera});
  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Reading.library();
    if (mounted) {
      setState(() {
        _books = l;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final f = r?.files.single;
      if (f?.path == null) return;
      await Reading.add(f!.path!, f.name);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that PDF.')));
    }
  }

  Future<void> _open(Book b) async {
    final p = await Reading.pathOf(b);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(book: b, path: p)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text('Reading shelf', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, color: _ink)),
      ),
      body: SafeArea(
        child: kIsWeb
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('The PDF reader works in the phone app.', style: GoogleFonts.lexend(color: _muted))))
            : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
                StreamBuilder<int>(
                  stream: Reading.pagesToday(),
                  builder: (context, s) {
                    final n = s.data ?? 0;
                    final v = (n / widget.goal).clamp(0.0, 1.0);
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(22)),
                      child: Row(children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(value: v, strokeWidth: 7, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD79A))),
                            Icon(v >= 1 ? Icons.check_rounded : Icons.auto_stories_rounded, color: Colors.white),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$n of ${widget.goal} pages', style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text(v >= 1 ? 'Goal reached. Habit done.' : 'Read today to fill your battery.', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFFFFD79A))),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    'A page counts after ${Reading.minSeconds} seconds of active reading on it. Flipping past pages, leaving the app, or an idle screen counts nothing.',
                    style: GoogleFonts.lexend(fontSize: 12, height: 1.45, color: _ink),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Your books', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _orange)))
                else if (_books.isEmpty)
                  Text('No books yet. Add a PDF to start reading.', style: GoogleFonts.lexend(fontSize: 13, color: _muted))
                else
                  for (final b in _books)
                    Dismissible(
                      key: ValueKey(b.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: const Color(0xFFF3D9D5), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                      onDismissed: (_) async {
                        await Reading.remove(b);
                        _load();
                      },
                      child: GestureDetector(
                        onTap: () => _open(b),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line, width: 1.5)),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 56,
                              decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: _purple),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(value: b.pages == 0 ? 0 : b.counted.length / b.pages, minHeight: 6, backgroundColor: _line, valueColor: const AlwaysStoppedAnimation(_purple)),
                                ),
                                const SizedBox(height: 4),
                                Text('${b.counted.length} of ${b.pages} pages read', style: GoogleFonts.lexend(fontSize: 11, color: _muted)),
                              ]),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: _muted),
                          ]),
                        ),
                      ),
                    ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Add a PDF', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(backgroundColor: _ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                ),
                if (widget.onCamera != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCamera!();
                    },
                    child: Text('Reading a paper book? Check in with the camera', style: GoogleFonts.lexend(fontSize: 13, color: _muted)),
                  ),
              ]),
      ),
    );
  }
}
