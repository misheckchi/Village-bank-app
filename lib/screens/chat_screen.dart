import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                msg.sender == 'admin-token' ? 'Admin' : 'Member ${msg.sender.substring(msg.sender.length - 4)}',
                style: TextStyle(fontSize: 10, color: BankTheme.accentPurple, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe
                  ? BankTheme.accentPurple
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(msg.imageUrl!, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                ],
                if (msg.transactionId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BankTheme.statusYellow.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, color: BankTheme.statusYellow, size: 14),
                        const SizedBox(width: 8),
                        Text('TX ID: ${msg.transactionId}',
                          style: const TextStyle(color: BankTheme.statusYellow, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  msg.text,
                  style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: BankTheme.accentPurple),
            onPressed: _showImageSourceSheet,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: BankTheme.accentPurple),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
