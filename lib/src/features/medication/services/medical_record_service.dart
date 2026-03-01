import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/medical_record.dart';

class MedicalRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  Stream<List<MedicalRecord>> getMedicalRecords(String elderlyId) {
    return _firestore
        .collection('medical_records')
        .where('elderlyId', isEqualTo: elderlyId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => MedicalRecord.fromMap(doc.data(), doc.id))
              .where((record) => record.isActive)
              .toList();
          
          records.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
          return records;
        });
  }

  Future<void> addMedicalRecord({
    required String elderlyId,
    required String title,
    required String description,
    required String hospitalName,
    required String doctorName,
    required DateTime recordDate,
    required String uploadedByRole,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSize,
    required String fileType,
  }) async {
    String? fileUrl;
    String filePath = 'medical_records/$elderlyId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    Reference storageRef = _storage.ref().child(filePath);

    try {
      SettableMetadata metadata = SettableMetadata(
        contentType: fileType.toLowerCase() == 'pdf' ? 'application/pdf' : 'image/$fileType',
      );
      
      TaskSnapshot uploadTask = await storageRef.putData(fileBytes, metadata).timeout(const Duration(seconds: 60));
      fileUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(seconds: 30));

      MedicalRecord record = MedicalRecord(
        id: '', 
        title: title,
        description: description,
        hospitalName: hospitalName,
        doctorName: doctorName,
        recordDate: recordDate,
        uploadDate: DateTime.now(),
        fileSize: fileSize,
        fileType: fileType,
        fileUrl: fileUrl,
        uploadedByRole: uploadedByRole,
        elderlyId: elderlyId,
        isActive: true,
      );

      await _firestore.collection('medical_records').add(record.toMap()).timeout(const Duration(seconds: 15));
    } catch (e) {
      if (fileUrl != null) {
        try { await storageRef.delete(); } catch (_) {}
      }
      // Provide clean error without standard stack trace prefixes
      final errorStr = e.toString();
      if (errorStr.contains('TimeoutException')) {
        throw Exception("Upload timeout. Please check your network connection.");
      }
      throw Exception(errorStr.replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateMedicalRecord(String recordId, Map<String, dynamic> data) async {
    await _firestore.collection('medical_records').doc(recordId).update(data);
  }

  Future<void> softDeleteMedicalRecord(String recordId) async {
    await updateMedicalRecord(recordId, {'isActive': false});
  }
}
