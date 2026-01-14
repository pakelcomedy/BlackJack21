// lib/views/blackjack_view.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/blackjack_viewmodel.dart';
import '../models/playing_card.dart';

// --- Palette (minimal, consistent) ------------------------------------------------
const Color _kBackground = Color(0xFF072E2A); // deep teal/green felt
const Color _kFelt = Color(0xFF0B3D35);
const Color _kAccent = Color(0xFFFFB74D); // warm amber accent for highlights
const Color _kCardBack = Color(0xFF1F2A2A);

class BlackjackView extends StatefulWidget {
  const BlackjackView({super.key});

  @override
  State<BlackjackView> createState() => _BlackjackViewState();
}

class _BlackjackViewState extends State<BlackjackView>
    with TickerProviderStateMixin {
  bool _isDealing = false;
  final Map<String, bool> _revealed = {}; // keys: 'dealer-0', 'player-0-1', etc.

  late AnimationController _overlayController;
  late Animation<double> _overlayScale;

  @override
  void initState() {
    super.initState();
    _overlayController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _overlayScale =
        CurvedAnimation(parent: _overlayController, curve: Curves.easeOutBack);
    _overlayController.value = 0.0;
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  Future<void> _onDealPressed(BlackjackViewModel vm) async {
    if (_isDealing || vm.pendingBet <= 0) return;
    setState(() {
      _isDealing = true;
      _revealed.clear();
    });

    // prepare keys for current visible cards (dealer + first player hand)
    final dealerCount = vm.dealerCards.length;
    final playerHand = vm.playerHands.isNotEmpty ? vm.playerHands[0] : <PlayingCard>[];
    final allKeys = <String>[];
    for (var i = 0; i < dealerCount; i++) allKeys.add('dealer-$i');
    for (var i = 0; i < playerHand.length; i++) allKeys.add('player-0-$i');

    // reveal in staggered sequence (gentle tempo)
    for (var i = 0; i < allKeys.length; i++) {
      await Future.delayed(const Duration(milliseconds: 110));
      setState(() => _revealed[allKeys[i]] = true);
    }

    // slight pause then start round
    await Future.delayed(const Duration(milliseconds: 180));
    vm.startRound();
    setState(() => _isDealing = false);
  }

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

      // schedule overlay animation update
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOverlay(isRoundEnd));

      return Scaffold(
        backgroundColor: _kBackground,
        body: SafeArea(
          child: Stack(
            children: [
              // subtle felt background (flat)
              Positioned.fill(
                child: Container(
                  color: _kFelt,
                ),
              ),

              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          'BLACKJACK',
                          style: TextStyle(
                              color: Color.fromRGBO(255, 255, 255, 0.95),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0),
                        ),
                        const Spacer(),
                        _Badge(label: 'BANK', value: '\$${vm.bankroll}'),
                        const SizedBox(width: 8),
                        _Badge(
                          label: 'BET',
                          value: '\$${vm.pendingBet}',
                          subtle: isBetting ? false : true,
                        ),
                      ],
                    ),
                  ),

                  // Dealer area
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEALER', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.70), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: vm.dealerCards.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final card = vm.dealerCards[i];
                              final key = 'dealer-$i';
                              final revealed = _revealed[key] ?? !_isDealing;
                              final faceUp = !(i == 1 && vm.isPlayerTurn) && revealed;
                              return AnimatedCardWrapper(
                                revealed: revealed,
                                child: FlippableCard(
                                  card: card,
                                  faceUp: faceUp,
                                  width: 76,
                                  height: 110,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Player hands area
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      itemCount: vm.playerHands.length,
                      itemBuilder: (context, idx) {
                        final hand = vm.playerHands[idx];
                        final active = idx == vm.activeHandIndex && isPlayerTurn;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: active ? Color.fromRGBO(0, 0, 0, 0.18) : Color.fromRGBO(0, 0, 0, 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? _kAccent.withAlpha(230) : Color.fromRGBO(255, 255, 255, 0.10), width: active ? 2 : 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('HAND ${idx + 1}  •  BET \$${vm.playerBets[idx]}', style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.70)))),
                                  Text('SCORE ${vm.playerScores[idx]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 120,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: hand.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (_, j) {
                                    final card = hand[j];
                                    final k = 'player-$idx-$j';
                                    final revealed = _revealed[k] ?? !_isDealing;
                                    return AnimatedCardWrapper(
                                      revealed: revealed,
                                      child: FlippableCard(
                                        card: card,
                                        faceUp: revealed,
                                        width: 76,
                                        height: 110,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Controls area (cleaner, limited colors)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(31, 42, 42, 0.95),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBetting) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [10, 25, 50, 100].map((v) {
                              final enabled = vm.pendingBet + v <= vm.bankroll;
                              return GestureDetector(
                                onTap: enabled ? () => vm.placeBet(v) : null,
                                child: _BetChip(amount: v, enabled: enabled),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: vm.pendingBet > 0 && !_isDealing ? () => _onDealPressed(vm) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kAccent.withAlpha(243),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('DEAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn ? vm.hit : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('HIT'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn ? vm.stand : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('STAND'),
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
                                  child: const Text('SPLIT'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isPlayerTurn && vm.bankroll >= vm.playerBets[vm.activeHandIndex] ? vm.doubleDown : null,
                                  child: const Text('DOUBLE'),
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

              // Round result overlay
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isRoundEnd,
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
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
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('Bank: \$${vm.bankroll}', style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.70))),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: vm.prepareNextRound,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Color _resultColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('win')) return _kAccent;
    if (t.contains('lose')) return Colors.redAccent.shade100;
    return Colors.white;
  }
}

/// Small badge used in top bar
class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final bool subtle;
  const _Badge({required this.label, required this.value, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: subtle ? Color.fromRGBO(0, 0, 0, 0.12) : Color.fromRGBO(0, 0, 0, 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.60), fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Bet chip widget
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
        color: enabled ? _kAccent : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
        boxShadow: enabled ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: Offset(0, 2))] : null,
      ),
      child: Text('\$${amount}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }
}

/// A light wrapper to animate card entry (fade + translate)
class AnimatedCardWrapper extends StatelessWidget {
  final Widget child;
  final bool revealed;
  const AnimatedCardWrapper({required this.child, required this.revealed});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: revealed ? 1 : 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.only(top: revealed ? 0 : 10),
        child: child,
      ),
    );
  }
}

