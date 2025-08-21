import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:predigt_upload_v2/providers/app_state.dart';
import 'package:predigt_upload_v2/screens/overview_screen.dart';
import 'config_screen.dart';
import 'livestream_selection_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(configProvider);

    return Scaffold(
      body: configState.isConfigured ? _MainTabs() : const ConfigScreen(),
    );
  }
}

    class _MainTabs extends StatefulWidget {
      @override
      State<_MainTabs> createState() => _MainTabsState();
    }

    class _MainTabsState extends State<_MainTabs> {
      final _controller = PageController();
      int _index = 0;
      @override
      Widget build(BuildContext context) {
        return Scaffold(
          body: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              LivestreamSelectionScreen(),
              OverviewScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              _controller.jumpToPage(i);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.video_library), label: 'Livestreams'),
              NavigationDestination(icon: Icon(Icons.list), label: 'Übersicht'),
            ],
          ),
        );
      }
    }