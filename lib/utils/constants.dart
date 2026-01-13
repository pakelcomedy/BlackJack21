// lib/utils/constants.dart

/// ===============================
/// GAME CONFIGURATION
/// ===============================

/// Nilai maksimum sebelum bust
const int blackjackMaxScore = 21;

/// Nilai dealer wajib hit
const int dealerStandScore = 17;

/// Jumlah kartu awal untuk pemain & dealer
const int initialCardsCount = 2;

/// ===============================
/// CARD VALUES
/// ===============================

/// Nilai kartu bernomor (2–10)
const Map<String, int> numberCardValues = {
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  '10': 10,
};

/// Nilai kartu wajah
const Map<String, int> faceCardValues = {
  'J': 10,
  'Q': 10,
  'K': 10,
};

/// Nilai kartu As (bisa fleksibel 1 atau 11)
const int aceHighValue = 11;
const int aceLowValue = 1;

/// ===============================
/// CARD DEFINITIONS
/// ===============================

/// Semua simbol kartu
const List<String> cardSuits = [
  '♠', // Spades
  '♥', // Hearts
  '♦', // Diamonds
  '♣', // Clubs
];

/// Semua rank kartu
const List<String> cardRanks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];

/// ===============================
/// GAME STATES
/// ===============================

/// Status permainan
enum GameStatus {
  idle,
  playerTurn,
  dealerTurn,
  playerBust,
  dealerBust,
  playerWin,
  dealerWin,
  draw,
}

/// ===============================
/// UI / TEXT CONSTANTS
/// ===============================

const String appTitle = 'Blackjack';

const String playerLabel = 'Player';
const String dealerLabel = 'Dealer';

const String hitButtonText = 'Hit';
const String standButtonText = 'Stand';
const String restartButtonText = 'Restart';

const String blackjackText = 'Blackjack!';
const String bustText = 'Bust!';
const String winText = 'You Win!';
const String loseText = 'Dealer Wins';
const String drawText = 'Draw';

/// ===============================
/// ANIMATION / DELAY
/// ===============================

/// Delay dealer saat mengambil kartu (ms)
const int dealerDrawDelayMs = 800;
