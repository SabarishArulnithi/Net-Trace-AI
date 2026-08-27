class SuspectProfile {
  final String photoId;
  final String name;
  final String phone;
  final String email;
  final String socialPlatform;
  final String socialHandle;
  final String bankAcc;
  final String aadharFake;
  final double riskScore;
  final String riskFlag;

  SuspectProfile({
    required this.photoId,
    required this.name,
    required this.phone,
    required this.email,
    required this.socialPlatform,
    required this.socialHandle,
    required this.bankAcc,
    required this.aadharFake,
    required this.riskScore,
    required this.riskFlag,
  });

  factory SuspectProfile.fromJson(Map<String, dynamic> json) {
    return SuspectProfile(
      photoId: json['photo_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      socialPlatform: json['social_platform'] ?? '',
      socialHandle: json['social_handle'] ?? '',
      bankAcc: json['bank_acc'] ?? '',
      aadharFake: json['aadhar_fake'] ?? '',
      riskScore: double.tryParse(json['risk_score']?.toString() ?? '0.0') ?? 0.0,
      riskFlag: json['risk_flag'] ?? 'Low',
    );
  }
}

class CdrRecord {
  final String callId;
  final String callerPhone;
  final String callerName;
  final String receiverPhone;
  final String receiverName;
  final String timestamp;
  final int durationSec;
  final String towerLocation;
  final bool flag;

  CdrRecord({
    required this.callId,
    required this.callerPhone,
    required this.callerName,
    required this.receiverPhone,
    required this.receiverName,
    required this.timestamp,
    required this.durationSec,
    required this.towerLocation,
    required this.flag,
  });

  factory CdrRecord.fromJson(Map<String, dynamic> json) {
    // flag in dataset is either empty or '1' / true
    dynamic f = json['flag'];
    bool isFlagged = f == true || f == 1 || f == '1' || f == 'true';
    return CdrRecord(
      callId: json['call_id'] ?? '',
      callerPhone: json['caller_phone'] ?? '',
      callerName: json['caller_name'] ?? '',
      receiverPhone: json['receiver_phone'] ?? '',
      receiverName: json['receiver_name'] ?? '',
      timestamp: json['timestamp'] ?? '',
      durationSec: int.tryParse(json['duration_sec']?.toString() ?? '0') ?? 0,
      towerLocation: json['tower_location'] ?? '',
      flag: isFlagged,
    );
  }
}

class BankTransaction {
  final String txnId;
  final String fromAccount;
  final String fromName;
  final String toAccount;
  final String toName;
  final double amountInr;
  final String timestamp;
  final String type;
  final bool flag;

  BankTransaction({
    required this.txnId,
    required this.fromAccount,
    required this.fromName,
    required this.toAccount,
    required this.toName,
    required this.amountInr,
    required this.timestamp,
    required this.type,
    required this.flag,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    dynamic f = json['flag'];
    bool isFlagged = f == true || f == 1 || f == '1' || f == 'true';
    return BankTransaction(
      txnId: json['txn_id'] ?? '',
      fromAccount: json['from_account'] ?? '',
      fromName: json['from_name'] ?? '',
      toAccount: json['to_account'] ?? '',
      toName: json['to_name'] ?? '',
      amountInr: double.tryParse(json['amount_inr']?.toString() ?? '0') ?? 0.0,
      timestamp: json['timestamp'] ?? '',
      type: json['type'] ?? '',
      flag: isFlagged,
    );
  }
}

class GraphNode {
  final String id;
  final String label;
  final String type; // 'person' or 'unknown'
  final String risk; // 'Low', 'Medium', 'High'

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.risk,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      type: json['type'] ?? 'unknown',
      risk: json['risk'] ?? 'Low',
    );
  }
}

class GraphLink {
  final String source;
  final String target;
  final String type; // 'call' or 'txn'
  final bool flagged;

  GraphLink({
    required this.source,
    required this.target,
    required this.type,
    required this.flagged,
  });

  factory GraphLink.fromJson(Map<String, dynamic> json) {
    return GraphLink(
      source: json['source'] ?? '',
      target: json['target'] ?? '',
      type: json['type'] ?? 'call',
      flagged: json['flagged'] == true || json['flagged'] == 1 || json['flagged'] == '1' || json['flagged'] == 'true',
    );
  }
}

class NetworkGraphData {
  final List<GraphNode> nodes;
  final List<GraphLink> links;

  NetworkGraphData({
    required this.nodes,
    required this.links,
  });

  factory NetworkGraphData.fromJson(Map<String, dynamic> json) {
    var nodesList = json['nodes'] as List? ?? [];
    var linksList = json['links'] as List? ?? [];
    return NetworkGraphData(
      nodes: nodesList.map((n) => GraphNode.fromJson(n)).toList(),
      links: linksList.map((l) => GraphLink.fromJson(l)).toList(),
    );
  }
}
