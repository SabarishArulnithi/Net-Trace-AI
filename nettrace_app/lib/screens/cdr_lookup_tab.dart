import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CdrLookupTab extends StatefulWidget {
  final String initialPhone;

  const CdrLookupTab({super.key, this.initialPhone = ""});

  @override
  State<CdrLookupTab> createState() => _CdrLookupTabState();
}

class _CdrLookupTabState extends State<CdrLookupTab> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";
  List<CdrRecord> _calls = [];
  Map<String, dynamic> _metrics = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone.isNotEmpty) {
      _phoneController.text = widget.initialPhone;
      _performLookup(widget.initialPhone);
    }
  }

  @override
  void didUpdateWidget(covariant CdrLookupTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhone.isNotEmpty && widget.initialPhone != oldWidget.initialPhone) {
      _phoneController.text = widget.initialPhone;
      _performLookup(widget.initialPhone);
    }
  }

  Future<void> _performLookup(String phone) async {
    if (phone.length < 10) {
      setState(() {
        _errorMessage = "Enter a valid 10-digit phone number.";
        _calls = [];
        _metrics = {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final records = await ApiService.getCdr(phone);
      final riskInfo = await ApiService.getLiveRisk(phone);
      
      setState(() {
        _calls = records;
        _metrics = riskInfo['features'] ?? {};
        if (records.isEmpty) {
          _errorMessage = "No CDR records found for this phone number.";
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching CDR data: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MODULE 02', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Call Detail Records', style: AppTheme.displayStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          'Enter a suspect mobile number to request telecommunication call detail records and evaluate frequent or flagged contacts.',
          style: AppTheme.sansStyle(color: AppTheme.textDim, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Input Field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                style: AppTheme.monoStyle(color: AppTheme.text, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Enter 10-digit number (e.g. 9026542351)',
                ),
                onSubmitted: (val) => _performLookup(val),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _performLookup(_phoneController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              child: const Icon(Icons.search),
            ),
          ],
        ),

        // Error message
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_errorMessage, style: AppTheme.sansStyle(color: AppTheme.red, fontSize: 12)),
        ],

        // Loading
        if (_isLoading) ...[
          const SizedBox(height: 30),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.amber),
                SizedBox(height: 16),
                Text('Fetching authorized CDR logs...', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
              ],
            ),
          ),
        ],

        // Content
        if (!_isLoading && _calls.isNotEmpty) ...[
          const SizedBox(height: 20),
          
          // Metrics Grid
          Row(
            children: [
              Expanded(child: _buildMetricBox('TOTAL CALLS', _metrics['total_calls']?.toString() ?? '${_calls.length}')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('UNIQUE CONTACTS', _metrics['unique_contacts']?.toString() ?? '3')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('UNKNOWN CONTACTS', _metrics['calls_to_unknown']?.toString() ?? '1')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('MAX / DAY', _metrics['max_calls_per_day']?.toString() ?? '2')),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          Text('CALL LOG HISTORY', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ListView
          Expanded(
            child: ListView.builder(
              itemCount: _calls.length,
              itemBuilder: (context, index) {
                final call = _calls[index];
                return _buildCallLogItem(call);
              },
            ),
          ),
        ] else if (!_isLoading && _calls.isEmpty && _errorMessage.isEmpty) ...[
          const Expanded(
            child: Center(
              child: Text(
                'Enter phone number above to start evaluation.',
                style: TextStyle(color: AppTheme.textFaint),
              ),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildMetricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.displayStyle(color: AppTheme.amber, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCallLogItem(CdrRecord call) {
    String duration = '${(call.durationSec / 60).floor()}m ${call.durationSec % 60}s';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: call.flag ? AppTheme.redDim : AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: call.flag ? AppTheme.red : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Contact Name / Number
              Text(
                call.receiverName.isNotEmpty ? call.receiverName : call.receiverPhone,
                style: AppTheme.sansStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              // Timestamp
              Text(
                call.timestamp,
                style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Phone + Type
              Text(
                '${call.receiverPhone} • Outgoing',
                style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 11),
              ),
              // Duration + Location
              Text(
                '$duration • ${call.towerLocation}',
                style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 11),
              ),
            ],
          ),
          if (call.flag) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⚠️ FLAGGED ANOMALY',
                style: AppTheme.monoStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
