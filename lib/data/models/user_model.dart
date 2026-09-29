import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  NotificationSettings({
    this.dueSoon = true,
    this.overdue = true,
    this.morningBriefing = true,
    this.streakAtRisk = true,
    this.streakMilestone = true,
    this.weeklyReview = true,
    this.eveningWrapUp = false,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      dueSoon: map['dueSoon'] ?? true,
      overdue: map['overdue'] ?? true,
      morningBriefing: map['morningBriefing'] ?? true,
      streakAtRisk: map['streakAtRisk'] ?? true,
      streakMilestone: map['streakMilestone'] ?? true,
      weeklyReview: map['weeklyReview'] ?? true,
      eveningWrapUp: map['eveningWrapUp'] ?? false,
    );
  }
  final bool dueSoon;
  final bool overdue;
  final bool morningBriefing;
  final bool streakAtRisk;
  final bool streakMilestone;
  final bool weeklyReview;
  final bool eveningWrapUp;

  Map<String, dynamic> toMap() {
    return {
      'dueSoon': dueSoon,
      'overdue': overdue,
      'morningBriefing': morningBriefing,
      'streakAtRisk': streakAtRisk,
      'streakMilestone': streakMilestone,
      'weeklyReview': weeklyReview,
      'eveningWrapUp': eveningWrapUp,
    };
  }
}

class UserModel {
  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.notificationSettings,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return UserModel(
      uid: data?['uid'] ?? '',
      email: data?['email'] ?? '',
      displayName: data?['displayName'] ?? '',
      photoURL: data?['photoURL'],
      notificationSettings: NotificationSettings.fromMap(
        data?['notificationSettings'] ?? {},
      ),
    );
  }
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final NotificationSettings notificationSettings;

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'notificationSettings': notificationSettings.toMap(),
      if (photoURL != null) 'photoURL': photoURL,
    };
  }
}
