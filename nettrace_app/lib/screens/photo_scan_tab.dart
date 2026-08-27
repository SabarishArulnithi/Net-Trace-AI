import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PhotoScanTab extends StatefulWidget {
  final Function(String) onSuspectSelected;

  const PhotoScanTab({super.key, required this.onSuspectSelected});

  @override
  State<PhotoScanTab> createState() => _PhotoScanTabState();
}

class _PhotoScanTabState extends State<PhotoScanTab> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  
  bool _isCameraLive = false;
  bool _isScanning = false;
  bool _hasResult = false;
  String _statusText = "";
  
  List<SuspectProfile> _profiles = [];
  SuspectProfile? _selectedProfile;
  SuspectProfile? _scannedProfile;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await ApiService.getProfiles();
    if (mounted) {
      setState(() {
        _profiles = list;
      });
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _startCamera() {
    setState(() {
      _isCameraLive = true;
      _hasResult = false;
      _isScanning = false;
      _scannedProfile = null;
      _statusText = "Camera lens active. Align suspect face in viewfinder.";
    });
  }

  void _simulateScan(SuspectProfile target) {
    setState(() {
      _isCameraLive = false;
      _isScanning = true;
      _statusText = "Running biometric match against databases...";
    });
    _scanController.repeat();

    // After 2 seconds, stop scan and show match
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      
      // Perform live model risk check
      final riskInfo = await ApiService.getLiveRisk(target.phone);
      
      setState(() {
        _scanController.stop();
        _isScanning = false;
        _hasResult = true;
        _scannedProfile = SuspectProfile(
          photoId: target.photoId,
          name: target.name,
          phone: target.phone,
          email: target.email,
          socialPlatform: target.socialPlatform,
          socialHandle: target.socialHandle,
          bankAcc: target.bankAcc,
          aadharFake: target.aadharFake,
          riskScore: double.tryParse(riskInfo['risk_score'].toString()) ?? target.riskScore,
          riskFlag: riskInfo['risk_flag'] ?? target.riskFlag,
        );
        _statusText = "Biometric match found (100% confidence).";
      });
      // Notify parent to update the focus phone in other tabs
      widget.onSuspectSelected(target.phone);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODULE 01', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('On-spot Identity Scan', style: AppTheme.displayStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            'Capture/upload a suspect photo or select a quick-demo profile to run real-time biometric and AI risk anomaly matching.',
            style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Camera Viewfinder Box
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Viewfinder corners
                  const Positioned(top: 16, left: 16, child: _CornerIndicator(isTop: true, isLeft: true)),
                  const Positioned(top: 16, right: 16, child: _CornerIndicator(isTop: true, isLeft: false)),
                  const Positioned(bottom: 16, left: 16, child: _CornerIndicator(isTop: false, isLeft: true)),
                  const Positioned(bottom: 16, right: 16, child: _CornerIndicator(isTop: false, isLeft: false)),

                  // Content in the viewfinder
                  Center(
                    child: _buildViewfinderContent(),
                  ),

                  // Animated scan line
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          left: 0,
                          right: 0,
                          top: _scanAnimation.value * 280, // Approximate height constraint
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.cyan,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyan.withOpacity(0.8),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Select & Action Buttons
          if (_profiles.isNotEmpty) ...[
            Text('QUICK SELECT SUSPECT (DEMO)', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SuspectProfile>(
                  isExpanded: true,
                  dropdownColor: AppTheme.panel,
                  value: _selectedProfile,
                  hint: Text('Select a suspect to auto-match...', style: AppTheme.monoStyle(color: AppTheme.textDim)),
                  items: _profiles.map((p) {
                    return DropdownMenuItem<SuspectProfile>(
                      value: p,
                      child: Text(
                        '${p.name} (${p.riskFlag} Risk)',
                        style: AppTheme.monoStyle(
                          color: p.riskFlag == 'High'
                              ? AppTheme.red
                              : (p.riskFlag == 'Medium' ? AppTheme.amber : AppTheme.green),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProfile = val;
                    });
                    if (val != null) {
                      _simulateScan(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _startCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.panel2,
                    foregroundColor: AppTheme.text,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('OPEN CAMERA', style: AppTheme.monoStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Simulates an upload by picking a random profile
                    if (_profiles.isNotEmpty) {
                      final randomProfile = _profiles[Random().nextInt(_profiles.length)];
                      _simulateScan(randomProfile);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.panel2,
                    foregroundColor: AppTheme.text,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('UPLOAD PHOTO', style: AppTheme.monoStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // Status message
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isScanning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.cyan),
                  )
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusText,
                    style: AppTheme.monoStyle(color: AppTheme.cyan, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          // Suspect Result Profile Card
          if (_hasResult && _scannedProfile != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(_scannedProfile!),
          ],
        ],
      ),
    );
  }

  Widget _buildViewfinderContent() {
    if (_isScanning) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.face, size: 64, color: AppTheme.cyan),
          const SizedBox(height: 12),
          Text('BIOMETRIC SCAN IN PROGRESS', style: AppTheme.monoStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (_isCameraLive) {
      return Container(
        color: Colors.black.withOpacity(0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 50, color: AppTheme.textDim),
            const SizedBox(height: 12),
            Text('CAMERA SIMULATION LIVE', style: AppTheme.monoStyle(color: AppTheme.textDim)),
            const SizedBox(height: 4),
            Text('Point at suspect face', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11)),
          ],
        ),
      );
    }
    if (_hasResult && _scannedProfile != null) {
      // Mock captured face avatar or dynamic image
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.panel2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _scannedProfile!.riskFlag == 'High'
                    ? AppTheme.red
                    : (_scannedProfile!.riskFlag == 'Medium' ? AppTheme.amber : AppTheme.green),
                width: 2.0,
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(_scannedProfile!.name),
                style: AppTheme.displayStyle(
                  fontSize: 28,
                  color: _scannedProfile!.riskFlag == 'High'
                      ? AppTheme.red
                      : (_scannedProfile!.riskFlag == 'Medium' ? AppTheme.amber : AppTheme.green),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CAPTURED BIOMETRICS',
            style: AppTheme.monoStyle(
              color: _scannedProfile!.riskFlag == 'High' ? AppTheme.red : AppTheme.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.center_focus_weak, size: 40, color: AppTheme.textFaint),
        const SizedBox(height: 10),
        Text('No photo captured yet', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 13)),
      ],
    );
  }

  Widget _buildResultCard(SuspectProfile profile) {
    Color riskColor = profile.riskFlag == 'High'
        ? AppTheme.red
        : (profile.riskFlag == 'Medium' ? AppTheme.amber : AppTheme.green);

    Color riskBg = profile.riskFlag == 'High'
        ? AppTheme.redDim
        : (profile.riskFlag == 'Medium' ? AppTheme.amberDim : AppTheme.greenDim);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Avatar and Risk badge
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: riskColor.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    _getInitials(profile.name),
                    style: AppTheme.displayStyle(color: riskColor, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: AppTheme.displayStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.phone} • ${profile.socialHandle}',
                      style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${profile.riskFlag} Risk',
                  style: AppTheme.monoStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderSoft),

          // Detail rows
          _buildDetailRow('Phone Identity', profile.phone),
          _buildDetailRow('Email Account', profile.email),
          _buildDetailRow('Social Footprint', '${profile.socialPlatform} (${profile.socialHandle})'),
          _buildDetailRow('Bank Account ID', profile.bankAcc),
          _buildDetailRow('Aadhaar Reference', profile.aadharFake),

          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSoft),
          const SizedBox(height: 8),

          // Risk Anomaly Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI ANOMALY RISK SCORE', style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 11)),
              Text('${profile.riskScore}%', style: AppTheme.monoStyle(color: riskColor, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: profile.riskScore / 100,
              backgroundColor: AppTheme.panel2,
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.riskFlag == 'High'
                ? '⚠️ CRITICAL: Behaviors deviate drastically from population norms. Isolation forest model flags high probability of financial laundering/telecom fraud.'
                : profile.riskFlag == 'Medium'
                    ? '⚡ ALERT: Moderate deviation detected. Recommending network and ledger verification.'
                    : '✓ NORMAL: Suspect shows standard transactional behavior. No anomalous risk flag matches.',
            style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 13)),
          Text(value, style: AppTheme.monoStyle(color: AppTheme.text, fontSize: 12)),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

class _CornerIndicator extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerIndicator({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const double size = 20;
    const double thickness = 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: isLeft ? 0 : null,
            right: !isLeft ? 0 : null,
            top: isTop ? 0 : null,
            bottom: !isTop ? 0 : null,
            child: Container(
              width: size,
              height: thickness,
              color: AppTheme.amber,
            ),
          ),
          Positioned(
            left: isLeft ? 0 : null,
            right: !isLeft ? 0 : null,
            top: isTop ? 0 : null,
            bottom: !isTop ? 0 : null,
            child: Container(
              width: thickness,
              height: size,
              color: AppTheme.amber,
            ),
          ),
        ],
      ),
    );
  }
}
