// lib/viewmodels/blackjack_viewmodel.dart

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/playing_card.dart';
import '../utils/constants.dart';

enum GamePhase {
  betting,
  playerTurn,
  dealerTurn,
  roundEnd,
}

class BlackjackViewModel extends ChangeNotifier {
  // ========== Config ==========
  final int numDecks;
  final double shuffleThresholdPercent;
  final bool dealerHitsSoft17;

  // Bankroll
  int bankroll;
  final int minBet;
  final int maxBet;

  int pendingBet = 0;
  bool _betLocked = false;

  // Shoe
  final List<PlayingCard> _shoe = [];

  // State
  GamePhase _phase = GamePhase.betting;
  GamePhase get phase => _phase;

  final List<PlayingCard> _dealerCards = [];
  final List<List<PlayingCard>> _playerHands = [];
  final List<int> _playerBets = [];
  final List<bool> _handDone = [];

  int _activeHandIndex = 0;

  String lastRoundMessage = '';

  // ========== Persistence ==========
  Database? _db;
  static const String _tableName = 'kv';
  static const String _stateKey = 'game_state';

  // Auto-topup config
  final bool autoTopUpEnabled;
  final int autoTopUpThreshold; // if bankroll < this, auto topup triggers
  final int autoTopUpAmount;

  BlackjackViewModel({
    this.numDecks = 6,
    this.shuffleThresholdPercent = 0.25,
    this.dealerHitsSoft17 = true,
    this.bankroll = 1000,
    this.minBet = 1,
    this.maxBet = 100000,
    this.autoTopUpEnabled = true,
    this.autoTopUpThreshold = 10,
    this.autoTopUpAmount = 100,
  }) {
    _buildShoe();
    // NOTE: prefer using factory create(...) to load persisted state.
  }

  /// Async factory. Recommended: use this to obtain a VM already loaded from DB.
  static Future<BlackjackViewModel> create({
    int numDecks = 6,
    double shuffleThresholdPercent = 0.25,
    bool dealerHitsSoft17 = true,
    int bankroll = 1000,
    int minBet = 1,
    int maxBet = 100000,
    bool autoTopUpEnabled = true,
    int autoTopUpThreshold = 10,
    int autoTopUpAmount = 100,
  }) async {
    final vm = BlackjackViewModel(
      numDecks: numDecks,
      shuffleThresholdPercent: shuffleThresholdPercent,
      dealerHitsSoft17: dealerHitsSoft17,
      bankroll: bankroll,
      minBet: minBet,
      maxBet: maxBet,
      autoTopUpEnabled: autoTopUpEnabled,
      autoTopUpThreshold: autoTopUpThreshold,
      autoTopUpAmount: autoTopUpAmount,
    );
    await vm._initPersistence();
    return vm;
  }

  /* ================= GETTERS ================= */

  List<PlayingCard> get dealerCards =>
      List<PlayingCard>.unmodifiable(_dealerCards);

  List<List<PlayingCard>> get playerHands => _playerHands
      .map<List<PlayingCard>>(
        (List<PlayingCard> h) => List<PlayingCard>.unmodifiable(h),
      )
      .toList(growable: false);

  List<int> get playerBets => List<int>.unmodifiable(_playerBets);

  List<int> get playerScores =>
      _playerHands.map((h) => _calculateScore(h)).toList(growable: false);

  int get dealerScore => _calculateScore(_dealerCards);

  int get activeHandIndex => _activeHandIndex;

  bool get isBettingPhase => _phase == GamePhase.betting;
  bool get isPlayerTurn => _phase == GamePhase.playerTurn;
  bool get isDealerTurn => _phase == GamePhase.dealerTurn;
  bool get isRoundEnd => _phase == GamePhase.roundEnd;

  int get remainingCards => _shoe.length;
  int get totalCardsInShoe => numDecks * 52;

  bool get canSplit {
    if (!isPlayerTurn) return false;
    if (_playerHands.isEmpty) return false;
    final hand = _playerHands[_activeHandIndex];
    if (hand.length != 2) return false;
    if (hand[0].rank != hand[1].rank) return false;
    return bankroll >= _playerBets[_activeHandIndex];
  }

  /* ================= SHOE ================= */

  void _buildShoe() {
    _shoe.clear();
    for (int d = 0; d < numDecks; d++) {
      for (final suit in cardSuits) {
        for (final rank in cardRanks) {
          _shoe.add(PlayingCard(rank: rank, suit: suit));
        }
      }
    }
    _shuffle(_shoe);
  }

