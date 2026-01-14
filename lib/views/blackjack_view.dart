import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/blackjack_viewmodel.dart';
import '../models/playing_card.dart';

class BlackjackView extends StatefulWidget {
  const BlackjackView({super.key});

  @override
  State<BlackjackView> createState() => _BlackjackViewState();
}

class _BlackjackViewState extends State<BlackjackView>
    with TickerProviderStateMixin {
  // control deal animation sequence
  bool _isDealing = false;
  final Map<String, bool> _revealed = {}; // key: 'dealer-0', 'player-0-1' etc.

  late AnimationController _overlayController;
  late Animation<double> _overlayScale;

  @override
  void initState() {
    super.initState();

    _overlayController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _overlayScale =
        CurvedAnimation(parent: _overlayController, curve: Curves.easeOutBack);

    // start hidden
    _overlayController.value = 0.0;
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  // helper to compute suit color
  Color _suitColor(String suit) => (suit == '♥' || suit == '♦')
      ? Colors.red.shade700
      : Colors.black;

  // flip-card widget (front/back)
  Widget _flippableCard(PlayingCard card, {required bool faceUp}) {
    return _FlippableCard(
      width: 72,
      height: 104,
      front: _cardFront(card),
      back: _cardBack(),
      faceUp: faceUp,
    );
  }

  // front view of playing card
  Widget _cardFront(PlayingCard card) {
    return Container(
      width: 72,
      height: 104,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(card.rank,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _suitColor(card.suit))),
          ),
          Center(
            child: Text(card.suit,
                style: TextStyle(fontSize: 32, color: _suitColor(card.suit))),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(card.rank,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _suitColor(card.suit))),
            ),
          ),
        ],
      ),
    );
  }

  // back view of playing card
  Widget _cardBack() {
    return Container(
      width: 72,
      height: 104,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4))
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: pi / 12,
          child: Opacity(
            opacity: 0.14,
            child: Container(
              width: 36,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _resultColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('win')) return Colors.amber.shade400;
    if (t.contains('lose')) return Colors.redAccent.shade100;
    return Colors.white;
  }

  // when user taps deal: run local dealing animation then call viewmodel.startRound()
  Future<void> _onDealPressed(BlackjackViewModel vm) async {
    if (_isDealing) return;
    setState(() {
      _isDealing = true;
      _revealed.clear();
    });

    // sequence reveal timing: dealer, player1, dealer face down, player1 etc.
    // We'll do a simple stagger: dealer[0], player[0], dealer[1], player[1]
    final dealerCount = vm.dealerCards.length;
    final playerCount = vm.playerHands.isNotEmpty ? vm.playerHands[0].length : 0;

    final total = max(dealerCount, playerCount) * 2 + 2;
    int step = 0;

    // reveal sequence - create keys and progressively set revealed true
    // We'll just reveal all cards with small delay to simulate dealing
    final allKeys = <String>[];

    // dealer keys
    for (var i = 0; i < dealerCount; i++) {
      allKeys.add('dealer-$i');
    }
    // first player's first hand keys (we only animate primary hand to keep simple)
    final playerHand = vm.playerHands.isNotEmpty ? vm.playerHands[0] : <PlayingCard>[];
    for (var i = 0; i < playerHand.length; i++) {
      allKeys.add('player-0-$i');
    }

    // stagger reveal
    for (var key in allKeys) {
      await Future.delayed(const Duration(milliseconds: 140));
      setState(() {
        _revealed[key] = true;
      });
      step++;
    }

    // small pause then call vm.startRound
    await Future.delayed(const Duration(milliseconds: 220));
    vm.startRound();

    // finish
    setState(() {
      _isDealing = false;
    });
  }

  // listen overlay show/hide
  void _maybeShowOverlay(bool isRoundEnd) {
    if (isRoundEnd) {
      _overlayController.forward();
    } else {
      _overlayController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlackjackViewModel>(builder: (context, vm, _) {
      final isBetting = vm.isBettingPhase;
      final isPlayerTurn = vm.isPlayerTurn;
      final isRoundEnd = vm.isRoundEnd;

      // handle overlay animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowOverlay(isRoundEnd);
      });

      return Scaffold(
        backgroundColor: Colors.green.shade900,
        body: SafeArea(
          child: Stack(
            children: [
              // background table gradient + subtle vignette
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.6),
                      radius: 1.1,
                      colors: [
                        Colors.green.shade900,
                        Colors.green.shade800,
                        Colors.green.shade700,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.06)
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Column(
                children: [
                  // Top bar with subtle chip/balance
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BLACKJACK 21',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2),
                        ),
                        Row(
                          children: [
                            _BalanceBadge(balance: vm.bankroll),
                            const SizedBox(width: 8),
                            _StylishChip(text: '\$${vm.pendingBet}', visible: isBetting),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // DEALER area
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Column(
                      children: [
                        const Text('DEALER',
                            style: TextStyle(
                                color: Colors.white70, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(vm.dealerCards.length, (i) {
                                final card = vm.dealerCards[i];
                                final key = 'dealer-$i';
                                final revealed = _revealed[key] ?? !_isDealing;
                                // if it's second dealer card and playerTurn, keep back-face (classic casino)
                                final faceUp = !(i == 1 && vm.isPlayerTurn) && revealed;
                                return AnimatedPadding(
                                  duration: const Duration(milliseconds: 220),
                                  padding: EdgeInsets.only(left: i == 0 ? 16 : 8),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    opacity: revealed ? 1 : 0.0,
                                    child: Transform.translate(
                                      offset: revealed ? Offset(0, 0) : Offset(0, 14),
                                      child: _flippableCard(card, faceUp: faceUp),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Player hands
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 16),
                      itemCount: vm.playerHands.length,
                      itemBuilder: (context, i) {
                        final active = i == vm.activeHandIndex && isPlayerTurn;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: active ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? Colors.amber.shade400 : Colors.white10,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'HAND ${i + 1} • BET \$${vm.playerBets[i]}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                  Text('SCORE ${vm.playerScores[i]}',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 120,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(vm.playerHands[i].length, (j) {
                                      final card = vm.playerHands[i][j];
                                      final key = 'player-$i-$j';
                                      final revealed = _revealed[key] ?? !_isDealing;
                                      return Padding(
                                        padding: EdgeInsets.only(right: 10),
                                        child: AnimatedOpacity(
                                          duration: Duration(milliseconds: 220 + j * 30),
                                          opacity: revealed ? 1 : 0,
                                          child: Transform.translate(
                                            offset: revealed ? Offset(0, 0) : Offset(0, 18),
                                            child: _flippableCard(card, faceUp: true),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Controls / betting area
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -3))
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // quick chip row for betting
                        if (isBetting)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [10, 25, 50, 100].map((v) {
                                  final enabled = vm.pendingBet + v <= vm.bankroll;
                                  return GestureDetector(
                                    onTap: enabled ? () => vm.placeBet(v) : null,
                                    child: AnimatedScale(
                                      scale: enabled ? 1.0 : 0.9,
                                      duration: const Duration(milliseconds: 180),
                                      child: _BetChip(amount: v, enabled: enabled),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: vm.pendingBet > 0 && !_isDealing
                                          ? () => _onDealPressed(vm)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 6,
                                      ),
                                      child: const Text('DEAL', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                        // ACTIONS
                        if (!isBetting) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn ? vm.hit : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Hit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn ? vm.stand : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
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
                                  onPressed: isPlayerTurn && vm.canSplit ? vm.split : null,
                                  child: const Text('Split'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn &&
                                          vm.bankroll >= vm.playerBets[vm.activeHandIndex]
                                      ? vm.doubleDown
                                      : null,
                                  child: const Text('Double'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Result overlay
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isRoundEnd,
                  child: FadeTransition(
                    opacity:
                        CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
                    child: ScaleTransition(
                      scale: _overlayScale,
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                vm.lastRoundMessage.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _resultColor(vm.lastRoundMessage),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton(
                                onPressed: vm.prepareNextRound,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('NEXT ROUND'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Small widget showing balance with subtle style
class _BalanceBadge extends StatelessWidget {
  final int balance;
  const _BalanceBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text('\$$balance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Bet chip look
class _BetChip extends StatelessWidget {
  final int amount;
  final bool enabled;
  const _BetChip({required this.amount, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(colors: [Colors.orange.shade300, Colors.orange.shade500])
            : LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: enabled
            ? const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]
            : null,
      ),
      child: Text('\$$amount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

/// Stylish small chip for header
class _StylishChip extends StatelessWidget {
  final String text;
  final bool visible;
  const _StylishChip({required this.text, this.visible = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

/// Flippable card widget: front/back with rotation Y animation
class _FlippableCard extends StatelessWidget {
  final Widget front;
  final Widget back;
  final bool faceUp;
  final double width;
  final double height;

  const _FlippableCard({
    required this.front,
    required this.back,
    required this.faceUp,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // use AnimatedSwitcher with custom transition rotating on Y axis
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        transitionBuilder: _transitionBuilder,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        child: faceUp
            ? Container(key: const ValueKey(1), child: front)
            : Container(key: const ValueKey(2), child: back),
      ),
    );
  }

  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
    return AnimatedBuilder(
      animation: rotateAnim,
      child: child,
      builder: (context, child) {
        final isUnder = (ValueKey(child.hashCode) != (faceUp ? const ValueKey(1) : const ValueKey(2)));
        var tilt = (animation.value - 0.5).abs() - 0.5;
        tilt *= isUnder ? -0.003 : 0.003;
        final value = rotateAnim.value;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(value)
          ..rotateZ(tilt);
        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: child,
        );
      },
    );
  }
}
