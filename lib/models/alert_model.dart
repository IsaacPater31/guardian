import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model representing a single alert.
class AlertModel {
  final String? id;

  /// Alert category: `'detailed'`, `'quick'`, or `'swiped'`.
  final String type;

  /// Emergency type identifier (e.g. `'FIRE'`, `'HEALTH'`, `'POLICE'`).
  final String alertType;

  final String? description;
  final DateTime timestamp;
  final bool isAnonymous;
  final bool shareLocation;
  final LocationData? location;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final List<String>? imageBase64;
  final int viewedCount;
  final List<String> viewedBy;

  /// Community this alert was sent to. `null` for legacy alerts.
  final String? communityId;

  /// Attention status: `'pending'` or `'attended'`. Only officials may update.
  final String alertStatus;

  final int forwardsCount;
  final int reportsCount;

  /// User IDs that have reported this alert (prevents duplicate reports).
  final List<String> reportedBy;

  AlertModel({
    this.id,
    required this.type,
    required this.alertType,
    this.description,
    required this.timestamp,
    required this.isAnonymous,
    required this.shareLocation,
    this.location,
    this.userId,
    this.userEmail,
    this.userName,
    this.imageBase64,
    this.viewedCount = 0,
    this.viewedBy = const [],
    this.communityId,
    this.alertStatus = 'pending',
    this.forwardsCount = 0,
    this.reportsCount = 0,
    this.reportedBy = const [],
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      type: data['type'] ?? '',
      alertType: data['alertType'] ?? '',
      description: data['description'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isAnonymous: data['isAnonymous'] ?? false,
      shareLocation: data['shareLocation'] ?? false,
      location: data['location'] != null
          ? LocationData.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      userId: data['userId'],
      userEmail: data['userEmail'],
      userName: data['userName'],
      imageBase64: data['imageBase64'] != null
          ? List<String>.from(data['imageBase64'] as List)
          : null,
      viewedCount: data['viewedCount'] ?? 0,
      viewedBy: data['viewedBy'] != null
          ? List<String>.from(data['viewedBy'] as List)
          : [],
      communityId: data['community_id'],
      alertStatus: data['alert_status'] ?? 'pending',
      forwardsCount: data['forwards_count'] ?? 0,
      reportsCount: data['reports_count'] ?? 0,
      reportedBy: data['reported_by'] != null
          ? List<String>.from(data['reported_by'] as List)
          : [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'alertType': alertType,
        'description': description,
        'timestamp': Timestamp.fromDate(timestamp),
        'isAnonymous': isAnonymous,
        'shareLocation': shareLocation,
        'location': location?.toMap(),
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'imageBase64': imageBase64,
        'viewedCount': viewedCount,
        'viewedBy': viewedBy,
        'community_id': communityId,
        'alert_status': alertStatus,
        'forwards_count': forwardsCount,
        'reports_count': reportsCount,
        'reported_by': reportedBy,
      };

  AlertModel copyWith({
    String? id,
    String? type,
    String? alertType,
    String? description,
    DateTime? timestamp,
    bool? isAnonymous,
    bool? shareLocation,
    LocationData? location,
    String? userId,
    String? userEmail,
    String? userName,
    List<String>? imageBase64,
    int? viewedCount,
    List<String>? viewedBy,
    String? communityId,
    String? alertStatus,
    int? forwardsCount,
    int? reportsCount,
    List<String>? reportedBy,
  }) {
    return AlertModel(
      id: id ?? this.id,
      type: type ?? this.type,
      alertType: alertType ?? this.alertType,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      shareLocation: shareLocation ?? this.shareLocation,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      imageBase64: imageBase64 ?? this.imageBase64,
      viewedCount: viewedCount ?? this.viewedCount,
      viewedBy: viewedBy ?? this.viewedBy,
      communityId: communityId ?? this.communityId,
      alertStatus: alertStatus ?? this.alertStatus,
      forwardsCount: forwardsCount ?? this.forwardsCount,
      reportsCount: reportsCount ?? this.reportsCount,
      reportedBy: reportedBy ?? this.reportedBy,
    );
  }
}

/// Geographical coordinates attached to an alert.
class LocationData {
  final double latitude;
  final double longitude;

  const LocationData({
    required this.latitude,
    required this.longitude,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) => LocationData(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}