  void _shuffle(List<PlayingCard> list) {
    final rnd = Random();
    for (int i = list.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  PlayingCard _draw() {
    final threshold = (totalCardsInShoe * shuffleThresholdPercent).ceil();
    if (_shoe.length <= threshold) {
      _buildShoe();
    }
    if (_shoe.isEmpty) {
      _buildShoe();
    }
    return _shoe.removeLast();
  }

  /* ================= PERSISTENCE (sqflite) ================= */

  Future<void> _initPersistence() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'blackjack_vm.db');

    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $_tableName (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    });

    await _loadState();
  }

  Future<void> _saveState() async {
    if (_db == null) return;
    final state = <String, dynamic>{
      'bankroll': bankroll,
      'pendingBet': pendingBet,
      'lastRoundMessage': lastRoundMessage,
      // Add more fields if you want to persist hands / shoe / bets etc.
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final encoded = jsonEncode(state);
    await _db!.insert(
      _tableName,
      {'key': _stateKey, 'value': encoded},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _loadState() async {
    if (_db == null) return;
    final rows = await _db!.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_stateKey],
      limit: 1,
    );
    if (rows.isEmpty) return;
    try {
      final value = rows.first['value'] as String;
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      if (decoded.containsKey('bankroll')) {
        bankroll = decoded['bankroll'] is int
            ? decoded['bankroll'] as int
            : (decoded['bankroll'] as num).toInt();
      }
      pendingBet = decoded['pendingBet'] is int
          ? decoded['pendingBet'] as int
          : (decoded['pendingBet'] ?? 0) as int;
      lastRoundMessage = decoded['lastRoundMessage'] as String? ?? '';
      // After load, ensure auto top-up rule
      _checkAutoTopUpAndPersist();
      notifyListeners();
    } catch (e) {
      // ignore parse errors - proceed with defaults
      if (kDebugMode) {
        print('BlackjackViewModel: failed to load state: $e');
      }
    }
  }

  /* ================= BETTING ================= */

  bool placeBet(int amount) {
    if (!isBettingPhase || _betLocked) return false;
    if (amount < minBet || amount > maxBet) return false;
    if (amount > bankroll) return false;

    pendingBet = amount;
    _betLocked = true;
    _saveState(); // persist pendingBet
    notifyListeners();
    return true;
  }

  bool startRound() {
    if (!isBettingPhase || pendingBet <= 0) return false;

    bankroll -= pendingBet;
    _postBankrollChange(); // check auto-topup & persist

    _dealerCards.clear();
    _playerHands.clear();
    _playerBets.clear();
    _handDone.clear();

    _playerHands.add(<PlayingCard>[]);
    _playerBets.add(pendingBet);
    _handDone.add(false);

    pendingBet = 0;
    _betLocked = false;

    for (int i = 0; i < initialCardsCount; i++) {
      for (final hand in _playerHands) {
        hand.add(_draw());
      }
      _dealerCards.add(_draw());
    }

    _activeHandIndex = 0;

    final playerBJ = _isBlackjack(_playerHands[0]);
    final dealerBJ = _isBlackjack(_dealerCards);

    if (playerBJ || dealerBJ) {
      _phase = GamePhase.roundEnd;
      _resolve(initial: true);
    } else {
      _phase = GamePhase.playerTurn;
    }

    notifyListeners();
    return true;
  }

  /* ================= PLAYER ================= */

  void hit() {
    if (!isPlayerTurn) return;
    final hand = _playerHands[_activeHandIndex];
    hand.add(_draw());

    if (_calculateScore(hand) >= blackjackMaxScore) {
      _handDone[_activeHandIndex] = true;
      _advanceHand();
    }
    notifyListeners();
  }

  void stand() {
    if (!isPlayerTurn) return;
    _handDone[_activeHandIndex] = true;
    _advanceHand();
    notifyListeners();
  }

  void doubleDown() {
    if (!isPlayerTurn) return;
    final bet = _playerBets[_activeHandIndex];
    if (bankroll < bet) return;

    bankroll -= bet;
    _postBankrollChange();

    _playerBets[_activeHandIndex] = bet * 2;

    final hand = _playerHands[_activeHandIndex];
    hand.add(_draw());
    _handDone[_activeHandIndex] = true;
    _advanceHand();
    notifyListeners();
  }

  bool split() {
    if (!canSplit) return false;

    final hand = _playerHands[_activeHandIndex];
    final bet = _playerBets[_activeHandIndex];

    bankroll -= bet;
    _postBankrollChange();

    final a = hand[0];
    final b = hand[1];

    _playerHands[_activeHandIndex] = <PlayingCard>[a, _draw()];
    _playerHands.insert(_activeHandIndex + 1, <PlayingCard>[b, _draw()]);

    _playerBets.insert(_activeHandIndex + 1, bet);
    _handDone.insert(_activeHandIndex + 1, false);

    notifyListeners();
    return true;
  }

  void _advanceHand() {
    for (int i = _activeHandIndex + 1; i < _playerHands.length; i++) {
      if (!_handDone[i]) {
        _activeHandIndex = i;
        return;
      }
    }
    _phase = GamePhase.dealerTurn;
    _dealerPlay();
  }

  /* ================= DEALER ================= */

  void _dealerPlay() {
    while (true) {
      final score = _calculateScore(_dealerCards);
      if (score > blackjackMaxScore) break;
      if (score < dealerStandScore ||
          (score == dealerStandScore && dealerHitsSoft17 && _isSoft(_dealerCards))) {
        _dealerCards.add(_draw());
        continue;
      }
      break;
    }
    _phase = GamePhase.roundEnd;
    _resolve();
    notifyListeners();
  }

  void _resolve({bool initial = false}) {
    final dealerScore = _calculateScore(_dealerCards);
    final sb = StringBuffer();

    for (int i = 0; i < _playerHands.length; i++) {
      final hand = _playerHands[i];
      final bet = _playerBets[i];
      final score = _calculateScore(hand);

      String result;

      if (initial && _isBlackjack(hand)) {
        final payout = (bet * 3) ~/ 2;
        bankroll += bet + payout;
        result = 'Blackjack +$payout';
      } else if (score > blackjackMaxScore) {
        result = 'Bust';
      } else if (dealerScore > blackjackMaxScore || score > dealerScore) {
        bankroll += bet * 2;
        result = 'Win +$bet';
      } else if (score == dealerScore) {
        bankroll += bet;
        result = 'Push';
      } else {
        result = 'Lose';
      }

      sb.writeln('Hand ${i + 1}: $result');
    }

    lastRoundMessage = sb.toString().trim();

    // persist bankroll and message
    _postBankrollChange();
    _saveState();

    notifyListeners();
  }

  void prepareNextRound() {
    _dealerCards.clear();
    _playerHands.clear();
    _playerBets.clear();
    _handDone.clear();
    _activeHandIndex = 0;
    pendingBet = 0;
    lastRoundMessage = '';
    _phase = GamePhase.betting;
    _saveState();
    notifyListeners();
  }

  /* ================= SCORE ================= */

  int _calculateScore(List<PlayingCard> cards) {
    int total = 0;
    int aces = 0;

    for (final c in cards) {
      if (c.isAce) {
        total += aceHighValue;
        aces++;
      } else if (c.isFaceCard) {
        total += faceCardValues[c.rank]!;
      } else {
        total += numberCardValues[c.rank]!;
      }
    }

    while (total > blackjackMaxScore && aces > 0) {
      total -= 10;
      aces--;
    }
    return total;
  }

  bool _isSoft(List<PlayingCard> cards) =>
      cards.any((c) => c.isAce) && _calculateScore(cards) <= blackjackMaxScore;

  bool _isBlackjack(List<PlayingCard> cards) =>
      cards.length == 2 && _calculateScore(cards) == blackjackMaxScore;

  /* ================ Dev helpers & persistence helpers ================ */

  void reshuffleShoe() {
    _buildShoe();
    notifyListeners();
  }

  /// Public method to top up bankroll manually (and persist).
  void topUpBankroll(int amount) {
    bankroll += amount;
    _postBankrollChange();
    notifyListeners();
  }

  /// Internal: called whenever bankroll changes to handle auto-topup & persist.
  void _postBankrollChange() {
    // auto top-up if enabled
    if (autoTopUpEnabled && bankroll < autoTopUpThreshold) {
      // do not repeatedly add more than once per check — but adding once is fine here.
      bankroll += autoTopUpAmount;
      lastRoundMessage = 'Auto deposit +\$$autoTopUpAmount';
      // optionally, if you want to also show a toast in UI, you can surface lastRoundMessage
    }
    _saveState();
  }

  // helper that checks auto topup (used after load)
  void _checkAutoTopUpAndPersist() {
    if (autoTopUpEnabled && bankroll < autoTopUpThreshold) {
      bankroll += autoTopUpAmount;
      lastRoundMessage = 'Auto deposit +\$$autoTopUpAmount';
    }
    _saveState();
  }

  /// Forcefully clear persisted DB (dev use)
  Future<void> clearPersistedState() async {
    if (_db == null) return;
    await _db!.delete(_tableName, where: 'key = ?', whereArgs: [_stateKey]);
  }
}
