import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class ReportDialog extends StatefulWidget {
  final String reportedUserId;
  final String context;
  final String? contextId;

  const ReportDialog({
    super.key,
    required this.reportedUserId,
    required this.context,
    this.contextId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _selectedReason = 'harassment';
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = {
    'harassment': 'Harassment',
    'spam': 'Spam',
    'inappropriate_content': 'Inappropriate Content',
    'fake_profile': 'Fake Profile',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons.entries.map((e) => 
              DropdownMenuItem(value: e.key, child: Text(e.value))
            ).toList(),
            onChanged: (value) => setState(() => _selectedReason = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Provide additional details...',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    
    try {
      final reporterId = await SessionStore.ensureUserId();
      if (reporterId == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.reportsCollectionId,
        documentId: ID.unique(),
        data: {
          'reporterId': reporterId,
          'reportedUserId': widget.reportedUserId,
          'reportType': _selectedReason,
          'context': widget.context,
          'contextId': widget.contextId,
          'description': _descriptionController.text.trim().isEmpty 
            ? null : _descriptionController.text.trim(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
