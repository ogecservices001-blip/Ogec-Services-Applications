import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Photos du Bon d'intervention — vrais fichiers sur Firebase Storage
/// (chemin réservé aux utilisateurs connectés, pas sous /public/**),
/// plutôt qu'un encodage base64 dans le document Firestore : plus de
/// limite de taille/qualité liée à la limite de 1 Mo par document.
class BiPhotoService {
  Future<String> uploader(Uint8List bytes) async {
    final chemin = 'bi_photos/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(chemin);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
