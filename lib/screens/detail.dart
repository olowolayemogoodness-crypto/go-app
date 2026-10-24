import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';

const _done = {'passed', 'passed_by_partner'};

/// The 30-day grid: how many activities were done each day.
class DetailScreen extends StatelessWidget {
  final String pledgeId;
  const DetailScreen({super.key, required this.pledgeId});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.doc('pledges/$pledgeId').snapshots(),
      builder: (context, ps) {
        final p = ps.data?.data();
        if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final days = (p['days'] as num).toInt();
        final acts = (p['activities'] as List).cast<Map>();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.collection('pledges/$pledgeId/acts').snapshots(),
          builder: (context, as) {
            final doneBy = <int, int>{};
            for (final d in as.data?.docs ?? const []) {
              final x = d.data();
              if (_done.contains(x['status'])) {
                final k = (x['day'] as num).toInt();
                doneBy[k] = (doneBy[k] ?? 0) + 1;
              }
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fs.collection('pledges/$pledgeId/days').snapshots(),
              builder: (context, ds) {
                final skipped = {for (final d in ds.data?.docs ?? const []) int.tryParse(d.id) ?? 0};
                return PageShell(
                  title: 'Program details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Premium: ${p['premium']} (simulated)'),
                      Text('Refund if you win: ${p['refundAmount']}'),
                      Text('Partner: ${p['partnerName']}'),
                      Text('Grace passes left: ${p['gracePasses']}'),
                      const SizedBox(height: 8),
                      for (final a in acts) Text('• ${a['title']} (${a['kind']})'),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (var d = 1; d <= days; d++)
                          Semantics(
                            label: skipped.contains(d)
                                ? 'Day $d: skipped with grace pass'
                                : 'Day $d: ${doneBy[d] ?? 0} of ${acts.length} done',
                            child: Chip(
                              avatar: Icon(
                                  skipped.contains(d)
                                      ? Icons.event_available
                                      : (doneBy[d] ?? 0) >= acts.length
                                          ? Icons.check_circle
                                          : (doneBy[d] ?? 0) > 0
                                              ? Icons.adjust
                                              : Icons.radio_button_unchecked,
                                  size: 18),
                              label: Text('$d'),
                            ),
                          ),
                      ]),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
