class PackMeta {
  const PackMeta({
    required this.id,
    required this.titleEl,
    required this.emoji,
    required this.answerCount,
  });

  final String id;
  final String titleEl;
  final String emoji;
  final int answerCount;

  factory PackMeta.fromJson(Map<String, dynamic> json) {
    return PackMeta(
      id: json['id'] as String,
      titleEl: json['titleEl'] as String,
      emoji: json['emoji'] as String? ?? '',
      answerCount: (json['answerCount'] as num).toInt(),
    );
  }

  String get label => emoji.isEmpty ? titleEl : '$emoji $titleEl';
}
