class ChatThreadDto {
  ChatThreadDto({
    required this.otherUserId,
    required this.otherName,
    required this.otherAvatar,
    required this.lastMessage,
    required this.lastTime,
    required this.unreadCount,
    required this.pinned,
    required this.blocked,
  });

  final int otherUserId;
  final String otherName;
  final String? otherAvatar;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final bool pinned;
  final bool blocked;

  factory ChatThreadDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return ChatThreadDto(
      otherUserId: toInt(json['other_id']),
      otherName: (json['other_name'] ?? '').toString(),
      otherAvatar: json['other_avatar']?.toString(),
      lastMessage: (json['last_message'] ?? '').toString(),
      lastTime:
          DateTime.tryParse(json['last_time']?.toString() ?? '') ??
          DateTime.now(),
      unreadCount: toInt(json['unread_count']),
      pinned:
          json['pinned'] == true ||
          json['pinned'] == 1 ||
          json['pinned']?.toString() == '1',
      blocked:
          json['blocked'] == true ||
          json['blocked'] == 1 ||
          json['blocked']?.toString() == '1',
    );
  }
}

class ChatMessageDto {
  ChatMessageDto({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.read,
  });

  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime createdAt;
  final bool read;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id_mensaje'] as int? ?? 0,
      senderId: json['id_emisor'] as int? ?? 0,
      receiverId: json['id_receptor'] as int? ?? 0,
      content: (json['contenido'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      read: json['leido'] == true || json['leido'] == 1,
    );
  }
}
