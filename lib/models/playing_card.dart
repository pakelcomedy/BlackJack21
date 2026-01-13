// lib/models/playing_card.dart

import '../utils/constants.dart';

/// Model kartu permainan (immutable)
class PlayingCard {
  final String rank; // A, 2–10, J, Q, K
  final String suit; // ♠ ♥ ♦ ♣

  const PlayingCard({
    required this.rank,
    required this.suit,
  });

  /// Apakah kartu As
  bool get isAce => rank == 'A';

  /// Apakah kartu wajah (J, Q, K)
  bool get isFaceCard => faceCardValues.containsKey(rank);

  /// Nilai default kartu (Ace = 11)
  int get baseValue {
    if (isAce) return aceHighValue;
    if (isFaceCard) return faceCardValues[rank]!;
    return numberCardValues[rank]!;
  }

  /// Representasi teks (contoh: A♠, 10♦)
  String get display => '$rank$suit';

  /// Digunakan untuk debugging
  @override
  String toString() => display;

  /// Equality override supaya kartu bisa dibandingkan
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          suit == other.suit;

  @override
  int get hashCode => rank.hashCode ^ suit.hashCode;
}
