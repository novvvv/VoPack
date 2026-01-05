import 'package:flutter/material.dart';
import 'database/database.dart';

class DetailPageSetting extends StatefulWidget {
  final int? deckId;

  const DetailPageSetting({
    super.key,
    this.deckId,
  });

  @override
  State<DetailPageSetting> createState() => _DetailPageSettingState();
}

class _DetailPageSettingState extends State<DetailPageSetting> {
  late AppDatabase _database;
  List<Word> _words = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    if (widget.deckId != null) {
      _loadWords();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWords() async {
    if (widget.deckId == null) return;
    
    try {
      final words = await _database.getWordsByDeckId(widget.deckId!);
      setState(() {
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
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
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer 헤더
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252525),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            // 단어 목록 섹션
            if (widget.deckId != null) ...[
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: const Text(
                  '단어 목록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252525),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _words.isEmpty
                        ? const Center(
                            child: Text(
                              '단어가 없습니다',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _words.length,
                            itemBuilder: (context, index) {
                              final word = _words[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    word.word,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF252525),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        word.pronunciation,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        word.meaning,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF252525),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const Divider(),
            ],
            // 설정 메뉴 항목들
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('덱 추가'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // 프로필 페이지로 이동
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('알림 설정'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // 알림 설정 페이지로 이동
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('언어 설정'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // 언어 설정 페이지로 이동
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('앱 정보'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // 앱 정보 페이지로 이동
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

