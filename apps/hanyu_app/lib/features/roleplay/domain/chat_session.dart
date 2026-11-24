import 'dart:collection';

import 'package:doanchuyennganh2/features/roleplay/domain/scenario.dart';

class ChatTurn {
  const ChatTurn(this.text);
  final String text;
}

class ChatSession {
  ChatSession(this.number, this.scenario);
  static const turnLimit = 8;
  final createdAt = DateTime.now().toUtc();
  final int number;
  final Scenario scenario;
  final _turns = <ChatTurn>[];
  List<ChatTurn> get turns => UnmodifiableListView(_turns);
  String draft = '';
  bool _ended = false;
  bool get ended => _ended;
  bool confirmTurn(String value) {
    final text = value.trim();
    if (_ended ||
        _turns.length >= turnLimit ||
        text.isEmpty ||
        text.length > 300) {
      return false;
    }
    _turns.add(ChatTurn(text));
    draft = '';
    if (_turns.length == turnLimit) _ended = true;
    return true;
  }

  void end() {
    _ended = true;
    draft = '';
  }
}
