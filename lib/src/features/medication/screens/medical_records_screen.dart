import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../models/medical_record.dart';
import '../services/medical_record_service.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_medical_record_dialog.dart';
import 'edit_medical_record_dialog.dart';

class MedicalRecordsScreen extends StatefulWidget {
  final String patientId;

  const MedicalRecordsScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final role = user?.role;
    
    // Allow upload if Elderly or Caregiver a or Staff
    bool canUpload = (role == UserRole.elderly || role == UserRole.caregiver || role == UserRole.hospitalStaff);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
      ),
      body: StreamBuilder<List<MedicalRecord>>(
        stream: MedicalRecordService().getMedicalRecords(widget.patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching records: ${snapshot.error}"));
          }

          final allRecords = snapshot.data ?? [];
          
          if (allRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.document_scanner, size: 80, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("No Medical Records Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 40.0),
                     child: Text(
                       "You have not uploaded any medical documents yet. Upload prescriptions, lab reports, scan reports, or discharge summaries to keep them securely stored.",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey),
                     ),
                   ),
                   const SizedBox(height: 24),
                   if (canUpload)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AddMedicalRecordDialog(patientId: widget.patientId, currentUserRole: role!.name),
                            barrierDismissible: false,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Upload Medical Record'),
                         style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                        ),
                      )
                ],
              ),
            );
          }

          // Apply Search Filter locally
          final records = allRecords.where((r) {
             final query = _searchQuery.toLowerCase();
             return r.title.toLowerCase().contains(query) || 
                    r.doctorName.toLowerCase().contains(query) || 
                    r.hospitalName.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                     Expanded(
                       child: TextField(
                         decoration: InputDecoration(
                           hintText: 'Search Title, Doctor, or Hospital...',
                           prefixIcon: const Icon(Icons.search),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                           contentPadding: EdgeInsets.zero
                         ),
                         onChanged: (val) {
                            setState(() {
                               _searchQuery = val;
                            });
                         },
                       ),
                     ),
                     const SizedBox(width: 16),
                      Text("Total Records: ${records.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  ],
                ),
              ),
              if (canUpload)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AddMedicalRecordDialog(patientId: widget.patientId, currentUserRole: role!.name),
                          barrierDismissible: false,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Upload Medical Record'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: records.isEmpty 
                  ? const Center(child: Text("No records match your search."))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _MedicalRecordCard(record: record, currentUserRole: role!);
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _MedicalRecordCard extends StatelessWidget {
  final MedicalRecord record;
  final UserRole currentUserRole;

  const _MedicalRecordCard({required this.record, required this.currentUserRole});

  @override
  Widget build(BuildContext context) {
    bool canEdit = (currentUserRole == UserRole.elderly);
    bool canDelete = (currentUserRole == UserRole.elderly || currentUserRole == UserRole.caregiver);

    IconData getFileIcon(String type) {
      if (type.toLowerCase() == 'pdf') return Icons.picture_as_pdf;
      if (['jpg', 'jpeg', 'png'].contains(type.toLowerCase())) return Icons.image;
      return Icons.insert_drive_file;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(getFileIcon(record.fileType), size: 40, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(DateFormat('MMM dd, yyyy').format(record.recordDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                // Edit Button
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditMedicalRecordDialog(record: record),
                      );
                    },
                    tooltip: 'Edit Details',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (record.doctorName.isNotEmpty)
               Text("Doctor: ${record.doctorName}", style: const TextStyle(fontSize: 14)),
            if (record.hospitalName.isNotEmpty)
               Text("Hospital/Clinic: ${record.hospitalName}", style: const TextStyle(fontSize: 14)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () => _launchUrl(record.fileUrl),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  onPressed: () => _launchUrl(record.fileUrl), // For web, view and download might trigger the same behavior.
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
                if (canDelete)
                  TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(context, record),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $urlString");
    }
  }

  void _showDeleteConfirmation(BuildContext context, MedicalRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record"),
        content: const Text("Are you sure you want to delete this medical record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await MedicalRecordService().softDeleteMedicalRecord(record.id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
