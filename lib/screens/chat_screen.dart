import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../services/bank_provider.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserPhone;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserPhone,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BankProvider>(context, listen: false);
      provider.setActiveChat(widget.otherUserPhone);
      _fetchInitialMessages();
    });

    // Auto-refresh messages every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (mounted) {
        final provider = Provider.of<BankProvider>(context, listen: false);
        int oldLength = provider.messages.length;
        await provider.refreshMessages(widget.otherUserPhone);
        if (provider.messages.length > oldLength) {
          _scrollToBottom();
        }
      }
    });
  }

  void _fetchInitialMessages() async {
    await Provider.of<BankProvider>(context, listen: false).refreshMessages(widget.otherUserPhone);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    // Clear active chat to avoid provider conflicts
    // ignore: use_build_context_synchronously
    Provider.of<BankProvider>(context, listen: false).setActiveChat(null);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final success = await Provider.of<BankProvider>(context, listen: false).sendMessage(
      text: text,
      receiverPhone: widget.otherUserPhone,
    );

    if (success) {
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: BankTheme.accentPurple),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: BankTheme.accentPurple),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image == null) return;

      if (!mounted) return;

      // Show immediate feedback in the UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Uploading image proof...'),
            ],
          ),
          duration: Duration(seconds: 10), // Long duration, we'll hide it manually
        ),
      );

      final String? uploadedUrl = await Provider.of<BankProvider>(context, listen: false)
          .uploadImage(File(image.path));

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (uploadedUrl != null) {
        final success = await Provider.of<BankProvider>(context, listen: false).sendMessage(
          text: 'Sent an image proof',
          receiverPhone: widget.otherUserPhone,
          imageUrl: uploadedUrl,
        );
        if (success) {
          _scrollToBottom();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      debugPrint('Pick Image Error: $e');
    }
  }

  void _callAdmin() async {
    const String adminPhone = '0881689220';
    final Uri telUri = Uri.parse('tel:$adminPhone');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer for 0881689220')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<BankProvider>(context);
    final myPhone = provider.user?.token ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              widget.otherUserPhone == 'admin-token'
                ? 'System Support'
                : (widget.otherUserPhone == 'group' ? 'Community Chat' : widget.otherUserPhone),
              style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Colors.greenAccent),
            tooltip: 'Call Admin Direct',
            onPressed: _callAdmin,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final msg = provider.messages[index];
                final isMe = msg.sender == myPhone;
                return _buildMessageBubble(msg, isMe, isDark);
              },
            ),
          ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark) {
    final bool isGroup = widget.otherUserPhone == 'group';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isGroup && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                msg.sender == 'admin-token' ? '👑 Admin' : '👤 Member ${msg.sender.substring(msg.sender.length - 4)}',
                style: const TextStyle(fontSize: 11, color: BankTheme.accentPurple, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? BankTheme.accentPurple
                  : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      msg.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(8.0),
                        // Fallback icon if image fails to download
                        child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (msg.transactionId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BankTheme.statusYellow.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, color: BankTheme.statusYellow, size: 13),
                        const SizedBox(width: 6),
                        Text('TX ID: ${msg.transactionId}',
                          style: const TextStyle(color: BankTheme.statusYellow, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : (isDark ? const Color(0xFFE4E4E7) : Colors.black87),
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
              child: IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: BankTheme.accentPurple, size: 20),
                onPressed: _showImageSourceSheet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: BankTheme.accentPurple,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
