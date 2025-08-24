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

    // Delete from SharedPreferences
    await TemplateStorage.saveTemplates(templates);

    // Optionally delete the image file also
    final file = File(template.imagePath);
    if (await file.exists()) {
      await file.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(template.imagePath),
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                template.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanPosePage(template: template),
                  ),
                );
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteTemplate(idx),
              ),
            ),
          );
        },
      ),
    );
  }
}
