import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'registrator.dart';
import 'bee_game.dart'; 
import 'metamask_connector.dart';

import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT Master Trader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const TerlineTPage(),
    );
  }
}

class TerlineTPage extends StatefulWidget {
  const TerlineTPage({super.key});
  @override
  State<TerlineTPage> createState() => _TerlineTPageState();
}

class _TerlineTPageState extends State<TerlineTPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = "";
  bool _isLoading = false;
  bool _isAgentActive = false;
  bool _showVideo = false;
  bool _hasVideoBeenShown = false; 

  String? _chartSymbol;
  String? _chartInterval;

  // Lista Top 15 integrada para contexto global e inteligência de mercado
  final List<String> _topAssetsContext = [
    "BTC", "ETH", "USDT", "SOL", "BNB", "XRP", "USDC", "DOGE", "ADA", "TRX", "STETH", "SHIB", "AVAX", "DOT", "LINK", "XMR", "PEPE"
  ];

  late AnimationController _murmurationController;
  late AnimationController _swarmController;
  late List<BirdFlock> _flocks;
  late List<BeeParticle> _swarmParticles;

  late AudioPlayer _audioPlayer;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isMuted = false;
  bool _speechEnabled = false;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  final String hfSpaceUrl = 'https://tertulianoshow-terlinet.hf.space';

  @override
  void initState() {
    super.initState();
    _murmurationController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _swarmController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    
    _flocks = List.generate(6, (index) => BirdFlock(index));
    _swarmParticles = List.generate(40, (index) => BeeParticle());
    
    _audioPlayer = AudioPlayer();
    _initSpeech();
    _initVideo();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/Trader.mp4')
      ..initialize().then((_) {
        setState(() => _isVideoInitialized = true);
        _videoController.addListener(() {
          if (_videoController.value.position >= _videoController.value.duration) {
            if (_showVideo) _closeVideo();
          }
        });
      });
  }

  void _closeVideo() {
    setState(() {
      _showVideo = false;
      _hasVideoBeenShown = true; 
      _videoController.pause();
      _videoController.seekTo(Duration.zero);
      _response = "Protocolo de orientação concluído. O Bee Agent está agora sincronizado com as Top 15 do mercado global (XRP, Monero, SOL...). O que deseja analisar?";
    });
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try { _speechEnabled = await _speech.initialize(); } catch (e) { debugPrint('Erro STT: $e'); }
    setState(() {});
  }

  @override
  void dispose() {
    _murmurationController.dispose();
    _swarmController.dispose();
    _controller.dispose();
    _audioPlayer.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_isAgentActive) return;
    if (!_speechEnabled) await _initSpeech();
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() { 
            _controller.text = result.recognizedWords; 
            if (result.finalResult) { _isListening = false; _sendQuery(); } 
          });
        }, localeId: "pt_BR");
      }
    } else { setState(() => _isListening = false); _speech.stop(); }
  }

  Future<void> _sendQuery() async {
    if (!_isAgentActive) return;
    final String userText = _controller.text;
    if (userText.isEmpty) return;
    
    _controller.clear();
    setState(() { 
      _isLoading = true; 
      _response = "O Bee está convocando o enxame para análise tática global..."; 
    });

    try {
      final response = await http.post(
        Uri.parse('$hfSpaceUrl/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': userText, 
          'is_agent': true, 
          'consult_terlinet': true,
          'market_analysis': true,
          'priority_watchlist': _topAssetsContext, // Envia as Top 15 para o backend
          'real_time_sync': true
        }),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _response = data['text'] ?? "";
          _chartSymbol = data['chart_symbol'];
          _chartInterval = data['interval'] ?? "60";
          if (_chartSymbol != null && kIsWeb) {
            final String viewID = "tv-chart-${DateTime.now().millisecondsSinceEpoch}";
            final List<Map<String, String>> studiesList = [
              {"symbol": _chartSymbol!, "id": "SuperTrend@tv-basicstudies"},
              {"symbol": _chartSymbol!, "id": "PivotPointsStandard@tv-basicstudies"}
            ];
            final String indicators = jsonEncode(studiesList);
            final String url = "https://s.tradingview.com/widgetembed/?symbol=$_chartSymbol&interval=$_chartInterval&theme=dark&style=1&studies=${Uri.encodeComponent(indicators)}&hide_side_toolbar=1&details=true&withdateranges=true&show_popup_button=true&locale=pt_BR";
            registerChartWeb(viewID, url);
            _chartInterval = viewID;
          }
          if (data['audio'] != null) { _playVoice(data['audio']); }
        });
      }
    } catch (e) { setState(() => _response = "Conexão interrompida."); } 
    finally { setState(() => _isLoading = false); }
  }

  Future<void> _playVoice(String base64Audio) async {
    if (_isMuted) return;
    try {
      final Uint8List audioBytes = base64Decode(base64Audio);
      await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));
      _audioPlayer.play();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/trader.jpg'), fit: BoxFit.cover))),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: Stack(
              children: [
                Positioned(top: 15, left: 20, child: _buildHeader()),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_showVideo && _isVideoInitialized) _buildHolographicVideo(),
                        const SizedBox(height: 20),
                        VirtualBeeAgent(
                          isActive: _isAgentActive,
                          onTap: () {
                            if (_showVideo) {
                              _closeVideo(); 
                              setState(() => _isAgentActive = true);
                            } else if (_isLoading) {
                              setState(() {
                                _isLoading = false;
                                _response = "Análise interrompida. O que deseja saber?";
                              });
                            } else {
                              setState(() {
                                _isAgentActive = !_isAgentActive;
                                if (_isAgentActive) {
                                  if (!_hasVideoBeenShown) {
                                    _showVideo = true;
                                    _videoController.play();
                                  } else {
                                    _response = "Bee Agent Conectado. Sincronizado com Top 15 e tendências globais.";
                                  }
                                } else {
                                  _showVideo = false;
                                  _videoController.pause();
                                  _audioPlayer.stop();
                                  _response = "";
                                  _chartSymbol = null;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 30),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 800),
                          opacity: _isAgentActive ? 1.0 : 0.0,
                          child: _isAgentActive ? Column(
                            children: [
                              _buildChatInput(),
                              const SizedBox(height: 30),
                              _buildResponseArea(),
                            ],
                          ) : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isLoading) IgnorePointer(child: _buildSwarmOverlay()),
                if (_chartSymbol != null) _buildChartOverlay(),
              ],
            ),
          ),
          Positioned(bottom: 20, left: 0, right: 0, child: _buildFooter()),
        ],
      ),
    );
  }

  Widget _buildHolographicVideo() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: (MediaQuery.of(context).size.width * 0.85) * 9 / 16,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 25)]
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController)),
          ),
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              onTap: _closeVideo,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() { 
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 24), 
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 15)]
      ), 
      child: TextField(
        controller: _controller, 
        style: const TextStyle(color: Colors.white, fontSize: 18), 
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'CONSULTAR QUALQUER ATIVO (XRP, XMR, SOL...)',
          hintStyle: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 14), 
          border: InputBorder.none, 
          prefixIcon: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white), onPressed: _listen),
          suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.redAccent), onPressed: () => _sendQuery()),
        ), 
        onSubmitted: (_) => _sendQuery()
      )
    ); 
  }

  Widget _buildResponseArea() { 
    if (_response.isEmpty) return const SizedBox.shrink(); 
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))), 
      child: SelectableText(_response, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5))
    ); 
  }

  Widget _buildHeader() { 
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedBuilder(
          animation: _murmurationController, 
          builder: (context, child) => CustomPaint(
            painter: MurmurationPainter(_flocks, _murmurationController.value), 
            size: const Size(260, 60)
          )
        ), 
        const Padding(
          padding: EdgeInsets.only(left: 60.0), 
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text('T', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w100)), 
              SizedBox(width: 6), 
              Text('E R L I N E', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w200, letterSpacing: 4)), 
              SizedBox(width: 6), 
              Text('T', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w100))
            ]
          ),
        )
      ]
    ); 
  }

  Widget _buildSwarmOverlay() {
    return AnimatedBuilder(
      animation: _swarmController,
      builder: (context, child) => CustomPaint(painter: SwarmPainter(_swarmParticles, _swarmController.value, _isAgentActive, _isLoading), size: Size.infinite),
    );
  }

  Widget _buildChartOverlay() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.redAccent, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Padding(padding: EdgeInsets.all(12.0), child: Text("BEE TERMINAL ANALYSIS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _chartSymbol = null))]),
            Expanded(child: HtmlElementView(viewType: _chartInterval!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() { return const Center(child: Text('TerlineT • Master Trader Intelligence 2024', style: TextStyle(color: Colors.white24, fontSize: 9))); }
}

class MyCustomSource extends StreamAudioSource {
  final Uint8List bytes;
  MyCustomSource(this.bytes);
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0; end ??= bytes.length;
    return StreamAudioResponse(sourceLength: bytes.length, contentLength: end - start, offset: start, stream: Stream.value(bytes.sublist(start, end)), contentType: 'audio/mpeg');
  }
}

class BeeParticle {
  late double startSide, startY, orbitRadiusX, orbitRadiusY, speed, phase, scaleBase, noiseOffset, arrivalDelay;
  BeeParticle() {
    final rand = math.Random();
    startSide = rand.nextBool() ? 0 : 1;
    startY = rand.nextDouble();
    orbitRadiusX = 80 + rand.nextDouble() * 100;
    orbitRadiusY = 40 + rand.nextDouble() * 60;
    speed = 0.6 + rand.nextDouble() * 1.2;
    phase = rand.nextDouble() * 2 * math.pi;
    scaleBase = 0.25 + rand.nextDouble() * 0.3;
    noiseOffset = rand.nextDouble() * 1000;
    arrivalDelay = rand.nextDouble();
  }
}

class SwarmPainter extends CustomPainter {
  final List<BeeParticle> particles;
  final double value;
  final bool isAgent;
  final bool isLoading;
  SwarmPainter(this.particles, this.value, this.isAgent, this.isLoading);
  @override
  void paint(Canvas canvas, Size size) {
    final beeCenter = Offset(size.width / 2, size.height / 2 - 40);
    final sortedEntries = particles.map((p) {
      final multiplier = isLoading ? 2.5 : 1.0;
      final angle = (value * 2 * math.pi * p.speed * multiplier) + p.phase;
      final z = math.sin(angle);
      return MapEntry(p, z);
    }).toList();
    sortedEntries.sort((a, b) => a.value.compareTo(b.value));
    for (var entry in sortedEntries) {
      final p = entry.key;
      final z = entry.value;
      final multiplier = isLoading ? 2.5 : 1.0;
      final angle = (value * 2 * math.pi * p.speed * multiplier) + p.phase;
      final startX = p.startSide == 0 ? -120.0 : size.width + 120.0;
      final startY = p.startY * size.height;
      final startPos = Offset(startX, startY);
      final noiseX = math.sin(value * 20 + p.noiseOffset) * 6;
      final noiseY = math.cos(value * 15 + p.noiseOffset) * 6;
      final orbitPos = beeCenter + Offset(math.cos(angle) * p.orbitRadiusX + noiseX, math.sin(angle) * p.orbitRadiusY + noiseY);
      double individualValue = (value + p.arrivalDelay) % 1.0;
      double entryProgress = (individualValue * 2.5).clamp(0.0, 1.0);
      final currentPos = Offset.lerp(startPos, orbitPos, entryProgress)!;
      final scale = p.scaleBase * (1.2 + z * 0.4);
      final finalOpacity = (0.3 + (z + 1) / 2 * 0.7).clamp(0.1, 1.0);
      _drawMiniBee(canvas, currentPos, scale, isAgent, angle, finalOpacity, z);
    }
  }
  void _drawMiniBee(Canvas canvas, Offset center, double scale, bool isActive, double angle, double opacity, double z) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi/2 + (z * 0.2));
    canvas.scale(scale);
    final baseColor = isActive ? Colors.redAccent : Colors.yellowAccent;
    final secondaryColor = isActive ? Colors.red.shade900 : Colors.orange.shade800;
    final wingFlap = math.sin(value * 80 + angle) * 0.6;
    final wingPaint = Paint()..color = (isActive ? Colors.redAccent : Colors.white).withOpacity(0.4 * opacity)..style = PaintingStyle.fill;
    canvas.save(); canvas.rotate(wingFlap - 0.4); canvas.drawOval(Rect.fromLTWH(-15, -10, 15, 8), wingPaint); canvas.restore();
    canvas.save(); canvas.rotate(-wingFlap + 0.4); canvas.drawOval(Rect.fromLTWH(0, -10, 15, 8), wingPaint); canvas.restore();
    final brightness = (z + 1) / 2;
    final bodyPaint = Paint()..shader = ui.Gradient.radial(Offset.zero, 12, [Color.lerp(Colors.black, baseColor, 0.5 + brightness * 0.5)!, Color.lerp(Colors.black, secondaryColor, 0.3 + brightness * 0.7)!, Colors.black], const [0.2, 0.8, 1.0]);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 18), bodyPaint);
    final stripePaint = Paint()..color = Colors.black.withOpacity(0.8 * opacity)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: 24, height: 18), 0.5, 2.2, false, stripePaint);
    canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: 24, height: 18), 3.5, 2.2, false, stripePaint);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant SwarmPainter oldDelegate) => true;
}

