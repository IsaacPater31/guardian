import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model representing a single alert.
class AlertModel {
  final String? id;

  /// Alert category: `'detailed'`, `'quick'`, or `'swiped'`.
  final String type;

  /// Emergency type identifier (e.g. `'FIRE'`, `'HEALTH'`, `'POLICE'`).
  final String alertType;

  final String? description;
  final String? subtype;
  final String? customDetail;
  final DateTime timestamp;
  final bool isAnonymous;
  final bool shareLocation;
  final LocationData? location;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final List<String>? imageBase64;
  final List<String> attachmentPlaceholders;
  final int viewedCount;
  final List<String> viewedBy;

  /// Communities this alert was sent to.
  ///
  /// New documents store `community_ids: List<String>`.
  /// Legacy documents store `community_id: String?` — the parser
  /// normalises both formats into this single list.
  final List<String> communityIds;

  /// Attention status: `'pending'` or `'attended'`.
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
    this.subtype,
    this.customDetail,
    required this.timestamp,
    required this.isAnonymous,
    required this.shareLocation,
    this.location,
    this.userId,
    this.userEmail,
    this.userName,
    this.imageBase64,
    this.attachmentPlaceholders = const [],
    this.viewedCount = 0,
    this.viewedBy = const [],
    this.communityIds = const [],
    this.alertStatus = 'pending',
    this.forwardsCount = 0,
    this.reportsCount = 0,
    this.reportedBy = const [],
  });

  // ─── Derived helpers ──────────────────────────────────────────────────────

  /// `true` if this alert belongs to at least one community.
  bool get hasCommunity => communityIds.isNotEmpty;

  /// First community ID, or `null` — for forward-compat usage.
  String? get communityId => communityIds.isEmpty ? null : communityIds.first;

  // ─── Firestore serialisation ──────────────────────────────────────────────

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ── community_ids normalisation: support both legacy and new format ──
    final List<String> communityIds;
    if (data['community_ids'] != null) {
      // New format: array of strings
      communityIds = List<String>.from(data['community_ids'] as List);
    } else if (data['community_id'] != null &&
        (data['community_id'] as String).isNotEmpty) {
      // Legacy format: single string — wrap in list
      communityIds = [data['community_id'] as String];
    } else {
      communityIds = [];
    }

    return AlertModel(
      id: doc.id,
      type: data['type'] ?? '',
      alertType: data['alertType'] ?? '',
      description: data['description'],
      subtype: data['subtype'],
      customDetail: data['custom_detail'],
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
      attachmentPlaceholders: data['attachment_placeholders'] != null
          ? List<String>.from(data['attachment_placeholders'] as List)
          : const [],
      viewedCount: data['viewedCount'] ?? 0,
      viewedBy: data['viewedBy'] != null
          ? List<String>.from(data['viewedBy'] as List)
          : [],
      communityIds: communityIds,
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
        'subtype': subtype,
        'custom_detail': customDetail,
        'timestamp': Timestamp.fromDate(timestamp),
        'isAnonymous': isAnonymous,
        'shareLocation': shareLocation,
        'location': location?.toMap(),
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'imageBase64': imageBase64,
        'attachment_placeholders': attachmentPlaceholders,
        'viewedCount': viewedCount,
        'viewedBy': viewedBy,
        'community_ids': communityIds,   // new field (array)
        // Note: community_id (singular) is intentionally NOT written
        // so new documents only have community_ids.
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
    String? subtype,
    String? customDetail,
    DateTime? timestamp,
    bool? isAnonymous,
    bool? shareLocation,
    LocationData? location,
    String? userId,
    String? userEmail,
    String? userName,
    List<String>? imageBase64,
    List<String>? attachmentPlaceholders,
    int? viewedCount,
    List<String>? viewedBy,
    List<String>? communityIds,
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
      subtype: subtype ?? this.subtype,
      customDetail: customDetail ?? this.customDetail,
      timestamp: timestamp ?? this.timestamp,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      shareLocation: shareLocation ?? this.shareLocation,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      imageBase64: imageBase64 ?? this.imageBase64,
      attachmentPlaceholders: attachmentPlaceholders ?? this.attachmentPlaceholders,
      viewedCount: viewedCount ?? this.viewedCount,
      viewedBy: viewedBy ?? this.viewedBy,
      communityIds: communityIds ?? this.communityIds,
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