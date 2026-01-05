import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // image_picker : 갤러리 이미지 선택
import 'package:drift/drift.dart' show Value; // Value : Db Update 
import 'dart:io'; // File : 파일 경로 이미지 로드 
import 'detail_page_add_word.dart';
import 'detail_page_words_list.dart';
import 'database/database.dart';

// -- Variable -- 
// -- Map<String, dynamic>? cardData : 부모 위젯 (main.dart)로 붙어 받은 초기값 단어장 전체 정보 (불변) --
// --- cardData.image : 이미지 경로 (String)
// -- _currentCarData : State에서 관리하는 로컬 상태 데이터 -- 
class DetailPage extends StatefulWidget {

  final Map<String, dynamic>? cardData; 
  final VoidCallback? onDelete;
  final VoidCallback? onUpdate;

  const DetailPage({
    super.key,
    this.cardData,
    this.onDelete,
    this.onUpdate,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {

  int _currentIndex = 0;
  late AppDatabase _database;
  List<Word> _words = [];
  bool _isLoadingWords = true;

  final _imagePicker = ImagePicker(); // Image Picker Instance 
  Map<String, dynamic>? _currentCardData;
   // Local Image 상태 관리 ... TODO : widget.cardData를 수정하지 않고, 선택한 이미지가 즉시 반영되게 한다? 

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _currentCardData = widget.cardData;
    if (widget.cardData?['id'] != null) {
      _loadWords();
    }
  }

  Future<void> _pickDeckImage() async {
    if (widget.cardData?['id'] == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // 이미지 경로를 데이터베이스에 저장
        await (_database.update(_database.decks)
              ..where((d) => d.id.equals(widget.cardData!['id'])))
            .write(DecksCompanion(image: Value(image.path)));

        // 로컬 상태 업데이트
        setState(() {
          _currentCardData = {
            ..._currentCardData!,
            'image': image.path,
          };
        });

        // 부모 위젯에 업데이트 알림
        widget.onUpdate?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지가 업데이트되었습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadWords() async {
    if (widget.cardData?['id'] == null) return;
    
    try {
      final words = await _database.getWordsByDeckId(widget.cardData!['id']);
      setState(() {
        _words = words;
        _isLoadingWords = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWords = false;
      });
    }
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.onDelete != null && _currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteDialog(context),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDeckDetailView(),
            DetailPageAddWord(
              deckId: widget.cardData?['id'],
              onWordAdded: _loadWords,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFF2F2F2),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF252525),
          unselectedItemColor: const Color(0xFFBDBDBD),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: '단어장',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/add_word.png',
                width: 24,
                height: 24,
                color: _currentIndex == 1 ? const Color(0xFF252525) : const Color(0xFFBDBDBD),
              ),
              label: '단어 추가',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckDetailView() {
    if (_currentCardData == null) {
      return const Center(
        child: Text('단어장 정보가 없습니다'),
      );
    }

    final cardData = _currentCardData!;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // 상세 정보
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardData['title'],
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF252525),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${cardData['wordCount']}단어',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cardData['date'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // 원형 진행률 표시기
                _buildProgressCircle(cardData),
                const SizedBox(width: 20),
                // 단어장 이미지
                GestureDetector(
                  onTap: _pickDeckImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _currentCardData?['image'] != null && 
                             _currentCardData!['image'].toString().isNotEmpty
                          ? (_currentCardData!['image'].toString().startsWith('assets/')
                              ? Image.asset(
                                  _currentCardData!['image'],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildEmptyImageContainer();
                                  },
                                )
                              : Image.file(
                                  File(_currentCardData!['image']),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildEmptyImageContainer();
                                  },
                                ))
                          : _buildEmptyImageContainer(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // 학습 섹션
            _buildLearningSection(cardData),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryStatusRows() {
    final totalWords = _words.length;
    // TODO: 데이터베이스에 암기 상태 필드 추가 후 연결
    final memorizedWords = 0; // 추후 구현
    final unmemorizedWords = totalWords - memorizedWords;

    return Column(
      children: [
        // 미암기 단어
        _buildStatusRow(
          label: '미암기 단어',
          current: unmemorizedWords,
          total: totalWords,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE5E5E5)),
        const SizedBox(height: 16),
        // 암기 단어
        _buildStatusRow(
          label: '암기 단어',
          current: memorizedWords,
          total: totalWords,
        ),
      ],
    );
  }

  Widget _buildProgressCircle(Map<String, dynamic> cardData) {
    final targetCount = cardData['targetCount'] as int? ?? 20;
    final currentCount = cardData['currentCount'] as int? ?? 0;
    final progress = targetCount > 0 ? currentCount / targetCount : 0.0;
    final progressPercent = (progress * 100).toInt();

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          // 배경 원
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF252525)),
            ),
          ),
          // 중앙 텍스트
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252525),
                  ),
                ),
                Text(
                  '$currentCount/$targetCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required int current,
    required int total,
  }) {
    final progress = total > 0 ? current / total : 0.0;

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF252525),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          '$current/$total',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF252525),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          height: 4,
          child: Stack(
            children: [
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212842),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearningSection(Map<String, dynamic> cardData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 자동 학습 1회차 & 기록
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '자동 학습',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252525),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (widget.cardData?['id'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPageWordsList(
                          deckId: widget.cardData!['id'],
                        ),
                      ),
                    );
                  }
                },
                child: const Row(
                  children: [
                    Text(
                      '전체단어',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 암기/미암기 단어 표시
          _buildMemoryStatusRows(),
          const SizedBox(height: 24),
          // 학습하기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 학습 시작 (추후 구현)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF252525),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '학습하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 // 빈 이미지 컨테이너
  Widget _buildEmptyImageContainer() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.add_photo_alternate_outlined,
        color: Color(0xFF8E8E93),
        size: 32,
      ),
    );
  }

  Widget _buildWordCountRow(String label, int count) {
    return GestureDetector(
      onTap: () {
        // 단어 목록으로 이동 (추후 구현)
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF252525),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF252525),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '단어장 삭제',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '삭제하시겠습니까?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pop(); // 상세 페이지 닫기
                widget.onDelete?.call(); // 삭제 콜백 실행
              },
              child: const Text(
                '예',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

