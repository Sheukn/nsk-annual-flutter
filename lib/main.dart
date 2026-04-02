import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pa_snk/features/board/board_list_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'features/gallery/gallery_view.dart';
import 'services/connection_service.dart';
import 'services/photo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter PA SNK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter PA SNK'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late ConnectionService _connectionService;
  late PhotoService _photoService;

  @override
  void initState() {
    super.initState();
    _connectionService = ConnectionService();
    _photoService = PhotoService();
    _connectionService.checkServerHealth(); // Check once at startup
    _connectionService.startHealthCheck(); // Start periodic health checks
  }

  @override
  void dispose() {
    _connectionService.dispose();
    _photoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      GalleryView(photoService: _photoService),
      const BoardListView(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: widgetOptions.elementAt(_selectedIndex),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _connectionService.connectionStatus,
            builder: (context, isConnected, child) {
              if (!isConnected) {
                return GestureDetector(
                  onTap: () => _connectionService.reconnect(),
                  child: Container(
                    color: Colors.red[400],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No server connection - Tap to retry',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Gallery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_quilt),
            label: 'Board',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
