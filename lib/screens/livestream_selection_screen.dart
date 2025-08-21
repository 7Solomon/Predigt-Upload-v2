import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../widgets/life_stream_card.dart';
import 'detail_screen.dart';

class LivestreamSelectionScreen extends ConsumerWidget {
  const LivestreamSelectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livestreamsAsync = ref.watch(livestreamProvider(10));
    return Scaffold(
      appBar: AppBar(title: const Text('Letzte Livestreams')),
      body: livestreamsAsync.when(
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(livestreamProvider),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final card = LivestreamCard(
                livestream: list[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailScreen(livestream: list[i])),
                ),
              );
              return card;
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          print(e);
          return Center(child: Text('Fehler: $e'));
        },
      ),
    );
  }
}

