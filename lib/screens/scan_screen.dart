import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/receipt_parse_result.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/document_scan_service.dart';
import '../services/expense_service.dart';
import '../services/receipt_parser_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();
  final ImagePicker _imagePicker = ImagePicker();
  final ReceiptParserService _receiptParserService = ReceiptParserService();
  final DocumentScanService _documentScanService = DocumentScanService();
  final _shopController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController(
    text: AppFormat.date(DateTime.now()),
  );

  CameraController? _cameraController;
  XFile? _selectedImage;
  List<Category> _categories = Category.all;
  Category _selectedCategory = Category.all.first;
  ReceiptParseResult? _parseResult;
  bool _initializingCamera = true;
  bool _loadingCategories = true;
  bool _processing = false;
  bool _saving = false;
  String? _cameraError;
  String? _analysisMessage;

  bool get _usesSmartScan => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_usesSmartScan) {
      _initializingCamera = false;
    } else {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _shopController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.fetchCategories();
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories.isNotEmpty ? categories : Category.all;
        _selectedCategory = _categories.first;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = Category.all;
        _selectedCategory = _categories.first;
        _loadingCategories = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _cameraError = 'Keine Kamera auf diesem Gerät verfügbar.';
          _initializingCamera = false;
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializingCamera = false;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cameraError = exception.toString();
        _initializingCamera = false;
      });
    }
  }

  Future<void> _startSmartScan() async {
    try {
      final path = await _documentScanService.scanSinglePage();
      if (path != null) {
        await _processImage(XFile(path));
      }
    } catch (exception) {
      _showMessage('Smart-Scan fehlgeschlagen: $exception');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      await _processImage(image);
    } catch (exception) {
      _showMessage('Fotoaufnahme fehlgeschlagen: $exception');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image != null) {
        await _processImage(image);
      }
    } catch (exception) {
      _showMessage('Bildauswahl fehlgeschlagen: $exception');
    }
  }

  Future<void> _processImage(XFile image) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _selectedImage = image;
      _parseResult = null;
      _analysisMessage = 'Lokale OCR läuft...';
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(inputImage);
      final localResult = _receiptParserService.parse(recognized);
      var finalResult = localResult;
      var analysisMessage = 'Lokal mit ML Kit erkannt.';

      if (localResult.shouldUseAiFallback) {
        try {
          finalResult = await _enhanceWithAi(localResult, image.path);
          analysisMessage = finalResult.usedAi
              ? 'Mit Gemini verbessert.'
              : 'Lokale OCR verwendet. Bitte Felder prüfen.';
        } on ApiException {
          analysisMessage =
              'Lokale OCR verwendet. KI-Fallback ist auf dem Server nicht verfügbar.';
        } catch (_) {
          analysisMessage =
              'Lokale OCR verwendet. KI konnte diesen Beleg nicht weiter verbessern.';
        }
      }

      if (!mounted) {
        return;
      }

      _applyParseResultToControllers(finalResult);

      setState(() {
        _parseResult = finalResult;
        _analysisMessage = analysisMessage;
      });
    } catch (exception) {
      _showMessage('OCR fehlgeschlagen: $exception');
    } finally {
      await recognizer.close();
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<ReceiptParseResult> _enhanceWithAi(
    ReceiptParseResult localResult,
    String imagePath,
  ) async {
    final response = await _expenseService.parseReceiptWithAi(
      imagePath: imagePath,
      ocrText: localResult.ocrText,
    );

    final aiResult = ReceiptParseResult.fromAiResponse(
      response,
      fallbackOcrText: localResult.ocrText,
    );

    return _mergeResults(localResult, aiResult);
  }

  ReceiptParseResult _mergeResults(
    ReceiptParseResult localResult,
    ReceiptParseResult aiResult,
  ) {
    final useAiShop = aiResult.shopName != null &&
        (localResult.shopName == null ||
            localResult.shopConfidence < 0.60 ||
            aiResult.shopConfidence > localResult.shopConfidence + 0.10);

    final useAiAmount = aiResult.amount != null &&
        (localResult.amount == null ||
            localResult.amountConfidence < 0.82 ||
            aiResult.amountConfidence > localResult.amountConfidence + 0.08);

    final useAiDate = aiResult.date != null &&
        (localResult.date == null ||
            localResult.dateConfidence < 0.75 ||
            aiResult.dateConfidence > localResult.dateConfidence + 0.08);

    final usedAi = useAiShop || useAiAmount || useAiDate;

    return ReceiptParseResult(
      shopName: useAiShop ? aiResult.shopName : localResult.shopName,
      amount: useAiAmount ? aiResult.amount : localResult.amount,
      date: useAiDate ? aiResult.date : localResult.date,
      ocrText: localResult.ocrText,
      shopConfidence: useAiShop
          ? aiResult.shopConfidence
          : localResult.shopConfidence,
      amountConfidence: useAiAmount
          ? aiResult.amountConfidence
          : localResult.amountConfidence,
      dateConfidence: useAiDate
          ? aiResult.dateConfidence
          : localResult.dateConfidence,
      usedAi: usedAi,
      source: usedAi ? 'mlkit+gemini' : localResult.source,
      notes: aiResult.notes ?? localResult.notes,
    );
  }

  void _applyParseResultToControllers(ReceiptParseResult result) {
    _shopController.text = result.shopName ?? '';
    _amountController.text = result.amount != null
        ? AppFormat.amount(result.amount!)
        : '';
    _dateController.text = result.date != null
        ? AppFormat.displayDate(result.date)
        : AppFormat.date(DateTime.now());
  }

  Future<void> _improveWithAiManually() async {
    final image = _selectedImage;
    final parseResult = _parseResult;
    if (image == null || parseResult == null) {
      return;
    }

    setState(() {
      _processing = true;
      _analysisMessage = 'Gemini verbessert den Beleg...';
    });

    try {
      final improved = await _enhanceWithAi(parseResult, image.path);
      if (!mounted) {
        return;
      }

      _applyParseResultToControllers(improved);
      setState(() {
        _parseResult = improved;
        _analysisMessage = improved.usedAi
            ? 'Mit Gemini verbessert.'
            : 'Gemini konnte die Felder nicht weiter verbessern.';
      });
    } on ApiException catch (exception) {
      _showMessage(exception.message);
    } catch (exception) {
      _showMessage('KI-Optimierung fehlgeschlagen: $exception');
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = AppFormat.parseDate(_dateController.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );

    if (selected != null) {
      _dateController.text = AppFormat.date(selected);
    }
  }

  Future<bool> _confirmDuplicateSave(ApiException exception) async {
    final duplicate = exception.payload['duplicate'];
    final duplicateExpense = duplicate is Map<String, dynamic>
        ? Expense.fromJson(duplicate)
        : null;

    final content = duplicateExpense == null
        ? 'Es gibt bereits eine ähnliche Ausgabe. Möchtest du trotzdem speichern?'
        : 'Es gibt bereits „${duplicateExpense.shopName}“ am '
            '${AppFormat.displayDate(duplicateExpense.date)} mit '
            '${AppFormat.currency(duplicateExpense.amount)}. Trotzdem speichern?';

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mögliche Dublette'),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Trotzdem speichern'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submit({bool force = false}) async {
    final image = _selectedImage;
    final amount = AppFormat.parseAmount(_amountController.text);
    final shopName = _shopController.text.trim().isEmpty
        ? 'Unbekanntes Geschäft'
        : _shopController.text.trim();
    final ocrText = _parseResult?.ocrText.trim() ?? '';

    if (image == null) {
      _showMessage('Bitte erst einen Beleg aufnehmen oder auswählen.');
      return;
    }

    if (amount == null || amount <= 0) {
      _showMessage('Bitte einen gültigen Betrag eingeben.');
      return;
    }

    if (AppFormat.parseDate(_dateController.text.trim()) == null) {
      _showMessage('Bitte ein gültiges Datum auswählen.');
      return;
    }

    if (ocrText.isEmpty) {
      _showMessage('Der OCR-Text ist leer. Bitte erneut scannen.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _expenseService.addScannedExpense(
        amount: amount,
        shopName: shopName,
        date: _dateController.text.trim(),
        categoryId: _selectedCategory.id,
        ocrText: ocrText,
        imagePath: image.path,
        force: force,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Beleg wurde gespeichert.');
      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      if (!force && exception.isDuplicateExpense) {
        final continueSave = await _confirmDuplicateSave(exception);
        if (continueSave) {
          if (mounted) {
            setState(() {
              _saving = false;
            });
          }
          return _submit(force: true);
        }
      }

      _showMessage(exception.message);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _resetSelectedImage() {
    setState(() {
      _selectedImage = null;
      _parseResult = null;
      _analysisMessage = null;
      _shopController.clear();
      _amountController.clear();
      _dateController.text = AppFormat.date(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandAppBarTitle('Beleg scannen')),
      body: SafeArea(
        child: _loadingCategories
            ? const Center(child: CircularProgressIndicator())
            : _selectedImage == null
                ? _buildCaptureStage()
                : _buildReviewStage(),
      ),
    );
  }

  Widget _buildCaptureStage() {
    if (_usesSmartScan) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Color(0xFF2563EB),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Smart-Scan für Belege',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Auf Android wird der Google-Dokumentenscanner genutzt. Damit werden schiefe, zerknitterte oder dunkle Belegfotos vor der OCR deutlich besser vorbereitet.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _processing ? null : _startSmartScan,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Smart-Scan starten'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _processing ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Aus Galerie importieren'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _initializingCamera
                  ? const Center(child: CircularProgressIndicator())
                  : _cameraController != null &&
                          _cameraController!.value.isInitialized
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            if (_processing)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: const Color(0xFFF8FAFC),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _cameraError ?? 'Kamera ist nicht verfügbar.',
                            textAlign: TextAlign.center,
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galerie'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Aufnehmen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStage() {
    final parseResult = _parseResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _resetSelectedImage,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Neu aufnehmen'),
              ),
              OutlinedButton.icon(
                onPressed: _saving || _processing ? null : _improveWithAiManually,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Mit KI verbessern'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (parseResult != null || _analysisMessage != null)
            _buildAnalysisCard(parseResult),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Erkannte Felder prüfen',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _shopController,
                    decoration: const InputDecoration(
                      labelText: 'Geschäft',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Betrag',
                      prefixIcon: Icon(Icons.euro_rounded),
                      hintText: 'z. B. 6,50',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Datum',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<Category>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategorie',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(category.iconData, color: category.color),
                                const SizedBox(width: 10),
                                Text(category.localizedName),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'OCR-Text',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SelectableText(
                      parseResult == null || parseResult.ocrText.isEmpty
                          ? 'Noch kein OCR-Text vorhanden.'
                          : parseResult.ocrText,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving || _processing ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Beleg speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(ReceiptParseResult? parseResult) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Text(
                parseResult?.sourceLabel ?? 'Beleg wird analysiert',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (_analysisMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _analysisMessage!,
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ],
          if (parseResult?.notes != null && parseResult!.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              parseResult.notes!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}


