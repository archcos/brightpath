import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Example state (e.g., selected tile index)
  int selectedIndex = -1;

  void onTileTap(int index) {
    setState(() {
      selectedIndex = index;
    });

    // TODO: Add navigation or logic here
    debugPrint('Tapped tile index: $index');
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tiles = [
      {'icon': Icons.person, 'label': 'Profile'},
      {'icon': Icons.message, 'label': 'Messages'},
      {'icon': Icons.settings, 'label': 'Settings'},
      {'icon': Icons.analytics, 'label': 'Reports'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final tile = tiles[index];
            return DashboardTile(
              icon: tile['icon'],
              label: tile['label'],
              isSelected: selectedIndex == index,
              onTap: () => onTileTap(index),
            );
          },
        ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.indigo.shade100 : Colors.indigo.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.indigo),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
