import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/direct_messages_service.dart';
import 'user_profile_detail_page.dart';

/// Local-only RSVP chip state for event invite DMs (not persisted).
enum _InviteChoice { attend, decline }

class DirectMessagePage extends StatefulWidget {
  const DirectMessagePage({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  final String friendUid;
  final String friendName;

  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool? _canSendChat;

  /// Per-message selection for Attend / Decline (UI only).
  final Map<String, _InviteChoice> _inviteChoiceByMessageKey = {};

  Future<void> _safeMarkRead() async {
    try {
      await markDirectThreadAsRead(widget.friendUid);
    } catch (_) {
      // Non-fatal: unread indicators should not crash chat view.
    }
  }

  Future<void> _refreshCanSendChat() async {
    final v = await canSendDirectChatTo(widget.friendUid);
    if (mounted) setState(() => _canSendChat = v);
  }

  @override
  void initState() {
    super.initState();
    _refreshCanSendChat();
    _safeMarkRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await sendDirectMessage(recipientUid: widget.friendUid, text: text);
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  void _openInvitedEventInCalendar(
    BuildContext context, {
    required String? ownerUid,
    required String? eventId,
  }) {
    final o = ownerUid?.trim();
    final e = eventId?.trim();
    if (o == null || o.isEmpty || e == null || e.isEmpty) return;
    context.go(
      '/calendar?focusOwner=${Uri.encodeComponent(o)}&focusEvent=${Uri.encodeComponent(e)}',
    );
  }

  String _stableMessageKey(Map<String, dynamic> msg) {
    final id = msg['id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    final text = msg['text'] as String? ?? '';
    final sent = msg['sentAt'];
    return 'fallback_${text.hashCode}_${sent.hashCode}';
  }

  Widget _buildAttendDeclineSelector(String messageKey, bool mine) {
    final _InviteChoice? choice = _inviteChoiceByMessageKey[messageKey];

    final dividerColor =
        mine ? Colors.white.withValues(alpha: 0.35) : Colors.black26;

    Color cellBg({required bool isAttend}) {
      final selected =
          isAttend ? choice == _InviteChoice.attend : choice == _InviteChoice.decline;
      if (mine) {
        if (selected) return Colors.white;
        return Colors.white.withValues(alpha: 0.22);
      }
      if (selected) {
        return DirectMessagePage.forgeBlue.withValues(alpha: 0.14);
      }
      return const Color(0xFFE8EAED);
    }

    Color cellFg({required bool isAttend}) {
      final selected =
          isAttend ? choice == _InviteChoice.attend : choice == _InviteChoice.decline;
      if (mine) {
        if (selected) return DirectMessagePage.forgeBlue;
        return Colors.white;
      }
      if (selected) return DirectMessagePage.forgeBlue;
      return Colors.black54;
    }

    void onSideTapped(_InviteChoice side) {
      setState(() {
        _inviteChoiceByMessageKey[messageKey] = side;
      });
    }

    Widget side({
      required bool isAttend,
      required String label,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSideTapped(
              isAttend ? _InviteChoice.attend : _InviteChoice.decline,
            ),
            splashColor: mine
                ? Colors.white.withValues(alpha: 0.35)
                : DirectMessagePage.forgeBlue.withValues(alpha: 0.22),
            highlightColor: mine
                ? Colors.white.withValues(alpha: 0.18)
                : DirectMessagePage.forgeBlue.withValues(alpha: 0.10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cellBg(isAttend: isAttend),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: choice ==
                          (isAttend
                              ? _InviteChoice.attend
                              : _InviteChoice.decline)
                      ? FontWeight.w700
                      : FontWeight.w600,
                  fontSize: 13,
                  color: cellFg(isAttend: isAttend),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          side(isAttend: true, label: 'Attend'),
          Container(width: 1, height: 44, color: dividerColor),
          side(isAttend: false, label: 'Decline'),
        ],
      ),
    );
  }

  Widget _buildEventInviteBubble(
    BuildContext context,
    Map<String, dynamic> msg,
    bool mine,
  ) {
    final text = (msg['text'] as String?) ?? '';
    final ownerUid = msg['eventOwnerUid'] as String?;
    final eventId = msg['eventId'] as String?;
    final messageKey = _stableMessageKey(msg);
    final textColor = mine ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: mine ? DirectMessagePage.forgeBlue : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: mine
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: textColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: mine
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DirectMessagePage.forgeBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: ownerUid != null && eventId != null
                        ? () => _openInvitedEventInCalendar(
                              context,
                              ownerUid: ownerUid,
                              eventId: eventId,
                            )
                        : null,
                    child: const Text(
                      'View event',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DirectMessagePage.forgeBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: ownerUid != null && eventId != null
                        ? () => _openInvitedEventInCalendar(
                              context,
                              ownerUid: ownerUid,
                              eventId: eventId,
                            )
                        : null,
                    child: const Text(
                      'View event',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          _buildAttendDeclineSelector(messageKey, mine),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _fmt(msg['sentAt'] as DateTime?),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: mine
                    ? Colors.white70
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _threadIdForThisChat() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return '';
    return directThreadIdForPair(me, widget.friendUid);
  }

  Widget _buildFriendRequestBubble(
    BuildContext context,
    Map<String, dynamic> msg,
    bool mine,
  ) {
    final text = (msg['text'] as String?) ?? '';
    final requesterUid = msg['senderUid'] as String?;
    final messageId = msg['id'] as String?;
    final threadId = _threadIdForThisChat();
    final textColor = mine ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: mine ? DirectMessagePage.forgeBlue : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: mine
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: textColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: mine
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DirectMessagePage.forgeBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: requesterUid != null && requesterUid.isNotEmpty
                        ? () => openUserProfileDetailFromUid(
                              context,
                              uid: requesterUid,
                            )
                        : null,
                    child: const Text(
                      'View profile',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DirectMessagePage.forgeBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: requesterUid != null && requesterUid.isNotEmpty
                        ? () => openUserProfileDetailFromUid(
                              context,
                              uid: requesterUid,
                            )
                        : null,
                    child: const Text(
                      'View profile',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
          if (!mine) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: requesterUid == null ||
                            messageId == null ||
                            threadId.isEmpty
                        ? null
                        : () async {
                            try {
                              await acceptIncomingFriendRequest(
                                requesterUid: requesterUid,
                                threadId: threadId,
                                messageId: messageId,
                              );
                              if (!context.mounted) return;
                              await _refreshCanSendChat();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You are now friends'),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not accept: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: messageId == null || threadId.isEmpty
                        ? null
                        : () async {
                            try {
                              await declineIncomingFriendRequest(
                                threadId: threadId,
                                messageId: messageId,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not decline: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Waiting for a response',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _fmt(msg['sentAt'] as DateTime?),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: mine
                    ? Colors.white70
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final canSend = _canSendChat == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          widget.friendName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getDirectMessagesStream(widget.friendUid),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <Map<String, dynamic>>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start the conversation',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final mine = msg['senderUid'] == me;
                    final kind = msg['messageKind'] as String?;
                    if (kind == 'friend_request') {
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _buildFriendRequestBubble(context, msg, mine),
                      );
                    }
                    if (kind == 'event_invite') {
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _buildEventInviteBubble(context, msg, mine),
                      );
                    }
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? DirectMessagePage.forgeBlue : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              (msg['text'] as String?) ?? '',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: mine ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(msg['sentAt'] as DateTime?),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: mine
                                    ? Colors.white70
                                    : Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: _canSendChat == null
                ? const SizedBox(
                    height: 56,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : canSend
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textCapitalization: TextCapitalization.sentences,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F3F5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: DirectMessagePage.forgeBlue,
                                    ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        color: Colors.white,
                        child: Text(
                          'You can message each other once you are friends.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
