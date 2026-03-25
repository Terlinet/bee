import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class BeeGame extends StatefulWidget {
  const BeeGame({super.key});

  @override
  State<BeeGame> createState() => _BeeGameState();
}

class _BeeGameState extends State<BeeGame> with TickerProviderStateMixin {
  bool isGameStarted = false;
  bool isGameOver = false;
  double score = 0;
  double playerX = 50;
  double playerY = 150;
  double velocityY = 0;
  double velocityX = 0;
  double wingValue = 0;
  
  static const double gravity = 0.3;
  static const double jumpForce = -6.0;
  static const double moveSpeed = 3.0;
  static const double playerSize = 30.0;
  
  List<Offset> coins = [];
  List<Enemy> enemies = [];
  double groundY = 0;
  double cameraX = 0;
  
  late AnimationController _wingController;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _wingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat(reverse: true);
    
    _wingController.addListener(() {
      setState(() {
        wingValue = _wingController.value;
      });
    });
  }

  void startGame() {
    setState(() {
      isGameStarted = true;
      isGameOver = false;
      score = 0;
      playerX = 50;
      playerY = 150;
      velocityY = 0;
      velocityX = 0;
      cameraX = 0;
      _generateLevel();
    });
    
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _update();
    });
  }

  void _generateLevel() {
    coins = List.generate(30, (i) => Offset(300.0 + i * 200, 50.0 + math.Random().nextDouble() * 200));
    enemies = List.generate(15, (i) => Enemy(
      x: 500.0 + i * 400,
      y: 50.0 + math.Random().nextDouble() * 250,
      type: math.Random().nextBool() ? "bird" : "spider"
    ));
  }

  void _update() {
    if (!isGameStarted || isGameOver) return;

    setState(() {
      velocityY += gravity * 0.5;
      playerY += velocityY;
      playerX += velocityX;

      if (playerY < 0) {
        playerY = 0;
        velocityY = 0;
      }
      if (playerY > groundY - playerSize) {
        _gameOver();
      }

      cameraX = playerX - 50;

      coins.removeWhere((coin) {
        if ((Offset(playerX, playerY) - coin).distance < 40) {
          score += 10;
          return true;
        }
        return false;
      });

      for (var enemy in enemies) {
        if ((Offset(playerX, playerY) - Offset(enemy.x, enemy.y)).distance < 35) {
          _gameOver();
        }
        enemy.x -= 1.0;
      }
      
      velocityX = moveSpeed;
    });
  }

  void _jump() {
    if (!isGameStarted) return;
    setState(() {
      velocityY = jumpForce;
    });
  }

  void _gameOver() {
    _gameTimer?.cancel();
    setState(() {
      isGameOver = true;
    });
  }

  @override
  void dispose() {
    _wingController.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          groundY = constraints.maxHeight;
          return GestureDetector(
            onTapDown: (_) {
              if (!isGameStarted || isGameOver) {
                startGame();
              } else {
                _jump();
              }
            },
            child: Stack(
              children: [
                Transform.translate(
                  offset: Offset(-cameraX, 0),
                  child: Stack(
                    children: [
                      ...coins.map((c) => Positioned(
                        left: c.dx,
                        top: c.dy,
                        child: const Text("🫧", style: TextStyle(fontSize: 20)),
                      )),
                      ...enemies.map((e) => Positioned(
                        left: e.x,
                        top: e.y,
                        child: Text(e.type == "bird" ? "🦅" : "🕷️", style: const TextStyle(fontSize: 30)),
                      )),
                      Positioned(
                        left: playerX,
                        top: playerY,
                        child: SizedBox(
                          width: playerSize,
                          height: playerSize,
                          child: CustomPaint(
                            painter: BeeGamePainter(wingValue: wingValue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Text("BEE SCORE: ${score.toInt()}", style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (!isGameStarted) _buildMenu("BEE ADVENTURE", "TAP TO START"),
                if (isGameOver) _buildMenu("OFFLINE", "SCORE: ${score.toInt()}\nTAP TO RESTART"),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildMenu(String title, String subtitle) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class Enemy {
  double x, y;
  String type;
  Enemy({required this.x, required this.y, required this.type});
}

class BeeGamePainter extends CustomPainter {
  final double wingValue;
  BeeGamePainter({required this.wingValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final wingPaint = Paint()..color = Colors.cyanAccent.withOpacity(0.4)..style = PaintingStyle.fill;
      
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(wingValue * 0.4);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-10, -8), width: 18, height: 8), wingPaint);
    canvas.restore();
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-wingValue * 0.4);
    canvas.drawOval(Rect.fromCenter(center: const Offset(10, -8), width: 18, height: 8), wingPaint);
    canvas.restore();

    final bodyPaint = Paint()..color = Colors.amber..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (math.pi / 3) * i;
      double x = center.dx + 12 * math.cos(angle);
      double y = center.dy + 10 * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, bodyPaint);
    
    final stripePaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, stripePaint);
    canvas.drawCircle(center + const Offset(6, -2), 2, Paint()..color = Colors.black);
  }

  @override bool shouldRepaint(BeeGamePainter oldDelegate) => true;
}
