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
  final List<String>? imageBase64;

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
    this.imageBase64,
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
      imageBase64: data['imageBase64'] != null ? List<String>.from(data['imageBase64']) : null,
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
      'imageBase64': imageBase64,
    };
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