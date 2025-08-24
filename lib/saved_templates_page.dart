import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pos_detection/scan_pos_page.dart';
import 'model/pose_template.dart';
import 'utils/template_storage.dart';

class SavedTemplatesPage extends StatefulWidget {
  const SavedTemplatesPage({Key? key}) : super(key: key);

  @override
  State<SavedTemplatesPage> createState() => _SavedTemplatesPageState();
}

class _SavedTemplatesPageState extends State<SavedTemplatesPage> {
  List<PoseTemplate> templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final loaded = await TemplateStorage.loadTemplates();
    setState(() {
      templates = loaded;
    });
  }

  Future<void> _deleteTemplate(int index) async {
    final template = templates[index];

    // Remove from list
    setState(() {
      templates.removeAt(index);
    });

    // Save updated list
    await TemplateStorage.saveTemplates(templates);

    // Optionally delete the image file
    final file = File(template.imagePath);
    if (await file.exists()) {
      await file.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} deleted')),
    );
  }

  void _showImageDialog(PoseTemplate template, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.file(
                File(template.imagePath),
                fit: BoxFit.contain,
                height: 300,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 8),

            // Name
            Text(
              template.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Delete Option
                // ElevatedButton.icon(
                //   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                //   icon: const Icon(Icons.delete, color: Colors.white),
                //   label: const Text("Delete"),
                //   onPressed: () {
                //     Navigator.pop(context); // Close dialog
                //     _deleteTemplate(index);
                //   },
                // ),

                // Recreate Option
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text("Recreate Pose"),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanPosePage(template: template),
                      ),
                    );
                  },
                ),

                // Close Option
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text("Close"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white30,
      appBar: AppBar(title: const Text('Saved Templates')),
      body: templates.isEmpty
          ? const Center(child: Text('No saved templates found.'))
          : ListView.builder(
        itemCount: templates.length,
        itemBuilder: (context, idx) {
          final template = templates[idx];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showImageDialog(template, idx),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full width image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.file(
                      File(template.imagePath),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: Colors.blueGrey,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
