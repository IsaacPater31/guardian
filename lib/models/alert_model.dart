import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String? id;
  final String type; // 'detailed', 'quick', 'swiped'
  final String alertType; // 'EMERGENCY', 'FIRE', 'ACCIDENT', etc.
  final String? description;
  final DateTime timestamp;
  final bool isAnonymous;
  final bool shareLocation;
  final LocationData? location;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final List<String>? imageBase64;
  final int viewedCount; // Contador de personas que han visto la alerta
  final List<String> viewedBy; // Lista de IDs de usuarios que han visto la alerta
  
  // NUEVOS CAMPOS para sistema de comunidades
  final String? communityId; // FK a community (null para alertas antiguas - compatibilidad)
  final int forwardsCount; // Contador de reenvíos
  final int reportsCount; // Contador de reportes
  final List<String> reportedBy; // IDs de usuarios que han reportado (evitar doble reporte)

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
    // NUEVOS CAMPOS
    this.communityId,
    this.forwardsCount = 0,
    this.reportsCount = 0,
    this.reportedBy = const [],
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      type: data['type'] ?? '',
      alertType: data['alertType'] ?? '',
      description: data['description'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isAnonymous: data['isAnonymous'] ?? false,
      shareLocation: data['shareLocation'] ?? false,
      location: data['location'] != null ? LocationData.fromMap(data['location']) : null,
      userId: data['userId'],
      userEmail: data['userEmail'],
      userName: data['userName'],
      imageBase64: data['imageBase64'] != null ? List<String>.from(data['imageBase64']) : null,
      viewedCount: data['viewedCount'] ?? 0,
      viewedBy: data['viewedBy'] != null ? List<String>.from(data['viewedBy']) : [],
      // NUEVOS CAMPOS (compatibilidad: si no existen, son null/0)
      communityId: data['community_id'],
      forwardsCount: data['forwards_count'] ?? 0,
      reportsCount: data['reports_count'] ?? 0,
      reportedBy: data['reported_by'] != null ? List<String>.from(data['reported_by']) : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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
      // NUEVOS CAMPOS
      'community_id': communityId,
      'forwards_count': forwardsCount,
      'reports_count': reportsCount,
      'reported_by': reportedBy,
    };
  }

  // Método para crear una copia con el contador de vistas actualizado
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
    // NUEVOS CAMPOS
    String? communityId,
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
      // NUEVOS CAMPOS
      communityId: communityId ?? this.communityId,
      forwardsCount: forwardsCount ?? this.forwardsCount,
      reportsCount: reportsCount ?? this.reportsCount,
      reportedBy: reportedBy ?? this.reportedBy,
    );
  }
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
} 