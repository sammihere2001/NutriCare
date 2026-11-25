class NotificationModel {
  final int notificationId;
  final int userId;
  final String title;
  final String message;
  final String? notificationType;
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;
  final Map<String, dynamic>? extraData;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    this.notificationType,
    required this.isRead,
    required this.sentAt,
    this.readAt,
    this.extraData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      notificationType: json['notification_type'],
      isRead: json['is_read'] ?? false,
      sentAt: DateTime.parse(json['sent_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      extraData: json['extra_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'is_read': isRead,
      'sent_at': sentAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'extra_data': extraData,
    };
  }
}
