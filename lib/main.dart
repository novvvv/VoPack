import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'detail_page.dart';
import 'detail_page_setting.dart';
import 'database/database.dart' show AppDatabase, Deck, DecksCompanion;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vopet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late PageController _pageController;
  int _currentPage = 2; // 실제 첫 페이지는 인덱스 2
  int _previousPage = 2; // 이전 페이지 추적
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AppDatabase _database; // DB 인스턴스
  bool _isLoading = true; // 데이터 로딩 상태 플래그 

  // 카드 데이터 (DB에서 로드)
  List<Map<String, dynamic>> _cards = [
    {
      'isAddCard': true, // 덱 추가 카드 표시 TODO: 이게 먼데
    },
  ];

  List<Map<String, dynamic>> get _extendedCards {
    // 덱 추가 카드를 제외한 실제 카드들
    final actualCards = _cards.where((card) => card['isAddCard'] != true).toList();
    final addCard = _cards.firstWhere(
      (card) => card['isAddCard'] == true,
      orElse: () => {'isAddCard': true},
    );
    
    // 실제 카드가 없는 경우
    if (actualCards.isEmpty) {
      return [addCard];
    }
    
    // 구조: [마지막카드복제] [덱추가] [N5] [N4] [N3] [N2] [N1] [덱추가] [첫카드복제]
    // 인덱스:      0          1      2    3    4    5    6     7        8
    return [
      actualCards.last, // 마지막 실제 카드 복제본 (무한 루프용, 인덱스 0)
      addCard, // 덱 추가 카드 (왼쪽, 인덱스 1)
      ...actualCards, // 원본 실제 카드들 (인덱스 2~6)
      addCard, // 덱 추가 카드 (오른쪽, 인덱스 7)
      actualCards.first, // 첫 번째 실제 카드 복제본 (무한 루프용, 인덱스 8)
    ];
  }

  int get _realPageIndex {
    final actualCardsCount = _actualCardsCount;
    
    // 실제 카드가 없는 경우
    if (actualCardsCount == 0) {
      return -1;
    }
    
    // 실제 페이지 인덱스 계산
    // 덱 추가 카드 (인덱스 1 또는 actualCardsCount + 2)
    if (_currentPage == 1 || _currentPage == actualCardsCount + 2) {
      return -1; // 덱 추가 카드는 인디케이터에 표시하지 않음
    } else if (_currentPage >= 2 && _currentPage <= actualCardsCount + 1) {
      return _currentPage - 2; // 실제 카드들 (인덱스 2~6 → 0~4)
    }
    return 0;
  }
  
  int get _actualCardsCount {
    // 덱 추가 카드를 제외한 실제 카드 개수
    return _cards.where((card) => card['isAddCard'] != true).length;
  }

  @override
  void initState() {
    super.initState();

    _database = AppDatabase();
    _loadDecks();
    
    // 첫 번째 실제 카드는 인덱스 2 (복제=0, 덱추가=1, 첫 실제 카드=2)
    _pageController = PageController(initialPage: 2);
    _currentPage = 2; // 첫 번째 실제 페이지로 시작
    _previousPage = 2; // 이전 페이지 초기화
  }

  Future<void> _loadDecks() async {
    try {
      debugPrint('DB 데이터 로드 시작...');
      final decks = await _database.select(_database.decks).get();
      debugPrint('조회된 덱 수: ${decks.length}');
      
      // 데이터가 없으면 초기 데이터 삽입
      if (decks.isEmpty) {
        debugPrint('초기 데이터 삽입 중...');
        await _database.into(_database.decks).insert(DecksCompanion.insert(
          image: const Value(''),
          date: '2025.01.03',
          title: 'N5',
        ));
        debugPrint('N5 삽입 완료');
        
        await _database.into(_database.decks).insert(DecksCompanion.insert(
          image: const Value('assets/mikote.jpg'),
          date: '2025.01.04',
          title: 'N4',
        ));
        debugPrint('N4 삽입 완료');
        
        // 다시 조회
        final newDecks = await _database.select(_database.decks).get();
        debugPrint('삽입 후 덱 수: ${newDecks.length}');
        await _updateCards(newDecks);
      } else {
        debugPrint('기존 데이터 사용: ${decks.length}개');
        await _updateCards(decks);
      }
    } catch (e, stackTrace) {
      debugPrint('DB 에러: $e');
      debugPrint('스택트레이스: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCards(List<Deck> decks) async {
    // 각 덱의 단어 개수를 가져와서 카드 데이터 구성
    final cardsData = await Future.wait(decks.map((deck) async {
      final wordCount = await _database.getWordCountByDeckId(deck.id);
      return {
        'id': deck.id,
        'image': deck.image ?? '',
        'wordCount': wordCount.toString(),
        'date': deck.date,
        'title': deck.title,
        'targetCount': deck.targetCount,
        'currentCount': deck.currentCount,
      };
    }));

    setState(() {
      _cards = [
        ...cardsData,
        {'isAddCard': true}, // 덱 추가 카드
      ];
      _isLoading = false;
      
      // 데이터 로드 후 페이지 조정
      final actualCardsCount = _cards.where((card) => card['isAddCard'] != true).length;
      if (actualCardsCount > 0) {
        _currentPage = 2;
        _previousPage = 2;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(2);
        }
      } else {
        _currentPage = 0;
        _previousPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    });
  }

  Future<void> _deleteCard(Map<String, dynamic> cardToDelete) async {
    if (cardToDelete['id'] == null) return;
    
    try {
      // DB에서 삭제
      await (_database.delete(_database.decks)
            ..where((tbl) => tbl.id.equals(cardToDelete['id'])))
          .go();
      
      // UI 업데이트
      setState(() {
        // 카드 삭제
        _cards.removeWhere((card) => card['id'] == cardToDelete['id']);
        
        // 삭제 후 페이지 조정
        final actualCardsCount = _cards.where((card) => card['isAddCard'] != true).length;
        
        // 카드가 모두 삭제된 경우
        if (actualCardsCount == 0) {
          _currentPage = 0; // 덱 추가 카드로 이동
          _previousPage = 0;
          _pageController.jumpToPage(0);
          return;
        }
        
        // 현재 페이지가 삭제된 카드 범위를 벗어난 경우 조정
        final realIndex = _realPageIndex;
        if (realIndex >= actualCardsCount) {
          // 마지막 페이지로 이동
          _currentPage = actualCardsCount + 1;
          _previousPage = actualCardsCount + 1;
          _pageController.jumpToPage(actualCardsCount + 1);
        } else {
          // 현재 페이지 유지 (인덱스는 그대로 유지)
          _pageController.jumpToPage(_currentPage);
        }
      });
    } catch (e) {
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _database.close();
    super.dispose();
  }

  Widget _buildCard(Map<String, dynamic> cardData) {
    // 덱 추가 카드인 경우
    if (cardData['isAddCard'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: AspectRatio(
          aspectRatio: 1 / 1.3,
          child: GestureDetector(
            onTap: () {
              // 덱 추가 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DetailPage(),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 6),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '덱 추가',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 일반 카드
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: AspectRatio(
        aspectRatio: 1 / 1.3,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(
                  cardData: cardData,
                  onDelete: () => _deleteCard(cardData),
                  onUpdate: () => _loadDecks(),
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 6),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // 배경 이미지
                  Positioned.fill(
                    child: cardData['image'] != null
                        ? Image.asset(
                            cardData['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                          ),
                  ),
                  // 그라데이션 오버레이 (텍스트 가독성 향상)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // 텍스트 영역 (왼쪽 상단)
                  Positioned(
                    top: 26,
                    left: 26,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cardData['wordCount']}단어',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cardData['date'],
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cardData['title'],
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF252525),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 100; // 좌우 패딩 50 * 2
    final cardHeight = cardWidth * 1.3; // aspect ratio 1 / 1.3

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const DetailPageSetting(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            // 카드 슬라이더
            SizedBox(
              height: cardHeight,
              child: _extendedCards.isEmpty
                  ? const Center(child: Text('덱을 추가해주세요'))
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        if (_extendedCards.isEmpty) return;
                        
                        final actualCardsCount = _cards.where((card) => card['isAddCard'] != true).length;
                        
                        // 복제본 위치에서 점프
                        // 인덱스 0 (마지막 카드 복제본) → 실제 마지막 카드 (인덱스 actualCardsCount + 1)
                        if (index == 0 && actualCardsCount > 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_pageController.hasClients) {
                              _pageController.jumpToPage(actualCardsCount + 1);
                            }
                          });
                          return;
                        }
                        
                        // 인덱스 actualCardsCount + 3 (첫 카드 복제본) → 실제 첫 번째 카드 (인덱스 2)
                        if (index == actualCardsCount + 3 && actualCardsCount > 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_pageController.hasClients) {
                              _pageController.jumpToPage(2);
                            }
                          });
                          return;
                        }
                        
                        // 일반 카드 또는 덱 추가 카드
                        if (index < _extendedCards.length) {
                          setState(() {
                            _previousPage = _currentPage;
                            _currentPage = index;
                          });
                        }
                      },
                      itemCount: _extendedCards.length,
                      itemBuilder: (context, index) {
                        if (index >= _extendedCards.length) {
                          return const SizedBox.shrink();
                        }
                        return _buildCard(_extendedCards[index]);
                      },
                    ),
            ),
            // 페이지네이션 인디케이터
            Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 실제 카드 인디케이터
                  ...List.generate(
                    _actualCardsCount,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _realPageIndex
                            ? Colors.grey[600]
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                  // 덱 추가 카드 인디케이터
                  if (_extendedCards.isNotEmpty && _currentPage < _extendedCards.length)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _extendedCards[_currentPage]['isAddCard'] == true
                            ? Colors.grey[600]
                            : Colors.grey[300],
                      ),
                      child: _extendedCards[_currentPage]['isAddCard'] == true
                          ? const Icon(
                              Icons.add,
                              size: 6,
                              color: Colors.white,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
            // 설정 아이콘 (왼쪽 위)
            Positioned(
              top: 0,
              left: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.black,
                    size: 28,
                  ),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
