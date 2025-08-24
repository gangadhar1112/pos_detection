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
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanPosePage(template: template,),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.file(
                            File(template.imagePath),
                            height: 180, // Bigger image
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            template.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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
