import 'package:flutter/material.dart';
import 'screens/photo_scan_tab.dart';
import 'screens/cdr_lookup_tab.dart';
import 'screens/bank_lookup_tab.dart';
import 'screens/network_graph_tab.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initialize();
  runApp(const NetTraceApp());
}

class NetTraceApp extends StatelessWidget {
  const NetTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetTrace AI — Field Investigation Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainDashboardScreen(),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _activeTabIndex = 0;
  String _focusedPhone = ""; // Selected suspect's phone number shared across tabs
  bool _isBackendLive = false;

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
  }

  Future<void> _checkBackendStatus() async {
    bool live = await ApiService.checkHealth();
    if (mounted) {
      setState(() {
        _isBackendLive = live;
      });
    }
  }

  void _onSuspectSelected(String phone) {
    setState(() {
      _focusedPhone = phone;
    });
  }

  void _showSettingsDialog() {
    final TextEditingController urlController = TextEditingController(text: ApiService.baseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Text(
            'API CONFIGURATION',
            style: AppTheme.displayStyle(color: AppTheme.amber, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure the connection string to the FastAPI backend service.',
                style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                style: AppTheme.monoStyle(color: AppTheme.text),
                decoration: const InputDecoration(
                  labelText: 'API HOST URL',
                  labelStyle: TextStyle(color: AppTheme.amber),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: AppTheme.monoStyle(color: AppTheme.textDim)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  ApiService.baseUrl = urlController.text.trim();
                });
                _checkBackendStatus();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text('SAVE', style: AppTheme.monoStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check width for responsive layout (max-width of 520px in web container)
    double width = MediaQuery.of(context).size.width;
    bool isLargeScreen = width > 600;

    Widget bodyContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: IndexedStack(
        index: _activeTabIndex,
        children: [
          PhotoScanTab(onSuspectSelected: _onSuspectSelected),
          CdrLookupTab(initialPhone: _focusedPhone),
          BankLookupTab(initialPhone: _focusedPhone),
          NetworkGraphTab(initialPhone: _focusedPhone),
        ],
      ),
    );

    Widget dashboardContent = Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Row(
          children: [
            // Brand Logo indicator
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.amber, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.radar, size: 16, color: AppTheme.amber),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NetTrace AI',
                  style: AppTheme.displayStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Unified Investigation Analytics',
                  style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Connection Status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              backgroundColor: _isBackendLive ? AppTheme.greenDim : AppTheme.redDim,
              side: BorderSide(color: _isBackendLive ? AppTheme.green : AppTheme.red),
              label: Text(
                _isBackendLive ? 'LIVE' : 'DEMO MODE',
                style: AppTheme.monoStyle(
                  color: _isBackendLive ? AppTheme.green : AppTheme.red,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textDim),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppTheme.border),
          
          // Navigation Tab Bar
          Container(
            color: AppTheme.bg,
            child: Row(
              children: [
                _buildTabButton(0, Icons.camera_alt, 'Photo Scan'),
                _buildTabButton(1, Icons.phone, 'Call Detail'),
                _buildTabButton(2, Icons.account_balance_wallet, 'Ledgers'),
                _buildTabButton(3, Icons.hub, 'Network'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Main Screen tab view
          Expanded(
            child: bodyContent,
          ),
        ],
      ),
    );

    if (isLargeScreen) {
      // Center and constrain layout similar to CSS max-width:520px in HTML
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            width: 520,
            decoration: const BoxDecoration(
              color: AppTheme.bg,
              border: Border(
                left: BorderSide(color: AppTheme.border),
                right: BorderSide(color: AppTheme.border),
              ),
            ),
            child: dashboardContent,
          ),
        ),
      );
    }

    return dashboardContent;
  }

  Widget _buildTabButton(int index, IconData icon, String text) {
    bool isActive = _activeTabIndex == index;
    Color color = isActive ? AppTheme.amber : AppTheme.textDim;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.amber : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                text.toUpperCase(),
                style: AppTheme.monoStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