class VirtualBeeAgent extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  const VirtualBeeAgent({super.key, required this.onTap, this.isActive = false});
  @override State<VirtualBeeAgent> createState() => _VirtualBeeAgentState();
}

class _VirtualBeeAgentState extends State<VirtualBeeAgent> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _wingController;
  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _wingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat(reverse: true);
  }
  @override
  void dispose() { _hoverController.dispose(); _wingController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _hoverController,
        builder: (context, child) {
          final t = _hoverController.value * 2 * math.pi;
          return Transform.translate(
            offset: Offset(math.sin(t) * 15, math.sin(2 * t) * 10),
            child: SizedBox(width: 130, height: 130, child: CustomPaint(painter: BeePainter(wingValue: _wingController.value, isActive: widget.isActive))),
          );
        },
      ),
    );
  }
}

class BeePainter extends CustomPainter {
  final double wingValue;
  final bool isActive;
  BeePainter({required this.wingValue, this.isActive = false});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final wingPaint = Paint()..color = (isActive ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.3)..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    void drawWing(double angle, bool left) {
      canvas.save(); canvas.translate(center.dx, center.dy - 5); canvas.rotate(angle + (left ? -wingValue * 0.6 : wingValue * 0.6));
      canvas.drawOval(Rect.fromCenter(center: Offset(left ? -25 : 25, -15), width: 40, height: 15), wingPaint);
      canvas.restore();
    }
    drawWing(-0.5, true); drawWing(0.5, false);
    final bodyPaint = Paint()..shader = ui.Gradient.radial(center, 25, [isActive ? Colors.redAccent : Colors.yellowAccent, isActive ? Colors.red.shade900 : Colors.orange.shade700, Colors.black], const [0.2, 0.7, 1.0]);
    if (isActive) { canvas.drawCircle(center, 25, Paint()..color = Colors.redAccent.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)); }
    canvas.drawOval(Rect.fromCenter(center: center, width: 55, height: 45), bodyPaint);
    final stripePaint = Paint()..color = Colors.black.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: center, width: 55, height: 45), 0.5, 2.0, false, stripePaint);
    canvas.drawArc(Rect.fromCenter(center: center, width: 55, height: 45), 3.5, 2.0, false, stripePaint);
    final sensorPaint = Paint()..color = isActive ? Colors.redAccent : Colors.cyanAccent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(center.dx + 15, center.dy - 6), 6, Paint()..color = Colors.black); 
    canvas.drawCircle(Offset(center.dx + 16, center.dy - 6), 2, sensorPaint); 
    final antPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final path = Path(); path.moveTo(center.dx + 8, center.dy - 18); path.quadraticBezierTo(center.dx + 18, center.dy - 32, center.dx + 26, center.dy - 26);
    canvas.drawPath(path, antPaint); canvas.drawCircle(Offset(center.dx + 26, center.dy - 26), 2, sensorPaint);
  }
  @override bool shouldRepaint(BeePainter oldDelegate) => true;
}

class BirdFlock { final int id; BirdFlock(this.id); }
class MurmurationPainter extends CustomPainter {
  final List<BirdFlock> flocks; final double animationValue;
  MurmurationPainter(this.flocks, this.animationValue);
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double t = DateTime.now().millisecondsSinceEpoch / 2500.0; 
    for (int i = 0; i < 50; i++) {
      final pos = center + Offset(math.sin(t + i * 0.4) * 110, math.cos(t * 0.4 + i * 0.6) * 40);
      canvas.drawCircle(pos, 1.2, Paint()..color = Colors.white.withOpacity(0.25 + (math.sin(t + i).abs() * 0.3)));
    }
  }
  @override bool shouldRepaint(covariant MurmurationPainter oldDelegate) => true;
}
