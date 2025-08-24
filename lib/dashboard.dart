import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_detection/scan_pos_page.dart';

import 'create_pos_template_page.dart';
import 'model/pose_template.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<PoseTemplate> savedTemplates = [];

  void _addNewTemplate(PoseTemplate template) {
    setState(() {
      savedTemplates.add(template);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create New Pose Template'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePoseTemplatePage(
                      onTemplateCreated: _addNewTemplate,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Saved Pose Templates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: savedTemplates.isEmpty
                  ? const Center(child: Text('No saved pose templates found.'))
                  : ListView.builder(
                itemCount: savedTemplates.length,
                itemBuilder: (context, idx) {
                  final template = savedTemplates[idx];
                  return ListTile(
                    leading: Image.file(
                      File(template.imagePath),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(template.name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanPosePage(
                            template: template,// pass saved image size
                          ),
                        ),
                      );

                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
