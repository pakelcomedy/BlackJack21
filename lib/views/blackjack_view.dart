import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/blackjack_viewmodel.dart';
import '../models/playing_card.dart';

class BlackjackView extends StatelessWidget {
  const BlackjackView({super.key});

  Color _suitColor(String suit) =>
      (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;

  Widget _card(PlayingCard card) {
    return Container(
      width: 56,
      height: 82,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(card.rank,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _suitColor(card.suit))),
          Text(card.suit,
              style: TextStyle(
                  fontSize: 20,
                  color: _suitColor(card.suit))),
          RotatedBox(
            quarterTurns: 2,
            child: Text(card.rank,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _suitColor(card.suit))),
          ),
        ],
      ),
    );
  }

  Widget _cardBack() {
    return Container(
      width: 56,
      height: 82,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Color _resultColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('win')) return Colors.amber;
    if (t.contains('lose')) return Colors.redAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlackjackViewModel>(
      builder: (context, vm, _) {
        final isBetting = vm.isBettingPhase;
        final isPlayerTurn = vm.isPlayerTurn;
        final isRoundEnd = vm.isRoundEnd;

        return Scaffold(
          backgroundColor: Colors.green.shade900,
          body: SafeArea(
            child: Stack(
              children: [
                // ================= TABLE =================
                Column(
                  children: [
                    // DEALER
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          const Text('DEALER',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                vm.dealerCards.length,
                                (i) => (i == 1 && isPlayerTurn)
                                    ? _cardBack()
                                    : _card(vm.dealerCards[i]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // PLAYER HANDS
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 12),
                        itemCount: vm.playerHands.length,
                        itemBuilder: (context, i) {
                          final active =
                              i == vm.activeHandIndex && isPlayerTurn;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? Colors.amber
                                    : Colors.white24,
                                width: active ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HAND ${i + 1} • BET \$${vm.playerBets[i]} • SCORE ${vm.playerScores[i]}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: vm.playerHands[i]
                                        .map(_card)
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // CONTROLS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Balance: \$${vm.bankroll}',
                                  style: const TextStyle(
                                      color: Colors.white)),
                              if (isBetting)
                                Text('Bet: \$${vm.pendingBet}',
                                    style: const TextStyle(
                                        color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // BETTING
                          if (isBetting) ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [10, 25, 50, 100].map((v) {
                                return ElevatedButton(
                                  onPressed:
                                      vm.pendingBet + v <= vm.bankroll
                                          ? () => vm.placeBet(v)
                                          : null,
                                  child: Text('\$$v'),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: vm.pendingBet > 0
                                    ? vm.startRound
                                    : null,
                                child: const Text('DEAL'),
                              ),
                            ),
                          ],

// ACTIONS
if (!isBetting) ...[
  Column(
    children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isPlayerTurn ? vm.hit : null,
              child: const Text('Hit'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: isPlayerTurn ? vm.stand : null,
              child: const Text('Stand'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed:
                  isPlayerTurn && vm.canSplit ? vm.split : null,
              child: const Text('Split'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: isPlayerTurn &&
                      vm.bankroll >=
                          vm.playerBets[vm.activeHandIndex]
                  ? vm.doubleDown
                  : null,
              child: const Text('Double'),
            ),
          ),
        ],
      ),
    ],
  ),
],
                        ],
                      ),
                    ),
                  ],
                ),

                // ================= RESULT OVERLAY =================
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: isRoundEnd
                      ? Container(
                          key: const ValueKey('result'),
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  vm.lastRoundMessage.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        _resultColor(vm.lastRoundMessage),
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: vm.prepareNextRound,
                                  child: const Text('NEXT ROUND'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
