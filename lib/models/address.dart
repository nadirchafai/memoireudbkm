// lib/models/address.dart
class Address {
  final int id;
  final String? ville; // ville might be nullable
  final String? quartier; // quartier might be nullable
  final String? rue; // rue might be nullable

  Address({required this.id, this.ville, this.quartier, this.rue});

  // Factory method to create an Address object from a JSON map
  factory Address.fromJson(Map<String, dynamic> json) {
    // Safely parse ID as int
    final idValue = json['id'];
    final int parsedId = idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0;

    return Address(
      id: parsedId,
      ville: json['ville'] as String?, // Cast to String?, returns null if JSON value is null
      quartier: json['quartier'] as String?,
      rue: json['rue'] as String?,
    );
  }
}