import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BankLookupTab extends StatefulWidget {
  final String initialPhone;

  const BankLookupTab({super.key, this.initialPhone = ""});

  @override
  State<BankLookupTab> createState() => _BankLookupTabState();
}

class _BankLookupTabState extends State<BankLookupTab> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";
  List<BankTransaction> _txns = [];
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
  void didUpdateWidget(covariant BankLookupTab oldWidget) {
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
        _txns = [];
        _metrics = {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final records = await ApiService.getBank(phone);
      final riskInfo = await ApiService.getLiveRisk(phone);
      
      setState(() {
        _txns = records;
        _metrics = riskInfo['features'] ?? {};
        if (records.isEmpty) {
          _errorMessage = "No transactions found for the linked account.";
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching bank data: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MODULE 03', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Bank Ledger Lookup', style: AppTheme.displayStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text(
          'Query suspect bank details using phone identity to fetch the legal bank statement feed, monitoring flow metrics and anomalies.',
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
                Text('Fetching official bank statement...', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
              ],
            ),
          ),
        ],

        // Content
        if (!_isLoading && _txns.isNotEmpty) ...[
          const SizedBox(height: 20),
          
          // Metrics Grid
          Row(
            children: [
              Expanded(child: _buildMetricBox('TRANSACTIONS', _metrics['total_txns']?.toString() ?? '${_txns.length}')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('TOTAL VOL', currencyFormatter.format(_metrics['total_amount'] ?? 650000))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('MAX SINGLE', currencyFormatter.format(_metrics['max_single_txn'] ?? 500000))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricBox('UNLINKED', _metrics['txns_to_unlinked']?.toString() ?? '2')),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          Text('TRANSACTION LOGS', style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ListView
          Expanded(
            child: ListView.builder(
              itemCount: _txns.length,
              itemBuilder: (context, index) {
                final txn = _txns[index];
                return _buildTxnLogItem(txn, currencyFormatter);
              },
            ),
          ),
        ] else if (!_isLoading && _txns.isEmpty && _errorMessage.isEmpty) ...[
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
            textAlign: TextAlign.center,
            style: AppTheme.displayStyle(color: AppTheme.amber, fontSize: 14),
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

  Widget _buildTxnLogItem(BankTransaction txn, NumberFormat format) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: txn.flag ? AppTheme.redDim : AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: txn.flag ? AppTheme.red : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Receiver Name
              Text(
                txn.toName.isNotEmpty ? txn.toName : txn.toAccount,
                style: AppTheme.sansStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              // Amount
              Text(
                format.format(txn.amountInr),
                style: AppTheme.monoStyle(
                  color: txn.flag ? AppTheme.red : AppTheme.amber, 
                  fontSize: 14, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Account Details + Type
              Text(
                'To Account: ${txn.toAccount} • ${txn.type}',
                style: AppTheme.monoStyle(color: AppTheme.textDim, fontSize: 11),
              ),
              // Timestamp
              Text(
                txn.timestamp,
                style: AppTheme.monoStyle(color: AppTheme.textFaint, fontSize: 11),
              ),
            ],
          ),
          if (txn.flag) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⚠️ CRITICAL: FLAGGED ANOMALY LAUNDERING RISK',
                style: AppTheme.monoStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
