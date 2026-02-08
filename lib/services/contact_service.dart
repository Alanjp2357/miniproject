import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection Reference
  CollectionReference get _contactsCollection {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(user.uid).collection('contacts');
  }

  // Add Contact
  Future<void> addContact(String name, String phone, {String? email}) async {
    await _contactsCollection.add({
      'name': name,
      'phone': phone,
      'email': email ?? '',
      'createdAt': DateTime.now(),
    });
  }

  // Get Contacts Stream
  Stream<QuerySnapshot> getContacts() {
    return _contactsCollection
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Delete Contact
  Future<void> deleteContact(String id) async {
    await _contactsCollection.doc(id).delete();
  }
}
