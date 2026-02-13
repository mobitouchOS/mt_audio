import 'package:flutter/material.dart';
import 'package:mt_audio_example/pages/home_page.dart';
import 'package:mt_audio_example/pages/queue_page.dart';
import 'package:mt_audio_example/pages/settings_page.dart';
import 'package:mt_audio_example/pages/widgets_page.dart';
import 'package:mt_audio_example/providers/player_provider.dart';
import 'package:mt_audio_example/widgets/mini_player.dart';

/// Main application widget.
class MtAudioExampleApp extends StatelessWidget {
  const MtAudioExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mt_audio Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

/// Main scaffold with bottom navigation and mini player.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    WidgetsPage(),
    QueuePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player shown when audio is loaded
          StreamBuilder(
            stream: player.currentItemStream,
            builder: (context, snapshot) {
              final hasItem = snapshot.data != null;
              if (!hasItem) return const SizedBox.shrink();
              return const MiniPlayer();
            },
          ),
          // Bottom navigation
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Player',
              ),
              NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                selectedIcon: Icon(Icons.widgets),
                label: 'Widgets',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: 'Queue',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Debug',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
