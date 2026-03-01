import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medical_record.dart';
import '../services/medical_record_service.dart';

class EditMedicalRecordDialog extends StatefulWidget {
  final MedicalRecord record;

  const EditMedicalRecordDialog({Key? key, required this.record}) : super(key: key);

  @override
  _EditMedicalRecordDialogState createState() => _EditMedicalRecordDialogState();
}

class _EditMedicalRecordDialogState extends State<EditMedicalRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _hospitalController;
  late TextEditingController _doctorController;
  late DateTime _recordDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.record.title);
    _descriptionController = TextEditingController(text: widget.record.description);
    _hospitalController = TextEditingController(text: widget.record.hospitalName);
    _doctorController = TextEditingController(text: widget.record.doctorName);
    _recordDate = widget.record.recordDate;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _recordDate) {
      setState(() {
         _recordDate = picked;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        await MedicalRecordService().updateMedicalRecord(
          widget.record.id,
          {
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'hospitalName': _hospitalController.text.trim(),
            'doctorName': _doctorController.text.trim(),
            'recordDate': _recordDate,
          },
        );

        if (mounted) {
           Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Details'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Record Title *', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description / Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(labelText: 'Hospital / Clinic Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _doctorController,
                  decoration: const InputDecoration(labelText: 'Doctor Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date of Record', border: OutlineInputBorder()),
                    child: Text(DateFormat('MMM dd, yyyy').format(_recordDate)),
                  ),
                ),
                if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
        )
      ],
    );
  }
}
