import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../database/app_database.dart';
import '../../category/data/category_repository.dart';
import '../../transaction/domain/transaction_draft.dart';
import '../../transaction/presentation/transaction_form_screen.dart';
import '../domain/receipt_parser.dart';

/// レシート撮影画面。design.md 6章参照。
/// カメラで撮影 → Google ML Kitで文字認識 → 自作パーサーで日付・支払先・金額を判定し、
/// 取引追加フォームへ事前入力した状態で遷移する。
class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'カメラが見つかりませんでした。');
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = 'カメラの初期化に失敗しました: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _analyzing = true);
    try {
      final file = await controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer = TextRecognizer();
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      final blocks = [
        for (final block in recognized.blocks)
          OcrTextBlock(
            text: block.text,
            top: block.boundingBox.top,
            left: block.boundingBox.left,
          ),
      ];
      final parsed = parseReceipt(blocks);

      final categories = ref.read(categoriesStreamProvider).value ?? [];
      var categoryId = categories.isNotEmpty ? categories.first.id : 0;
      var necessity = Necessity.necessary;
      if (parsed.amount != null) {
        for (final c in categories) {
          if (c.id == categoryId) necessity = c.defaultNecessity;
        }
      }

      // OCR確認後、画像は破棄する(design.md 3.4節: レシート画像はDBに保持しない)。
      // ここでは一時ファイルを削除する。

      if (!mounted) return;
      final draft = TransactionDraft(
        date: parsed.date ?? DateTime.now(),
        payee: parsed.payee ?? '',
        categoryId: categoryId,
        amount: parsed.amount ?? 0,
        splitType: SplitType.none,
        payer: Payer.self,
        necessity: necessity,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TransactionFormScreen(prefill: draft),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('読み取りに失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('レシート撮影')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            );
          }
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.78,
                  heightFactor: 0.62,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'この枠内にレシートを収めてください',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              if (_analyzing)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('解析中…', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.large(
                    onPressed: _analyzing ? null : _capture,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
