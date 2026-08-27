import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NetworkGraphTab extends StatefulWidget {
  final String initialPhone;

  const NetworkGraphTab({super.key, this.initialPhone = ""});

  @override
  State<NetworkGraphTab> createState() => _NetworkGraphTabState();
}

class _NetworkGraphTabState extends State<NetworkGraphTab> with SingleTickerProviderStateMixin {
  String _selectedPhone = "";
  List<SuspectProfile> _profiles = [];
  bool _isLoading = false;
  
  NetworkGraphData? _graphData;
  Map<String, Point<double>> _nodePositions = {};
  Map<String, Point<double>> _nodeVelocities = {};
  
  late Ticker _ticker;
  GraphNode? _selectedNode;
  SuspectProfile? _selectedNodeProfile;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadProfiles();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final list = await ApiService.getProfiles();
    setState(() {
      _profiles = list;
      if (list.isNotEmpty) {
        // Default to initialPhone, otherwise use the first high-risk profile, or first profile
        if (widget.initialPhone.isNotEmpty) {
          _selectedPhone = widget.initialPhone;
        } else {
          final highRisk = list.firstWhere((p) => p.riskFlag == 'High', orElse: () => list[0]);
          _selectedPhone = highRisk.phone;
        }
        _fetchGraphData(_selectedPhone);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NetworkGraphTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhone.isNotEmpty && widget.initialPhone != oldWidget.initialPhone) {
      setState(() {
        _selectedPhone = widget.initialPhone;
      });
      _fetchGraphData(widget.initialPhone);
    }
  }

  Future<void> _fetchGraphData(String phone) async {
    setState(() {
      _isLoading = true;
      _selectedNode = null;
      _selectedNodeProfile = null;
    });
    
    _ticker.stop();

    try {
      final data = await ApiService.getGraph(phone);
      
      // Initialize node positions randomly around center
      final rand = Random();
      final Map<String, Point<double>> positions = {};
      final Map<String, Point<double>> velocities = {};

      for (var node in data.nodes) {
        if (node.id == phone) {
          // Center the focused node
          positions[node.id] = const Point(0.0, 0.0);
        } else {
          double angle = rand.nextDouble() * 2 * pi;
          double radius = 100.0 + rand.nextDouble() * 50.0;
          positions[node.id] = Point(cos(angle) * radius, sin(angle) * radius);
        }
        velocities[node.id] = const Point(0.0, 0.0);
      }

      setState(() {
        _graphData = data;
        _nodePositions = positions;
        _nodeVelocities = velocities;
        _isLoading = false;
      });

      _ticker.start();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Force-directed graph simulation tick
  void _onTick(Duration elapsed) {
    if (_graphData == null) return;

    double kr = 2800.0; // Repulsion constant
    double ka = 0.08;   // Attraction constant
    double d0 = 70.0;   // Preferred edge distance
    double damping = 0.82; // Velocity damping
    double timestep = 0.8;

    Map<String, Point<double>> nextPositions = Map.from(_nodePositions);
    Map<String, Point<double>> nextVelocities = Map.from(_nodeVelocities);

    // 1. Repulsion between all node pairs
    for (int i = 0; i < _graphData!.nodes.length; i++) {
      var n1 = _graphData!.nodes[i];
      var p1 = _nodePositions[n1.id]!;
      double fx = 0;
      double fy = 0;

      for (int j = 0; j < _graphData!.nodes.length; j++) {
        if (i == j) continue;
        var n2 = _graphData!.nodes[j];
        var p2 = _nodePositions[n2.id]!;

        double dx = p1.x - p2.x;
        double dy = p1.y - p2.y;
        double distSq = dx * dx + dy * dy;
        double dist = sqrt(distSq);

        if (dist < 1.0) dist = 1.0;
        
        // Coulomb repulsion force
        double f = kr / (dist * dist);
        fx += (dx / dist) * f;
        fy += (dy / dist) * f;
      }

      // 2. Attraction along edges
      for (var link in _graphData!.links) {
        if (link.source == n1.id || link.target == n1.id) {
          String otherId = (link.source == n1.id) ? link.target : link.source;
          var p2 = _nodePositions[otherId];
          if (p2 == null) continue;

          double dx = p2.x - p1.x;
          double dy = p2.y - p1.y;
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 1.0) dist = 1.0;

          // Hooke's Law attraction force
          double f = ka * (dist - d0);
          fx += (dx / dist) * f;
          fy += (dy / dist) * f;
        }
      }

      // 3. Central gravity (slow pull to center (0,0))
      double distToCenter = sqrt(p1.x * p1.x + p1.y * p1.y);
      if (distToCenter > 1.0) {
        fx -= (p1.x / distToCenter) * 0.45;
        fy -= (p1.y / distToCenter) * 0.45;
      }

      // 4. Don't move the focused center suspect node
      if (n1.id == _selectedPhone) {
        fx = 0;
        fy = 0;
      }

      // Apply force to velocity
      double vx = (nextVelocities[n1.id]!.x + fx) * damping;
      double vy = (nextVelocities[n1.id]!.y + fy) * damping;

      nextVelocities[n1.id] = Point(vx, vy);

      // Apply velocity to position
      double px = p1.x + vx * timestep;
      double py = p1.y + vy * timestep;
      nextPositions[n1.id] = Point(px, py);
    }

    setState(() {
      _nodePositions = nextPositions;
      _nodeVelocities = nextVelocities;
    });
  }

  void _onNodeTapped(GraphNode node) async {
    setState(() {
      _selectedNode = node;
    });

    // Check if the tapped node is a known person in our system
    // Node ID might be phone number directly, or formatted bank ID: 'acct:XXXX2584'
    String cleanId = node.id.replaceFirst('acct:', '');
    
    // Find suspect profile either by phone or by bank account matching
    final profiles = await ApiService.getProfiles();
    final profile = profiles.firstWhere(
      (p) => p.phone == cleanId || p.bankAcc == cleanId,
      orElse: () => SuspectProfile(
        photoId: '', name: node.label, phone: node.id, email: '', 
        socialPlatform: '', socialHandle: '', bankAcc: '', aadharFake: '', 
        riskScore: 0.0, riskFlag: 'Low'
      ),
    );

    if (profile.name != node.label || profile.phone == node.id) {
      setState(() {
        _selectedNodeProfile = profile;
      });
    } else {
      setState(() {
        _selectedNodeProfile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MODULE 04', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Entity Match Network', style: AppTheme.displayStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          'Visualize interconnected call and financial networks centering on the suspect. Red connections indicate high risk.',
          style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Suspect selector
        if (_profiles.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AppTheme.panel,
                value: _selectedPhone,
                items: _profiles.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.phone,
                    child: Text(
                      'Focus Network: ${p.name}',
                      style: AppTheme.monoStyle(color: AppTheme.text),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPhone = val;
                    });
                    _fetchGraphData(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildLegendItem('Known Person', AppTheme.cyan),
            _buildLegendItem('Unregistered', AppTheme.textFaint),
            _buildLegendItem('Call Link', AppTheme.green, isLine: true),
            _buildLegendItem('Money Link', AppTheme.amber, isLine: true),
            _buildLegendItem('Flagged Link', AppTheme.red, isLine: true, isThick: true),
          ],
        ),
        const SizedBox(height: 14),

        // Graph Box
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: AppTheme.amber))
                else if (_graphData != null)
                  InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(400),
                    minScale: 0.1,
                    maxScale: 2.0,
                    child: SizedBox(
                      width: 1000,
                      height: 1000,
                      child: GestureDetector(
                        onTapUp: (details) {
                          // Find tapped node
                          Offset localOffset = details.localPosition;
                          
                          // Translate logic: center of 1000x1000 widget is (500,500)
                          double graphX = localOffset.dx - 500;
                          double graphY = localOffset.dy - 500;

                          GraphNode? tapped;
                          double minDistance = 25.0; // Click radius target

                          for (var node in _graphData!.nodes) {
                            var pos = _nodePositions[node.id];
                            if (pos == null) continue;
                            double dx = pos.x - graphX;
                            double dy = pos.y - graphY;
                            double dist = sqrt(dx * dx + dy * dy);
                            if (dist < minDistance) {
                              minDistance = dist;
                              tapped = node;
                            }
                          }

                          if (tapped != null) {
                            _onNodeTapped(tapped);
                          }
                        },
                        child: CustomPaint(
                          size: const Size(1000, 1000),
                          painter: NetworkGraphPainter(
                            nodes: _graphData!.nodes,
                            links: _graphData!.links,
                            positions: _nodePositions,
                            selectedPhone: _selectedPhone,
                            selectedNodeId: _selectedNode?.id,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Info Overlay at bottom of graph
                if (_selectedNode != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _buildNodeDetailCard(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isLine = false, bool isThick = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(
            width: 14,
            height: isThick ? 3.5 : 1.5,
            color: color,
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildNodeDetailCard() {
    final node = _selectedNode!;
    final isKnown = _selectedNodeProfile != null && _selectedNodeProfile!.photoId.isNotEmpty;
    
    Color riskColor = node.risk == 'High'
        ? AppTheme.red
        : (node.risk == 'Medium' ? AppTheme.amber : AppTheme.cyan);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    isKnown ? _selectedNodeProfile!.name.substring(0, 1) : '?',
                    style: AppTheme.displayStyle(color: riskColor, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.label, style: AppTheme.sansStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      isKnown
                          ? '${_selectedNodeProfile!.phone} • ${_selectedNodeProfile!.email}'
                          : node.id.contains('acct:')
                              ? 'Bank Account Reference'
                              : 'Unregistered Number',
                      style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (isKnown) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_selectedNodeProfile!.riskFlag} risk',
                    style: AppTheme.monoStyle(color: riskColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}

class NetworkGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  final Map<String, Point<double>> positions;
  final String selectedPhone;
  final String? selectedNodeId;

  NetworkGraphPainter({
    required this.nodes,
    required this.links,
    required this.positions,
    required this.selectedPhone,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Translate origin (0,0) to center of layout canvas
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // 1. Draw link lines
    for (var link in links) {
      var p1 = positions[link.source];
      var p2 = positions[link.target];
      if (p1 == null || p2 == null) continue;

      Color lineColor = AppTheme.green;
      double strokeWidth = 1.2;

      if (link.flagged) {
        lineColor = AppTheme.red;
        strokeWidth = 2.5;
      } else if (link.type == 'txn') {
        lineColor = AppTheme.amber;
      }

      final paint = Paint()
        ..color = lineColor.withOpacity(0.65)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
    }

    // 2. Draw node nodes
    for (var node in nodes) {
      var pos = positions[node.id];
      if (pos == null) continue;

      bool isPerson = node.type == 'person';
      double radius = isPerson ? 13.0 : 8.0;

      Color nodeColor = AppTheme.cyan;
      if (node.risk == 'High') {
        nodeColor = AppTheme.red;
      } else if (node.risk == 'Medium') {
        nodeColor = AppTheme.amber;
      } else if (!isPerson) {
        nodeColor = AppTheme.textFaint;
      }

      // Highlight selected node
      if (node.id == selectedNodeId) {
        final highlightPaint = Paint()
          ..color = AppTheme.text.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(pos.x, pos.y), radius + 6.0, highlightPaint);
      }

      // Inner fill
      final fillPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      // Outer border
      final borderPaint = Paint()
        ..color = AppTheme.bg
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(pos.x, pos.y), radius, fillPaint);
      canvas.drawCircle(Offset(pos.x, pos.y), radius, borderPaint);

      // Label text
      final textSpan = TextSpan(
        text: node.label.length > 10 ? '${node.label.substring(0, 9)}..' : node.label,
        style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 8.5, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      // Draw label offset slightly below/next to the node
      textPainter.paint(canvas, Offset(pos.x + radius + 3.0, pos.y - 4.5));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NetworkGraphPainter oldDelegate) {
    return true; // Positions update on every tick, so repaint constantly
  }
}
