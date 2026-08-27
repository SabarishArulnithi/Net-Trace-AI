import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/profile.dart';

class ApiService {
  // Configurable base URL
  static String baseUrl = 'http://localhost:8000';

  // Automatically update base URL depending on platform
  static void initialize() {
    if (!kIsWeb && Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8000'; // Special loopback address for Android Emulators
    }
  }

  // Check if backend is alive
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  // Get list of profiles
  static Future<List<SuspectProfile>> getProfiles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/profiles')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((p) => SuspectProfile.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching profiles from API, using mock: $e');
    }
    // Mock Fallback
    return _mockProfiles.map((p) => SuspectProfile.fromJson(p)).toList();
  }

  // Get profile live risk inference
  static Future<Map<String, dynamic>> getLiveRisk(String phone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/risk/$phone')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting live risk from API, using mock: $e');
    }
    // Mock Fallback
    final profile = _mockProfiles.firstWhere((p) => p['phone'] == phone, orElse: () => _mockProfiles[0]);
    return {
      'phone': phone,
      'name': profile['name'],
      'risk_score': double.tryParse(profile['risk_score'].toString()) ?? 0.0,
      'risk_flag': profile['risk_flag'],
      'features': {
        'total_calls': 12,
        'unique_contacts': 4,
        'calls_to_unknown': profile['risk_flag'] == 'High' ? 8 : 1,
        'max_calls_per_day': 5,
        'total_txns': 8,
        'total_amount': profile['risk_flag'] == 'High' ? 650000.0 : 16500.0,
        'max_single_txn': profile['risk_flag'] == 'High' ? 500000.0 : 10000.0,
        'txns_to_unlinked': profile['risk_flag'] == 'High' ? 6 : 2,
      }
    };
  }

  // Perform photo match
  static Future<SuspectProfile> matchPhoto(String seed) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/match-photo?seed=$seed')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return SuspectProfile.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error matching photo from API, using mock: $e');
    }
    // Deterministic mock match based on seed hash length or characters
    int index = seed.hashCode.abs() % _mockProfiles.length;
    return SuspectProfile.fromJson(_mockProfiles[index]);
  }

  // Get Call Detail Records
  static Future<List<CdrRecord>> getCdr(String phone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/cdr/$phone')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((c) => CdrRecord.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching CDR from API, using mock: $e');
    }
    // Mock Fallback
    final logs = _mockCdrLogs[phone] ?? _mockCdrLogs['9026542351']!;
    return logs.map((c) => CdrRecord.fromJson(c)).toList();
  }

  // Get Bank Transactions
  static Future<List<BankTransaction>> getBank(String phone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/bank/$phone')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((t) => BankTransaction.fromJson(t)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching bank logs from API, using mock: $e');
    }
    // Mock Fallback
    final logs = _mockBankTxns[phone] ?? _mockBankTxns['9026542351']!;
    return logs.map((t) => BankTransaction.fromJson(t)).toList();
  }

  // Get Entity Relationship Graph
  static Future<NetworkGraphData> getGraph(String phone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/graph/$phone')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return NetworkGraphData.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching graph from API, using mock: $e');
    }
    // Mock Fallback
    final graph = _mockGraphs[phone] ?? _mockGraphs['9026542351']!;
    return NetworkGraphData.fromJson(graph);
  }

  // -----------------------------------------------------------------
  // MOCK DATASETS
  // -----------------------------------------------------------------

  static final List<Map<String, dynamic>> _mockProfiles = [
    {
      "photo_id": "face_001.jpg",
      "name": "Gowtham Pillai",
      "phone": "9026542351",
      "email": "gowtham.p1@fakemail.com",
      "social_platform": "Telegram",
      "social_handle": "@gowtham_dev",
      "bank_acc": "XXXX2584",
      "aadhar_fake": "XXXX-XXXX-0001",
      "risk_score": "9.6",
      "risk_flag": "Low"
    },
    {
      "photo_id": "face_007.jpg",
      "name": "Vijay Patel",
      "phone": "9871012269",
      "email": "vijay.p7@fakemail.com",
      "social_platform": "Telegram",
      "social_handle": "@vijay_dev",
      "bank_acc": "XXXX7252",
      "aadhar_fake": "XXXX-XXXX-0007",
      "risk_score": "71.4",
      "risk_flag": "High"
    },
    {
      "photo_id": "face_021.jpg",
      "name": "Kumar Achari",
      "phone": "9435346247",
      "email": "kumar.a21@fakemail.com",
      "social_platform": "Instagram",
      "social_handle": "@kumar_007",
      "bank_acc": "XXXX1152",
      "aadhar_fake": "XXXX-XXXX-0021",
      "risk_score": "46.5",
      "risk_flag": "Medium"
    },
    {
      "photo_id": "face_011.jpg",
      "name": "Farook Iyer",
      "phone": "9171822782",
      "email": "farook.i11@fakemail.com",
      "social_platform": "Telegram",
      "social_handle": "@farook_official",
      "bank_acc": "XXXX4470",
      "aadhar_fake": "XXXX-XXXX-0011",
      "risk_score": "15.7",
      "risk_flag": "Low"
    },
  ];

  static final Map<String, List<Map<String, dynamic>>> _mockCdrLogs = {
    '9026542351': [
      {
        "call_id": "C00001",
        "caller_phone": "9026542351",
        "caller_name": "Gowtham Pillai",
        "receiver_phone": "9871012269",
        "receiver_name": "Vijay Patel",
        "timestamp": "2026-08-01 17:29",
        "duration_sec": 354,
        "tower_location": "Erode-Hub",
        "flag": ""
      },
      {
        "call_id": "C00002",
        "caller_phone": "9026542351",
        "caller_name": "Gowtham Pillai",
        "receiver_phone": "9435346247",
        "receiver_name": "Kumar Achari",
        "timestamp": "2026-08-02 13:15",
        "duration_sec": 419,
        "tower_location": "Chennai-Central",
        "flag": ""
      },
      {
        "call_id": "C00003",
        "caller_phone": "9026542351",
        "caller_name": "Gowtham Pillai",
        "receiver_phone": "9171822782",
        "receiver_name": "Farook Iyer",
        "timestamp": "2026-08-03 09:02",
        "duration_sec": 120,
        "tower_location": "Madurai-East",
        "flag": ""
      }
    ],
    '9871012269': [
      {
        "call_id": "C00101",
        "caller_phone": "9871012269",
        "caller_name": "Vijay Patel",
        "receiver_phone": "9999900011",
        "receiver_name": "Unknown Contact",
        "timestamp": "2026-08-05 23:45",
        "duration_sec": 62,
        "tower_location": "Delhi-Border",
        "flag": "1"
      },
      {
        "call_id": "C00102",
        "caller_phone": "9871012269",
        "caller_name": "Vijay Patel",
        "receiver_phone": "9999900022",
        "receiver_name": "Unknown Contact",
        "timestamp": "2026-08-06 02:10",
        "duration_sec": 45,
        "tower_location": "Delhi-Border",
        "flag": "1"
      },
      {
        "call_id": "C00001",
        "caller_phone": "9026542351",
        "caller_name": "Gowtham Pillai",
        "receiver_phone": "9871012269",
        "receiver_name": "Vijay Patel",
        "timestamp": "2026-08-01 17:29",
        "duration_sec": 354,
        "tower_location": "Erode-Hub",
        "flag": ""
      }
    ]
  };

  static final Map<String, List<Map<String, dynamic>>> _mockBankTxns = {
    '9026542351': [
      {
        "txn_id": "T00001",
        "from_account": "XXXX2584",
        "from_name": "Gowtham Pillai",
        "to_account": "XXXX1152",
        "to_name": "Kumar Achari",
        "amount_inr": 2500.0,
        "timestamp": "2026-08-02 13:00",
        "type": "IMPS",
        "flag": ""
      },
      {
        "txn_id": "T00002",
        "from_account": "XXXX2584",
        "from_name": "Gowtham Pillai",
        "to_account": "XXXX4470",
        "to_name": "Farook Iyer",
        "amount_inr": 4000.0,
        "timestamp": "2026-08-03 09:00",
        "type": "UPI",
        "flag": ""
      }
    ],
    '9871012269': [
      {
        "txn_id": "T00201",
        "from_account": "XXXX7252",
        "from_name": "Vijay Patel",
        "to_account": "XXXX9999",
        "to_name": "Unlinked Account",
        "amount_inr": 500000.0,
        "timestamp": "2026-08-04 12:00",
        "type": "IMPS",
        "flag": "1"
      },
      {
        "txn_id": "T00202",
        "from_account": "XXXX7252",
        "from_name": "Vijay Patel",
        "to_account": "XXXX8888",
        "to_name": "Unlinked Account",
        "amount_inr": 150000.0,
        "timestamp": "2026-08-05 14:30",
        "type": "RTGS",
        "flag": "1"
      }
    ]
  };

  static final Map<String, Map<String, dynamic>> _mockGraphs = {
    '9026542351': {
      'nodes': [
        {'id': '9026542351', 'label': 'Gowtham Pillai', 'type': 'person', 'risk': 'Low'},
        {'id': '9871012269', 'label': 'Vijay Patel', 'type': 'person', 'risk': 'High'},
        {'id': '9435346247', 'label': 'Kumar Achari', 'type': 'person', 'risk': 'Medium'},
        {'id': '9171822782', 'label': 'Farook Iyer', 'type': 'person', 'risk': 'Low'},
      ],
      'links': [
        {'source': '9026542351', 'target': '9871012269', 'type': 'call', 'flagged': false},
        {'source': '9026542351', 'target': '9435346247', 'type': 'call', 'flagged': false},
        {'source': '9026542351', 'target': '9171822782', 'type': 'call', 'flagged': false},
        {'source': '9026542351', 'target': '9435346247', 'type': 'txn', 'flagged': false},
      ]
    },
    '9871012269': {
      'nodes': [
        {'id': '9871012269', 'label': 'Vijay Patel', 'type': 'person', 'risk': 'High'},
        {'id': '9026542351', 'label': 'Gowtham Pillai', 'type': 'person', 'risk': 'Low'},
        {'id': '9999900011', 'label': '9999900011', 'type': 'unknown', 'risk': 'Low'},
        {'id': 'acct:XXXX9999', 'label': 'XXXX9999', 'type': 'unknown', 'risk': 'Low'},
      ],
      'links': [
        {'source': '9871012269', 'target': '9026542351', 'type': 'call', 'flagged': false},
        {'source': '9871012269', 'target': '9999900011', 'type': 'call', 'flagged': true},
        {'source': '9871012269', 'target': 'acct:XXXX9999', 'type': 'txn', 'flagged': true},
      ]
    }
  };
}
