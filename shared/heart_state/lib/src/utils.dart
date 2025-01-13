import 'package:cloud_firestore/cloud_firestore.dart';

T? fromFirestoreField<T>(dynamic field) {
  return switch (field) {
    Timestamp t => t.toDate(),
    _ => field,
  };
}

Map<String, dynamic> fromFirestoreMap(Map<String, dynamic> source) {
  return source.map((k, v) => MapEntry(k, fromFirestoreField(v)));
}
