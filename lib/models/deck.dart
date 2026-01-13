// lib/models/deck.dart

import 'dart:math';

import 'playing_card.dart';
import '../utils/constants.dart';

/// Deck kartu standar (52 kartu)
class Deck {
  final List<PlayingCard> _cards = [];

  Deck() {
    _generateDeck();
    shuffle();
  }

  /// Membuat 52 kartu unik
  void _generateDeck() {
    _cards.clear();

    for (final suit in cardSuits) {
      for (final rank in cardRanks) {
        _cards.add(
          PlayingCard(rank: rank, suit: suit),
        );
      }
    }
  }

  /// Mengacak kartu (Fisher–Yates shuffle)
  void shuffle() {
    final random = Random();
    for (int i = _cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = temp;
    }
  }

  /// Mengambil satu kartu dari atas deck
  PlayingCard draw() {
    if (_cards.isEmpty) {
      throw StateError('Deck is empty');
    }
    return _cards.removeLast();
  }

  /// Jumlah kartu tersisa
  int get remainingCards => _cards.length;

  /// Cek apakah deck habis
  bool get isEmpty => _cards.isEmpty;

  /// Reset deck (pakai ulang game)
  void reset() {
    _generateDeck();
    shuffle();
  }
}