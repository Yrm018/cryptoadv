class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? creatorId;
  final List<String> memberIds;
  final String? photoBase64;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.creatorId,
    required this.memberIds,
    this.photoBase64,
    required this.createdAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      creatorId: map['creator_id'] ?? map['creatorId'],
      memberIds: List<String>.from(map['memberIds'] ?? map['members'] ?? []),
      photoBase64: map['photoBase64'] ?? map['photo_base64'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'creatorId': creatorId,
    'memberIds': memberIds,
    'photoBase64': photoBase64,
    'createdAt': createdAt.toIso8601String(),
  };
}
