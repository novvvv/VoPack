import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'dart:io';
import 'database/database.dart';

class DetailPageAddWord extends StatefulWidget {
  final int? deckId;
  final VoidCallback? onWordAdded;

  const DetailPageAddWord({
    super.key,
    this.deckId,
    this.onWordAdded,
  });

  @override
  State<DetailPageAddWord> createState() => _DetailPageAddWordState();
}

class _DetailPageAddWordState extends State<DetailPageAddWord> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _meaningController = TextEditingController();
  final _exampleController = TextEditingController();
  final _imagePicker = ImagePicker();
  late AppDatabase _database;
  bool _isSubmitting = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _pronunciationController.dispose();
    _meaningController.dispose();
    _exampleController.dispose();
    _database.close();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }

  Future<void> _addWord() async {
    if (widget.deckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장 정보가 없습니다')),
      );
      return;
    }

    // 현재 단어 개수 확인하여 order 설정
    final currentWordCount = await _database.getWordCountByDeckId(widget.deckId!);
    final newOrder = currentWordCount + 1;

    try {
      await _database.into(_database.words).insert(WordsCompanion.insert(
        deckId: widget.deckId!,
        order: newOrder,
        word: _wordController.text,
        pronunciation: _pronunciationController.text,
        meaning: _meaningController.text,
        image: _selectedImagePath != null ? Value(_selectedImagePath) : const Value.absent(),
        example: _exampleController.text.isNotEmpty 
            ? Value(_exampleController.text) 
            : const Value.absent(),
      ));

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어가 추가되었습니다')),
        );
        
        // 콜백 호출하여 부모 위젯에 새로고침 알림
        widget.onWordAdded?.call();
        
        // 페이지 닫기
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 추가 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildMinimalTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF252525),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 17,
              color: Colors.grey[350],
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF252525), width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF3B30)),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF3B30), width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    '단어 추가',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF252525),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // 단어 입력
                  _buildMinimalTextField(
                    controller: _wordController,
                    label: '단어',
                    hint: '입력',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '단어를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // 발음 입력
                  _buildMinimalTextField(
                    controller: _pronunciationController,
                    label: '발음',
                    hint: '입력',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '발음을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // 뜻 입력
                  _buildMinimalTextField(
                    controller: _meaningController,
                    label: '뜻',
                    hint: '입력',
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '뜻을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  // 예문 입력
                  _buildMinimalTextField(
                    controller: _exampleController,
                    label: '예문',
                    hint: '입력 (선택사항)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  // 이미지 선택
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '이미지',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE5E5E5),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _selectedImagePath != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(
                                              File(_selectedImagePath!),
                                              width: double.infinity,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: _removeImage,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              color: Color(0xFF8E8E93),
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '이미지 선택 (선택사항)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  // 추가 버튼
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() {
                                  _isSubmitting = true;
                                });
                                await _addWord();
                                if (mounted) {
                                  setState(() {
                                    _isSubmitting = false;
                                  });
                                }
                              }
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF252525),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: const Color(0xFFE5E5E5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '추가',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

