import 'package:drift/drift.dart';

class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get image => text().nullable()();
  TextColumn get date => text()();
  TextColumn get title => text()();
  IntColumn get targetCount => integer().withDefault(const Constant(20))();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
}

class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId => integer().references(Decks, #id, onDelete: KeyAction.cascade)();
  IntColumn get order => integer()();
  TextColumn get word => text()();
  TextColumn get pronunciation => text()();
  TextColumn get meaning => text()();
  TextColumn get image => text().nullable()();
  TextColumn get example => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

