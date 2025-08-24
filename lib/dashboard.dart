import 'package:flutter/material.dart';
import 'create_pos_template_page.dart';
import 'saved_templates_page.dart';
import 'model/pose_template.dart';
import 'utils/template_storage.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<PoseTemplate> savedTemplates = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTemplates();
  }

  Future<void> _loadSavedTemplates() async {
    final templates = await TemplateStorage.loadTemplates();
    setState(() => savedTemplates = templates);
  }

  Future<void> _addNewTemplate(PoseTemplate template) async {
    setState(() => _isSaving = true);
    savedTemplates.add(template);
    await TemplateStorage.saveTemplates(savedTemplates);
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    ).then((_) => _loadSavedTemplates());
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder),
                  label: const Text('Saved Pose Templates'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedTemplatesPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
