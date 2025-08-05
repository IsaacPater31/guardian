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