import 'dart:convert';

class FolderEntity {
  final String name;
  final String package;
  final String id;

  const FolderEntity({
    required this.name,
    required this.package,
    required this.id,
  });

  FolderEntity copyWith({String? name, String? package, String? id}) {
    return FolderEntity(
      name: name ?? this.name,
      package: package ?? this.package,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'name': name, 'package': package, 'id': id};
  }

  factory FolderEntity.fromMap(Map<String, dynamic> map) {
    return FolderEntity(
      name: (map["name"] ?? '') as String,
      package: (map["package"] ?? '') as String,
      id: (map["id"] ?? '') as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory FolderEntity.fromJson(String source) =>
      FolderEntity.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'FolderEntity(name: $name, package: $package, id: $id)';

  @override
  bool operator ==(covariant FolderEntity other) {
    if (identical(this, other)) return true;

    return other.name == name && other.package == package && other.id == id;
  }

  @override
  int get hashCode => name.hashCode ^ package.hashCode ^ id.hashCode;
}
