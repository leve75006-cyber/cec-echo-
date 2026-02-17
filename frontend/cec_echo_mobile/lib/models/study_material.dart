class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String courseCode;
  final String subjectName;
  final String materialType;
  final String resourceUrl;
  final List<String> tags;
  final DateTime? createdAt;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.courseCode,
    required this.subjectName,
    required this.materialType,
    required this.resourceUrl,
    required this.tags,
    this.createdAt,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'] as List<dynamic>? ?? const [];
    return StudyMaterial(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Material').toString(),
      description: (json['description'] ?? '').toString(),
      courseCode: (json['courseCode'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? '').toString(),
      materialType: (json['materialType'] ?? 'notes').toString(),
      resourceUrl: (json['resourceUrl'] ?? '').toString(),
      tags: tagsRaw.map((e) => e.toString()).toList(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}
