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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text("📊 Pose Dashboard"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center,
                        size: 40, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Welcome back! Ready to capture a new pose?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Dashboard Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDashboardCard(
                    color: Colors.deepPurpleAccent,
                    icon: Icons.add_circle,
                    title: "Create New Pose",
                    subtitle: "Capture & save pose template",
                    onTap: () {
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
                  _buildDashboardCard(
                    color: Colors.teal,
                    icon: Icons.folder_open,
                    title: "Saved Templates",
                    subtitle: "${savedTemplates.length} templates stored",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedTemplatesPage(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    color: Colors.orange,
                    icon: Icons.analytics,
                    title: "Statistics",
                    subtitle: "Track usage & progress",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Coming soon 🚀")),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    color: Colors.pink,
                    icon: Icons.settings,
                    title: "Settings",
                    subtitle: "Customize preferences",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Settings Page not ready")),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          /// Saving overlay
          if (_isSaving)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// 🔹 Reusable Card Widget with subtitle
  Widget _buildDashboardCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(3, 3),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
