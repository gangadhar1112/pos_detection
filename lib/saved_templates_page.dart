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
    setState(() => templates = loaded);
  }

  Future<void> _deleteTemplate(int index) async {
    final template = templates[index];
    setState(() => templates.removeAt(index));
    await TemplateStorage.saveTemplates(templates);

    final file = File(template.imagePath);
    if (await file.exists()) {
      await file.delete();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} deleted')),
    );
  }

  void _showImageBottomSheet(PoseTemplate template, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Preview Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(template.imagePath),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),

              /// Pose Name
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              /// Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bottomSheetButton(
                    icon: Icons.refresh,
                    label: "Recreate Pose",
                    color: Colors.deepPurple,
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
                  _bottomSheetButton(
                    icon: Icons.delete,
                    label: "Delete",
                    color: Colors.redAccent,
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTemplate(index);
                    },
                  ),
                  _bottomSheetButton(
                    icon: Icons.close,
                    label: "Close",
                    color: Colors.grey,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text("📂 Saved Templates"),
        centerTitle: true,
      ),
      body: templates.isEmpty
          ? _buildEmptyState()
          : Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: templates.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, idx) {
            final template = templates[idx];
            return GestureDetector(
              onTap: () => _showImageBottomSheet(template, idx),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(template.imagePath)),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    )
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        template.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 3,
                            )
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.photo_library_outlined,
              size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No saved templates yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            "Start by creating a new pose template",
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// 🔹 Reusable bottom sheet button
  Widget _bottomSheetButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
    );
  }
}
