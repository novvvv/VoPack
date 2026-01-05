import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

// Drift Database 선언 & 사용할 테이블 (Decks, Words) 지정 
// _$AppDatabase : 생성된 클래스 
@DriftDatabase(tables: [Decks, Words])
class AppDatabase extends _$AppDatabase {

  AppDatabase() : super(_openConnection()); // DB Connect Init 

  @override
  int get schemaVersion => 2; // Schema Ver

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // 최초 생성시 실행 
      onCreate: (Migrator m) async {
        await m.createAll(); // 테이블 생성
        await _insertInitialData(); // 초기 데이터 삽입 
      },
      // 스키마 버전 업데이트시 실행
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // image와 example 컬럼 추가
          await m.addColumn(words, words.image);
          await m.addColumn(words, words.example);
        }
      },
    );
  }

  Future<void> _insertInitialData() async {
    // 기존 하드코딩된 데이터를 초기 데이터로 삽입
    final deck1Id = await into(decks).insert(DecksCompanion(
      image: const Value(''),
      date: const Value('2025.01.03'),
      title: const Value('N5'),
    ));
    
    final deck2Id = await into(decks).insert(DecksCompanion(
      image: const Value('assets/misun.png'),
      date: const Value('2025.01.04'),
      title: const Value('N4'),
    ));

    // 더미 단어 데이터 추가 (각 덱당 3개씩)
    // N5 덱 단어들
    await into(words).insert(WordsCompanion.insert(
      deckId: deck1Id,
      order: 1,
      word: 'こんにちは',
      pronunciation: 'konnichiwa',
      meaning: '안녕하세요',
    ));
    
    await into(words).insert(WordsCompanion.insert(
      deckId: deck1Id,
      order: 2,
      word: 'ありがとう',
      pronunciation: 'arigatou',
      meaning: '감사합니다',
    ));
    
    await into(words).insert(WordsCompanion.insert(
      deckId: deck1Id,
      order: 3,
      word: 'さようなら',
      pronunciation: 'sayounara',
      meaning: '안녕히 가세요',
    ));

    // N4 덱 단어들
    await into(words).insert(WordsCompanion.insert(
      deckId: deck2Id,
      order: 1,
      word: '勉強',
      pronunciation: 'benkyou',
      meaning: '공부',
    ));
    
    await into(words).insert(WordsCompanion.insert(
      deckId: deck2Id,
      order: 2,
      word: '学校',
      pronunciation: 'gakkou',
      meaning: '학교',
    ));
    
    await into(words).insert(WordsCompanion.insert(
      deckId: deck2Id,
      order: 3,
      word: '友達',
      pronunciation: 'tomodachi',
      meaning: '친구',
    ));
  }

  // 덱의 단어 개수 가져오기
  Future<int> getWordCountByDeckId(int deckId) async {
    final query = selectOnly(words)
      ..addColumns([words.id.count()])
      ..where(words.deckId.equals(deckId));
    final result = await query.getSingle();
    return result.read(words.id.count()) ?? 0;
  }

  // 덱의 단어 목록 가져오기
  Future<List<Word>> getWordsByDeckId(int deckId) async {
    return await (select(words)
          ..where((w) => w.deckId.equals(deckId))
          ..orderBy([(w) => OrderingTerm(expression: w.order)]))
        .get();
  }

  // 덱과 단어 목록을 함께 가져오기
  Future<DeckWithWords?> getDeckWithWords(int deckId) async {
    final deck = await (select(decks)..where((d) => d.id.equals(deckId))).getSingleOrNull();
    if (deck == null) return null;

    final wordsList = await getWordsByDeckId(deckId);
    return DeckWithWords(deck: deck, words: wordsList);
  }
}

// Relations: Deck과 Words의 관계 정의
class DeckWithWords {
  final Deck deck;
  final List<Word> words;

  DeckWithWords({
    required this.deck,
    required this.words,
  });
}

// Connection 
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vopet.db'));
    return NativeDatabase(file);
  });
}

