import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/global_post_model.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';

class GlobalCommunityThreadScreen extends StatefulWidget {
  const GlobalCommunityThreadScreen({super.key});

  @override
  State<GlobalCommunityThreadScreen> createState() => _GlobalCommunityThreadScreenState();
}

class _GlobalCommunityThreadScreenState extends State<GlobalCommunityThreadScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BankProvider>(context, listen: false).refreshCommunityPosts();
    });
  }

  void _showNewPostDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: BankTheme.accentPurple),
            const SizedBox(width: 8),
            Text(
              'SHARE PERFORMANCE IDEA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share an idea, strategy, or financial practice to help all village bank organizations perform better:',
                style: TextStyle(fontSize: 12, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'IDEA TITLE / STRATEGY NAME',
                  hintText: 'e.g., Weekly Savings Reminders & Peer Guarantees',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                decoration: const InputDecoration(
                  labelText: 'DESCRIPTION & STEPS',
                  hintText: 'Explain how your organization improved loan repayment or grew total savings...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BankTheme.accentPurple),
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isNotEmpty && content.isNotEmpty) {
                final success = await provider.createCommunityPost(title, content);
                if (!mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your idea has been posted to the global community thread!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in both title and description.')),
                );
              }
            },
            child: const Text('POST IDEA'),
          ),
        ],
      ),
    );
  }

  void _showPostDetailsDialog(GlobalPostModel post) {
    final replyController = TextEditingController();
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final userPhone = provider.user?.token ?? '';
          final isLiked = post.likes.contains(userPhone);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By ${post.authorName} (${post.authorOrg})',
                              style: const TextStyle(fontSize: 12, color: BankTheme.accentPurple, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? Colors.redAccent : BankTheme.textMuted),
                        onPressed: () async {
                          await provider.likeCommunityPost(post.id);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Post Content
                  Text(
                    post.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : BankTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${post.replies.length} Replies',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Replies List
                  Expanded(
                    child: post.replies.isEmpty
                        ? Center(
                            child: Text(
                              'No responses yet. Be the first to reply!',
                              style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12),
                            ),
                          )
                        : ListView.separated(
                            itemCount: post.replies.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final reply = post.replies[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${reply.authorName} (${reply.authorOrg})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BankTheme.accentPurple),
                                        ),
                                        Text(
                                          _formatDate(reply.timestamp),
                                          style: TextStyle(fontSize: 9, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      reply.content,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Reply Input Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyController,
                          style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Write a response...',
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: BankTheme.accentPurple),
                        onPressed: () async {
                          final replyText = replyController.text.trim();
                          if (replyText.isNotEmpty) {
                            final success = await provider.replyToCommunityPost(post.id, replyText);
                            if (success) {
                              replyController.clear();
                              Navigator.pop(context);
                              _showPostDetailsDialog(provider.communityPosts.firstWhere((p) => p.id == post.id));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.forum_rounded, color: BankTheme.accentPurple, size: 20),
            SizedBox(width: 8),
            Text('Global Idea Forum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BankTheme.accentPurple,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text('SHARE IDEA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showNewPostDialog,
      ),
      body: Consumer<BankProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.communityPosts.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: BankTheme.accentPurple));
          }

          final posts = provider.communityPosts.where((p) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return p.title.toLowerCase().contains(query) ||
                p.content.toLowerCase().contains(query) ||
                p.authorOrg.toLowerCase().contains(query) ||
                p.authorName.toLowerCase().contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refreshCommunityPosts,
            color: BankTheme.accentPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cross-Organization Forum',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All members from any village bank organization can post and reply to share strategies for improving performance.',
                    style: TextStyle(fontSize: 12, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Search box
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search ideas or organizations...',
                      prefixIcon: const Icon(Icons.search_rounded, color: BankTheme.accentPurple),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (posts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: BankTheme.accentPurple),
                            const SizedBox(height: 16),
                            Text(
                              'No forum ideas posted yet.\nBe the first to share an improvement idea!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final userPhone = provider.user?.token ?? '';
                        final isLiked = post.likes.contains(userPhone);

                        return GestureDetector(
                          onTap: () => _showPostDetailsDialog(post),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: BankTheme.accentPurple.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        post.authorOrg,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BankTheme.accentPurple),
                                      ),
                                    ),
                                    Text(
                                      _formatDate(post.timestamp),
                                      style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Text(
                                  post.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  post.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isDark ? Colors.white70 : BankTheme.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'By ${post.authorName}',
                                      style: TextStyle(fontSize: 11, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                    ),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => provider.likeCommunityPost(post.id),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                size: 16,
                                                color: isLiked ? Colors.redAccent : BankTheme.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${post.likes.length}',
                                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Row(
                                          children: [
                                            Icon(Icons.mode_comment_outlined, size: 16, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${post.replies.length}',
                                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 80), // FAB space padding
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
