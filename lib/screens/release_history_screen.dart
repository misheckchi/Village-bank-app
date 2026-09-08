import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/bank_provider.dart';
import '../models/release_record.dart';

class ReleaseHistoryScreen extends StatefulWidget {
  const ReleaseHistoryScreen({super.key});

  @override
  State<ReleaseHistoryScreen> createState() => _ReleaseHistoryScreenState();
}

class _ReleaseHistoryScreenState extends State<ReleaseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BankProvider>().refreshReleases();
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Release Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BankProvider>().refreshReleases(),
          ),
        ],
      ),
      body: Consumer<BankProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.releases.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.releases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No release records found', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.releases.length,
            itemBuilder: (context, index) {
              final release = provider.releases[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Version ${release.version}+${release.buildNumber}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(release.timestamp),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        release.notes,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _launchUrl(release.downloadUrl),
                              icon: const Icon(Icons.download),
                              label: const Text('Download APK'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: context.watch<BankProvider>().user?.role == 'admin'
        ? FloatingActionButton.extended(
            onPressed: () => _showAddReleaseDialog(context),
            label: const Text('Log New Release'),
            icon: const Icon(Icons.add),
          )
        : null,
    );
  }

  void _showAddReleaseDialog(BuildContext context) {
    final versionController = TextEditingController();
    final buildController = TextEditingController();
    final urlController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log New Release'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: versionController, decoration: const InputDecoration(labelText: 'Version (e.g. 1.0.0)')),
              TextField(controller: buildController, decoration: const InputDecoration(labelText: 'Build Number (e.g. 1)')),
              TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Download URL')),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Release Notes'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<BankProvider>().logNewRelease(
                version: versionController.text,
                buildNumber: buildController.text,
                downloadUrl: urlController.text,
                notes: notesController.text,
              );
              if (mounted && success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Release logged successfully')),
                );
              }
            },
            child: const Text('Log Release'),
          ),
        ],
      ),
    );
  }
}