/// Flippable card that uses its own animation controller for clean Y-rotation
class FlippableCard extends StatefulWidget {
  final PlayingCard card;
  final bool faceUp;
  final double width;
  final double height;

  const FlippableCard({
    required this.card,
    required this.faceUp,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<FlippableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // initialize to correct side
    _ctrl.value = widget.faceUp ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant FlippableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.faceUp != widget.faceUp) {
      if (widget.faceUp) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final front = _cardFront(widget.card);
    final back = _cardBack();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          // rotation from pi to 0 for front; show back when t < 0.5
          final angle = (1 - t) * pi;
          final isFrontVisible = t > 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isFrontVisible
                ? front
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: back,
                  ),
          );
        },
      ),
    );
  }

  Widget _cardFront(PlayingCard card) {
    final suitColor = (card.suit == '♥' || card.suit == '♦') ? Color.fromRGBO(183, 28, 28, 1) : Colors.black87;
    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(card.rank, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: suitColor)),
          ),
          Center(child: Text(card.suit, style: TextStyle(fontSize: 36, color: suitColor))),
          Align(
            alignment: Alignment.bottomRight,
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(card.rank, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: suitColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardBack() {
    // simple patterned back, flat and subtle with limited color use
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _kCardBack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Center(
        child: Container(
          width: widget.width * 0.46,
          height: widget.height * 0.7,
          decoration: BoxDecoration(
            color: _kCardBack.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) => Container(height: 6, margin: EdgeInsets.symmetric(horizontal: 6), color: Colors.white10)),
          ),
        ),
      ),
    );
  }
}
