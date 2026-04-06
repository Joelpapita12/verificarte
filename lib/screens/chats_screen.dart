import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../theme/app_colors.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.initialOtherUserId});

  static const String routeName = '/chats';

  final int? initialOtherUserId;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FeedApi _api = FeedApi();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  List<ChatThreadDto> _threads = <ChatThreadDto>[];
  List<ChatMessageDto> _messages = <ChatMessageDto>[];
  int? _selectedOtherUserId;

  int? get _userId => CurrentUserStore.userId;

  ChatThreadDto? get _selectedThread {
    final id = _selectedOtherUserId;
    if (id == null) return null;
    for (final thread in _threads) {
      if (thread.otherUserId == id) return thread;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    final userId = _userId;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final threads = await _api.fetchChatThreads(userId);
    final selected = _selectedOtherUserId ??
        widget.initialOtherUserId ??
        (threads.isNotEmpty ? threads.first.otherUserId : null);

    if (!mounted) return;
    setState(() {
      _threads = threads;
      _selectedOtherUserId = selected;
      _loading = false;
    });

    if (selected != null) {
      await _loadConversation(selected);
    }
  }

  Future<void> _loadConversation(int otherUserId) async {
    final userId = _userId;
    if (userId == null) return;

    final messages = await _api.fetchConversation(
      userId: userId,
      otherUserId: otherUserId,
    );
    await _api.markChatRead(userId: userId, otherUserId: otherUserId);

    if (!mounted) return;
    setState(() => _messages = messages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final userId = _userId;
    final otherUserId = _selectedOtherUserId;
    final text = _messageController.text.trim();
    final thread = _selectedThread;

    if (userId == null || otherUserId == null || text.isEmpty) return;
    if (thread?.blocked == true) {
      _showMessage('Este chat está bloqueado.');
      return;
    }

    try {
      await _api.sendMessage(
        senderId: userId,
        receiverId: otherUserId,
        content: text,
      );
      _messageController.clear();
      await _loadConversation(otherUserId);
      await _loadThreads();
    } catch (_) {
      _showMessage('No se pudo enviar el mensaje.');
    }
  }

  Future<void> _selectThread(ChatThreadDto thread) async {
    setState(() => _selectedOtherUserId = thread.otherUserId);
    await _loadConversation(thread.otherUserId);
    await _loadThreads();
  }

  Future<void> _handleThreadAction(ChatThreadDto thread, String action) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      if (action == 'pin') {
        await _api.pinChat(
          userId: userId,
          otherUserId: thread.otherUserId,
          pinned: !thread.pinned,
        );
      } else if (action == 'block') {
        await _api.blockChat(
          userId: userId,
          otherUserId: thread.otherUserId,
          blocked: !thread.blocked,
        );
      } else if (action == 'delete') {
        await _api.deleteChat(userId: userId, otherUserId: thread.otherUserId);
        if (_selectedOtherUserId == thread.otherUserId) {
          _selectedOtherUserId = null;
          _messages = <ChatMessageDto>[];
        }
      }

      await _loadThreads();
      if (_selectedOtherUserId != null) {
        await _loadConversation(_selectedOtherUserId!);
      }
    } catch (_) {
      _showMessage('No se pudo actualizar el chat.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus chats.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: AppColors.deepNavy),
                    child: _threads.isEmpty
                        ? const Center(
                            child: Text(
                              'Aún no tienes conversaciones.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _threads.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final thread = _threads[index];
                              final isSelected =
                                  thread.otherUserId == _selectedOtherUserId;
                              return Card(
                                color: isSelected
                                    ? const Color(0xFF16356A)
                                    : const Color(0xFF0D2347),
                                child: ListTile(
                                  onTap: () => _selectThread(thread),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white12,
                                    child: Text(
                                      _initials(thread.otherName),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    thread.otherName.isEmpty
                                        ? '@${thread.otherUserId}'
                                        : thread.otherName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    thread.lastMessage.isEmpty
                                        ? 'Sin mensajes'
                                        : thread.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) =>
                                        _handleThreadAction(thread, value),
                                    itemBuilder: (context) =>
                                        <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'pin',
                                        child: Text(
                                          thread.pinned
                                              ? 'Desanclar'
                                              : 'Anclar',
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'block',
                                        child: Text(
                                          thread.blocked
                                              ? 'Desbloquear'
                                              : 'Bloquear',
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Eliminar chat'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFF10233F)),
                    child: _selectedThread == null
                        ? const Center(
                            child: Text(
                              'Selecciona una conversación.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : Column(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: const Color(0xFF0C1E37),
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundColor: Colors.white12,
                                      child: Text(
                                        _initials(_selectedThread!.otherName),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedThread!.otherName.isEmpty
                                            ? '@${_selectedThread!.otherUserId}'
                                            : _selectedThread!.otherName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final mine = message.senderId == _userId;
                                    return Align(
                                      alignment: mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mine
                                              ? const Color(0xFF1D4D9B)
                                              : const Color(0xFF26384F),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          message.content,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Escribe un mensaje para continuar...',
                                            filled: true,
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        onPressed: _sendMessage,
                                        icon: const Icon(Icons.send),
                                        label: const Text('Enviar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  String _initials(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

