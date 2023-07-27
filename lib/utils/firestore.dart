import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreData {
  static Future<List<dynamic>> getRagiData() async {
    final Query collectionRef =
        FirebaseFirestore.instance.collection('kirtan_duties');

    QuerySnapshot querySnapshot = await collectionRef.get();

    final allData = querySnapshot.docs.map((doc) {
      final data =
          Map<String, dynamic>.from(doc.data() as Map<dynamic, dynamic>);
      data['id'] = int.tryParse(doc.id);
      return data;
    }).toList();

    allData.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));

    return allData;
  }

  static Future<List<dynamic>> getKirtanData() async {
    final Query collectionRef =
        FirebaseFirestore.instance.collection('kirtan_link');

    QuerySnapshot querySnapshot = await collectionRef.get();

    final allData = querySnapshot.docs.map((doc) {
      final data =
          Map<String, dynamic>.from(doc.data() as Map<dynamic, dynamic>);
      data['id'] = int.tryParse(doc.id);
      return data;
    }).toList();

    allData.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));

    return(allData);
  }
}
