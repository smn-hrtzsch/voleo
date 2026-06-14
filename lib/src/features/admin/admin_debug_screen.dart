import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const adminDebugUids = {'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2'};

class AdminDebugScreen extends StatelessWidget {
  const AdminDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (!adminDebugUids.contains(uid)) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Nicht verfügbar.')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('sync_status')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Noch kein Sync Status.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _StatusCard(
                title: 'Live Sync',
                icon: Icons.flash_on,
                data: _mapValue(data['live']),
                primaryKeys: const [
                  'ok',
                  'changedCount',
                  'liveCandidates',
                  'overlayMatches',
                  'skippedStaleCount',
                  'footballDataStatus',
                  'footballDataMatches',
                  'updatedAt',
                  'error',
                ],
              ),
              const SizedBox(height: 12),
              _StatusCard(
                title: 'Full Sync',
                icon: Icons.sync,
                data: _mapValue(data['full']),
                primaryKeys: const [
                  'ok',
                  'reason',
                  'matchesChanged',
                  'finalMatchesChanged',
                  'groupMatches',
                  'totalMatches',
                  'updatedAt',
                  'error',
                ],
              ),
              const SizedBox(height: 12),
              _StatusCard(
                title: 'Score Audit',
                icon: Icons.fact_check,
                data: _mapValue(data['scoreAudit']),
                primaryKeys: const [
                  'ok',
                  'reason',
                  'leagueCount',
                  'activeMembers',
                  'finalMatches',
                  'scoredTips',
                  'standingsWritten',
                  'standingsDeleted',
                  'duplicateTipsDeleted',
                  'orphanTipsDeleted',
                  'updatedAt',
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.icon,
    required this.data,
    required this.primaryKeys,
  });

  final String title;
  final IconData icon;
  final Map<String, dynamic> data;
  final List<String> primaryKeys;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ok = data['ok'] == true;
    final hasError = data['ok'] == false || data['error'] != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  hasError
                      ? Icons.error
                      : ok
                          ? Icons.check_circle
                          : Icons.help,
                  color: hasError ? colorScheme.error : colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.isEmpty)
              Text(
                'Keine Daten.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final key in primaryKeys)
                if (data.containsKey(key))
                  _StatusRow(label: _labelFor(key), value: _format(data[key])),
            if ((data['issues'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                'Issues: ${(data['issues'] as List).length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 142,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return const {};
}

String _labelFor(String key) {
  return switch (key) {
    'ok' => 'Status',
    'changedCount' => 'Writes',
    'liveCandidates' => 'Live-Kandidaten',
    'overlayMatches' => 'Overlay Matches',
    'skippedStaleCount' => 'Stale übersprungen',
    'footballDataStatus' => 'football-data HTTP',
    'footballDataMatches' => 'football-data Matches',
    'matchesChanged' => 'Matches geändert',
    'finalMatchesChanged' => 'Final neu',
    'groupMatches' => 'Gruppenspiele',
    'totalMatches' => 'Matches gesamt',
    'leagueCount' => 'Ligen',
    'activeMembers' => 'Aktive Mitglieder',
    'finalMatches' => 'Finale Matches',
    'scoredTips' => 'Bewertete Tipps',
    'standingsWritten' => 'Standings geschrieben',
    'standingsDeleted' => 'Standings gelöscht',
    'duplicateTipsDeleted' => 'Duplikate gelöscht',
    'orphanTipsDeleted' => 'Orphan Tipps gelöscht',
    'updatedAt' => 'Aktualisiert',
    'reason' => 'Grund',
    'error' => 'Fehler',
    _ => key,
  };
}

String _format(Object? value) {
  if (value == null) return '-';
  if (value is bool) return value ? 'OK' : 'Fehler';
  if (value is Timestamp) {
    return DateFormat('dd.MM. HH:mm:ss').format(value.toDate().toLocal());
  }
  if (value is DateTime) {
    return DateFormat('dd.MM. HH:mm:ss').format(value.toLocal());
  }
  if (value is Map || value is List) return value.toString();
  return '$value';
}
