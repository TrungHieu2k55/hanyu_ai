// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalWordsTable extends LocalWords
    with TableInfo<$LocalWordsTable, StoredWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hanziMeta = const VerificationMeta('hanzi');
  @override
  late final GeneratedColumn<String> hanzi = GeneratedColumn<String>(
    'hanzi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinyinMeta = const VerificationMeta('pinyin');
  @override
  late final GeneratedColumn<String> pinyin = GeneratedColumn<String>(
    'pinyin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleHanziMeta = const VerificationMeta(
    'exampleHanzi',
  );
  @override
  late final GeneratedColumn<String> exampleHanzi = GeneratedColumn<String>(
    'example_hanzi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _exampleVietnameseMeta = const VerificationMeta(
    'exampleVietnamese',
  );
  @override
  late final GeneratedColumn<String> exampleVietnamese =
      GeneratedColumn<String>(
        'example_vietnamese',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _personalMeta = const VerificationMeta(
    'personal',
  );
  @override
  late final GeneratedColumn<bool> personal = GeneratedColumn<bool>(
    'personal',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("personal" IN (0, 1))',
    ),
  );
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<bool> saved = GeneratedColumn<bool>(
    'saved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("saved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hanzi,
    pinyin,
    meaning,
    exampleHanzi,
    exampleVietnamese,
    personal,
    saved,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hanzi')) {
      context.handle(
        _hanziMeta,
        hanzi.isAcceptableOrUnknown(data['hanzi']!, _hanziMeta),
      );
    } else if (isInserting) {
      context.missing(_hanziMeta);
    }
    if (data.containsKey('pinyin')) {
      context.handle(
        _pinyinMeta,
        pinyin.isAcceptableOrUnknown(data['pinyin']!, _pinyinMeta),
      );
    } else if (isInserting) {
      context.missing(_pinyinMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('example_hanzi')) {
      context.handle(
        _exampleHanziMeta,
        exampleHanzi.isAcceptableOrUnknown(
          data['example_hanzi']!,
          _exampleHanziMeta,
        ),
      );
    }
    if (data.containsKey('example_vietnamese')) {
      context.handle(
        _exampleVietnameseMeta,
        exampleVietnamese.isAcceptableOrUnknown(
          data['example_vietnamese']!,
          _exampleVietnameseMeta,
        ),
      );
    }
    if (data.containsKey('personal')) {
      context.handle(
        _personalMeta,
        personal.isAcceptableOrUnknown(data['personal']!, _personalMeta),
      );
    } else if (isInserting) {
      context.missing(_personalMeta);
    }
    if (data.containsKey('saved')) {
      context.handle(
        _savedMeta,
        saved.isAcceptableOrUnknown(data['saved']!, _savedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredWord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      hanzi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hanzi'],
      )!,
      pinyin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinyin'],
      )!,
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      exampleHanzi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_hanzi'],
      )!,
      exampleVietnamese: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_vietnamese'],
      )!,
      personal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}personal'],
      )!,
      saved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}saved'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $LocalWordsTable createAlias(String alias) {
    return $LocalWordsTable(attachedDatabase, alias);
  }
}

class StoredWord extends DataClass implements Insertable<StoredWord> {
  final String id;
  final String hanzi;
  final String pinyin;
  final String meaning;
  final String exampleHanzi;
  final String exampleVietnamese;
  final bool personal;
  final bool saved;
  final String note;
  const StoredWord({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    required this.exampleHanzi,
    required this.exampleVietnamese,
    required this.personal,
    required this.saved,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hanzi'] = Variable<String>(hanzi);
    map['pinyin'] = Variable<String>(pinyin);
    map['meaning'] = Variable<String>(meaning);
    map['example_hanzi'] = Variable<String>(exampleHanzi);
    map['example_vietnamese'] = Variable<String>(exampleVietnamese);
    map['personal'] = Variable<bool>(personal);
    map['saved'] = Variable<bool>(saved);
    map['note'] = Variable<String>(note);
    return map;
  }

  LocalWordsCompanion toCompanion(bool nullToAbsent) {
    return LocalWordsCompanion(
      id: Value(id),
      hanzi: Value(hanzi),
      pinyin: Value(pinyin),
      meaning: Value(meaning),
      exampleHanzi: Value(exampleHanzi),
      exampleVietnamese: Value(exampleVietnamese),
      personal: Value(personal),
      saved: Value(saved),
      note: Value(note),
    );
  }

  factory StoredWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredWord(
      id: serializer.fromJson<String>(json['id']),
      hanzi: serializer.fromJson<String>(json['hanzi']),
      pinyin: serializer.fromJson<String>(json['pinyin']),
      meaning: serializer.fromJson<String>(json['meaning']),
      exampleHanzi: serializer.fromJson<String>(json['exampleHanzi']),
      exampleVietnamese: serializer.fromJson<String>(json['exampleVietnamese']),
      personal: serializer.fromJson<bool>(json['personal']),
      saved: serializer.fromJson<bool>(json['saved']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hanzi': serializer.toJson<String>(hanzi),
      'pinyin': serializer.toJson<String>(pinyin),
      'meaning': serializer.toJson<String>(meaning),
      'exampleHanzi': serializer.toJson<String>(exampleHanzi),
      'exampleVietnamese': serializer.toJson<String>(exampleVietnamese),
      'personal': serializer.toJson<bool>(personal),
      'saved': serializer.toJson<bool>(saved),
      'note': serializer.toJson<String>(note),
    };
  }

  StoredWord copyWith({
    String? id,
    String? hanzi,
    String? pinyin,
    String? meaning,
    String? exampleHanzi,
    String? exampleVietnamese,
    bool? personal,
    bool? saved,
    String? note,
  }) => StoredWord(
    id: id ?? this.id,
    hanzi: hanzi ?? this.hanzi,
    pinyin: pinyin ?? this.pinyin,
    meaning: meaning ?? this.meaning,
    exampleHanzi: exampleHanzi ?? this.exampleHanzi,
    exampleVietnamese: exampleVietnamese ?? this.exampleVietnamese,
    personal: personal ?? this.personal,
    saved: saved ?? this.saved,
    note: note ?? this.note,
  );
  StoredWord copyWithCompanion(LocalWordsCompanion data) {
    return StoredWord(
      id: data.id.present ? data.id.value : this.id,
      hanzi: data.hanzi.present ? data.hanzi.value : this.hanzi,
      pinyin: data.pinyin.present ? data.pinyin.value : this.pinyin,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      exampleHanzi: data.exampleHanzi.present
          ? data.exampleHanzi.value
          : this.exampleHanzi,
      exampleVietnamese: data.exampleVietnamese.present
          ? data.exampleVietnamese.value
          : this.exampleVietnamese,
      personal: data.personal.present ? data.personal.value : this.personal,
      saved: data.saved.present ? data.saved.value : this.saved,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredWord(')
          ..write('id: $id, ')
          ..write('hanzi: $hanzi, ')
          ..write('pinyin: $pinyin, ')
          ..write('meaning: $meaning, ')
          ..write('exampleHanzi: $exampleHanzi, ')
          ..write('exampleVietnamese: $exampleVietnamese, ')
          ..write('personal: $personal, ')
          ..write('saved: $saved, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hanzi,
    pinyin,
    meaning,
    exampleHanzi,
    exampleVietnamese,
    personal,
    saved,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredWord &&
          other.id == this.id &&
          other.hanzi == this.hanzi &&
          other.pinyin == this.pinyin &&
          other.meaning == this.meaning &&
          other.exampleHanzi == this.exampleHanzi &&
          other.exampleVietnamese == this.exampleVietnamese &&
          other.personal == this.personal &&
          other.saved == this.saved &&
          other.note == this.note);
}

class LocalWordsCompanion extends UpdateCompanion<StoredWord> {
  final Value<String> id;
  final Value<String> hanzi;
  final Value<String> pinyin;
  final Value<String> meaning;
  final Value<String> exampleHanzi;
  final Value<String> exampleVietnamese;
  final Value<bool> personal;
  final Value<bool> saved;
  final Value<String> note;
  final Value<int> rowid;
  const LocalWordsCompanion({
    this.id = const Value.absent(),
    this.hanzi = const Value.absent(),
    this.pinyin = const Value.absent(),
    this.meaning = const Value.absent(),
    this.exampleHanzi = const Value.absent(),
    this.exampleVietnamese = const Value.absent(),
    this.personal = const Value.absent(),
    this.saved = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWordsCompanion.insert({
    required String id,
    required String hanzi,
    required String pinyin,
    required String meaning,
    this.exampleHanzi = const Value.absent(),
    this.exampleVietnamese = const Value.absent(),
    required bool personal,
    this.saved = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       hanzi = Value(hanzi),
       pinyin = Value(pinyin),
       meaning = Value(meaning),
       personal = Value(personal);
  static Insertable<StoredWord> custom({
    Expression<String>? id,
    Expression<String>? hanzi,
    Expression<String>? pinyin,
    Expression<String>? meaning,
    Expression<String>? exampleHanzi,
    Expression<String>? exampleVietnamese,
    Expression<bool>? personal,
    Expression<bool>? saved,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hanzi != null) 'hanzi': hanzi,
      if (pinyin != null) 'pinyin': pinyin,
      if (meaning != null) 'meaning': meaning,
      if (exampleHanzi != null) 'example_hanzi': exampleHanzi,
      if (exampleVietnamese != null) 'example_vietnamese': exampleVietnamese,
      if (personal != null) 'personal': personal,
      if (saved != null) 'saved': saved,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWordsCompanion copyWith({
    Value<String>? id,
    Value<String>? hanzi,
    Value<String>? pinyin,
    Value<String>? meaning,
    Value<String>? exampleHanzi,
    Value<String>? exampleVietnamese,
    Value<bool>? personal,
    Value<bool>? saved,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return LocalWordsCompanion(
      id: id ?? this.id,
      hanzi: hanzi ?? this.hanzi,
      pinyin: pinyin ?? this.pinyin,
      meaning: meaning ?? this.meaning,
      exampleHanzi: exampleHanzi ?? this.exampleHanzi,
      exampleVietnamese: exampleVietnamese ?? this.exampleVietnamese,
      personal: personal ?? this.personal,
      saved: saved ?? this.saved,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hanzi.present) {
      map['hanzi'] = Variable<String>(hanzi.value);
    }
    if (pinyin.present) {
      map['pinyin'] = Variable<String>(pinyin.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (exampleHanzi.present) {
      map['example_hanzi'] = Variable<String>(exampleHanzi.value);
    }
    if (exampleVietnamese.present) {
      map['example_vietnamese'] = Variable<String>(exampleVietnamese.value);
    }
    if (personal.present) {
      map['personal'] = Variable<bool>(personal.value);
    }
    if (saved.present) {
      map['saved'] = Variable<bool>(saved.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWordsCompanion(')
          ..write('id: $id, ')
          ..write('hanzi: $hanzi, ')
          ..write('pinyin: $pinyin, ')
          ..write('meaning: $meaning, ')
          ..write('exampleHanzi: $exampleHanzi, ')
          ..write('exampleVietnamese: $exampleVietnamese, ')
          ..write('personal: $personal, ')
          ..write('saved: $saved, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMetadataTable extends LocalMetadata
    with TableInfo<$LocalMetadataTable, LocalMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalMetadataTable createAlias(String alias) {
    return $LocalMetadataTable(attachedDatabase, alias);
  }
}

class LocalMetadataData extends DataClass
    implements Insertable<LocalMetadataData> {
  final String key;
  final String value;
  const LocalMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalMetadataCompanion toCompanion(bool nullToAbsent) {
    return LocalMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory LocalMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalMetadataData copyWith({String? key, String? value}) =>
      LocalMetadataData(key: key ?? this.key, value: value ?? this.value);
  LocalMetadataData copyWithCompanion(LocalMetadataCompanion data) {
    return LocalMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalMetadataCompanion extends UpdateCompanion<LocalMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalReceiptsTable extends LocalReceipts
    with TableInfo<$LocalReceiptsTable, LocalReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [operationId, fingerprint];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  LocalReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReceipt(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
    );
  }

  @override
  $LocalReceiptsTable createAlias(String alias) {
    return $LocalReceiptsTable(attachedDatabase, alias);
  }
}

class LocalReceipt extends DataClass implements Insertable<LocalReceipt> {
  final String operationId;
  final String fingerprint;
  const LocalReceipt({required this.operationId, required this.fingerprint});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['fingerprint'] = Variable<String>(fingerprint);
    return map;
  }

  LocalReceiptsCompanion toCompanion(bool nullToAbsent) {
    return LocalReceiptsCompanion(
      operationId: Value(operationId),
      fingerprint: Value(fingerprint),
    );
  }

  factory LocalReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReceipt(
      operationId: serializer.fromJson<String>(json['operationId']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'fingerprint': serializer.toJson<String>(fingerprint),
    };
  }

  LocalReceipt copyWith({String? operationId, String? fingerprint}) =>
      LocalReceipt(
        operationId: operationId ?? this.operationId,
        fingerprint: fingerprint ?? this.fingerprint,
      );
  LocalReceipt copyWithCompanion(LocalReceiptsCompanion data) {
    return LocalReceipt(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReceipt(')
          ..write('operationId: $operationId, ')
          ..write('fingerprint: $fingerprint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(operationId, fingerprint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReceipt &&
          other.operationId == this.operationId &&
          other.fingerprint == this.fingerprint);
}

class LocalReceiptsCompanion extends UpdateCompanion<LocalReceipt> {
  final Value<String> operationId;
  final Value<String> fingerprint;
  final Value<int> rowid;
  const LocalReceiptsCompanion({
    this.operationId = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalReceiptsCompanion.insert({
    required String operationId,
    required String fingerprint,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       fingerprint = Value(fingerprint);
  static Insertable<LocalReceipt> custom({
    Expression<String>? operationId,
    Expression<String>? fingerprint,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalReceiptsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? fingerprint,
    Value<int>? rowid,
  }) {
    return LocalReceiptsCompanion(
      operationId: operationId ?? this.operationId,
      fingerprint: fingerprint ?? this.fingerprint,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReceiptsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSchedulesTable extends LocalSchedules
    with TableInfo<$LocalSchedulesTable, StoredSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_words (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    repetitions,
    intervalDays,
    ease,
    dueAt,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  StoredSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSchedule(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $LocalSchedulesTable createAlias(String alias) {
    return $LocalSchedulesTable(attachedDatabase, alias);
  }
}

class StoredSchedule extends DataClass implements Insertable<StoredSchedule> {
  final String wordId;
  final int repetitions;
  final int intervalDays;
  final double ease;
  final DateTime dueAt;
  final bool active;
  const StoredSchedule({
    required this.wordId,
    required this.repetitions,
    required this.intervalDays,
    required this.ease,
    required this.dueAt,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['repetitions'] = Variable<int>(repetitions);
    map['interval_days'] = Variable<int>(intervalDays);
    map['ease'] = Variable<double>(ease);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['active'] = Variable<bool>(active);
    return map;
  }

  LocalSchedulesCompanion toCompanion(bool nullToAbsent) {
    return LocalSchedulesCompanion(
      wordId: Value(wordId),
      repetitions: Value(repetitions),
      intervalDays: Value(intervalDays),
      ease: Value(ease),
      dueAt: Value(dueAt),
      active: Value(active),
    );
  }

  factory StoredSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSchedule(
      wordId: serializer.fromJson<String>(json['wordId']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      ease: serializer.fromJson<double>(json['ease']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'repetitions': serializer.toJson<int>(repetitions),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'ease': serializer.toJson<double>(ease),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'active': serializer.toJson<bool>(active),
    };
  }

  StoredSchedule copyWith({
    String? wordId,
    int? repetitions,
    int? intervalDays,
    double? ease,
    DateTime? dueAt,
    bool? active,
  }) => StoredSchedule(
    wordId: wordId ?? this.wordId,
    repetitions: repetitions ?? this.repetitions,
    intervalDays: intervalDays ?? this.intervalDays,
    ease: ease ?? this.ease,
    dueAt: dueAt ?? this.dueAt,
    active: active ?? this.active,
  );
  StoredSchedule copyWithCompanion(LocalSchedulesCompanion data) {
    return StoredSchedule(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      ease: data.ease.present ? data.ease.value : this.ease,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSchedule(')
          ..write('wordId: $wordId, ')
          ..write('repetitions: $repetitions, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('dueAt: $dueAt, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(wordId, repetitions, intervalDays, ease, dueAt, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSchedule &&
          other.wordId == this.wordId &&
          other.repetitions == this.repetitions &&
          other.intervalDays == this.intervalDays &&
          other.ease == this.ease &&
          other.dueAt == this.dueAt &&
          other.active == this.active);
}

class LocalSchedulesCompanion extends UpdateCompanion<StoredSchedule> {
  final Value<String> wordId;
  final Value<int> repetitions;
  final Value<int> intervalDays;
  final Value<double> ease;
  final Value<DateTime> dueAt;
  final Value<bool> active;
  final Value<int> rowid;
  const LocalSchedulesCompanion({
    this.wordId = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSchedulesCompanion.insert({
    required String wordId,
    this.repetitions = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.ease = const Value.absent(),
    required DateTime dueAt,
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       dueAt = Value(dueAt);
  static Insertable<StoredSchedule> custom({
    Expression<String>? wordId,
    Expression<int>? repetitions,
    Expression<int>? intervalDays,
    Expression<double>? ease,
    Expression<DateTime>? dueAt,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (repetitions != null) 'repetitions': repetitions,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (ease != null) 'ease': ease,
      if (dueAt != null) 'due_at': dueAt,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSchedulesCompanion copyWith({
    Value<String>? wordId,
    Value<int>? repetitions,
    Value<int>? intervalDays,
    Value<double>? ease,
    Value<DateTime>? dueAt,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return LocalSchedulesCompanion(
      wordId: wordId ?? this.wordId,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      dueAt: dueAt ?? this.dueAt,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSchedulesCompanion(')
          ..write('wordId: $wordId, ')
          ..write('repetitions: $repetitions, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('dueAt: $dueAt, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalReviewSessionsTable extends LocalReviewSessions
    with TableInfo<$LocalReviewSessionsTable, StoredReviewSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReviewSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardsJsonMeta = const VerificationMeta(
    'cardsJson',
  );
  @override
  late final GeneratedColumn<String> cardsJson = GeneratedColumn<String>(
    'cards_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revealedMeta = const VerificationMeta(
    'revealed',
  );
  @override
  late final GeneratedColumn<bool> revealed = GeneratedColumn<bool>(
    'revealed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revealed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardsJson,
    position,
    revealed,
    createdAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_review_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReviewSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cards_json')) {
      context.handle(
        _cardsJsonMeta,
        cardsJson.isAcceptableOrUnknown(data['cards_json']!, _cardsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cardsJsonMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('revealed')) {
      context.handle(
        _revealedMeta,
        revealed.isAcceptableOrUnknown(data['revealed']!, _revealedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredReviewSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReviewSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cardsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cards_json'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      revealed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revealed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $LocalReviewSessionsTable createAlias(String alias) {
    return $LocalReviewSessionsTable(attachedDatabase, alias);
  }
}

class StoredReviewSession extends DataClass
    implements Insertable<StoredReviewSession> {
  final String id;
  final String cardsJson;
  final int position;
  final bool revealed;
  final DateTime createdAt;
  final DateTime? finishedAt;
  const StoredReviewSession({
    required this.id,
    required this.cardsJson,
    required this.position,
    required this.revealed,
    required this.createdAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cards_json'] = Variable<String>(cardsJson);
    map['position'] = Variable<int>(position);
    map['revealed'] = Variable<bool>(revealed);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  LocalReviewSessionsCompanion toCompanion(bool nullToAbsent) {
    return LocalReviewSessionsCompanion(
      id: Value(id),
      cardsJson: Value(cardsJson),
      position: Value(position),
      revealed: Value(revealed),
      createdAt: Value(createdAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory StoredReviewSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReviewSession(
      id: serializer.fromJson<String>(json['id']),
      cardsJson: serializer.fromJson<String>(json['cardsJson']),
      position: serializer.fromJson<int>(json['position']),
      revealed: serializer.fromJson<bool>(json['revealed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cardsJson': serializer.toJson<String>(cardsJson),
      'position': serializer.toJson<int>(position),
      'revealed': serializer.toJson<bool>(revealed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  StoredReviewSession copyWith({
    String? id,
    String? cardsJson,
    int? position,
    bool? revealed,
    DateTime? createdAt,
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => StoredReviewSession(
    id: id ?? this.id,
    cardsJson: cardsJson ?? this.cardsJson,
    position: position ?? this.position,
    revealed: revealed ?? this.revealed,
    createdAt: createdAt ?? this.createdAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  StoredReviewSession copyWithCompanion(LocalReviewSessionsCompanion data) {
    return StoredReviewSession(
      id: data.id.present ? data.id.value : this.id,
      cardsJson: data.cardsJson.present ? data.cardsJson.value : this.cardsJson,
      position: data.position.present ? data.position.value : this.position,
      revealed: data.revealed.present ? data.revealed.value : this.revealed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReviewSession(')
          ..write('id: $id, ')
          ..write('cardsJson: $cardsJson, ')
          ..write('position: $position, ')
          ..write('revealed: $revealed, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cardsJson, position, revealed, createdAt, finishedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReviewSession &&
          other.id == this.id &&
          other.cardsJson == this.cardsJson &&
          other.position == this.position &&
          other.revealed == this.revealed &&
          other.createdAt == this.createdAt &&
          other.finishedAt == this.finishedAt);
}

class LocalReviewSessionsCompanion
    extends UpdateCompanion<StoredReviewSession> {
  final Value<String> id;
  final Value<String> cardsJson;
  final Value<int> position;
  final Value<bool> revealed;
  final Value<DateTime> createdAt;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const LocalReviewSessionsCompanion({
    this.id = const Value.absent(),
    this.cardsJson = const Value.absent(),
    this.position = const Value.absent(),
    this.revealed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalReviewSessionsCompanion.insert({
    required String id,
    required String cardsJson,
    this.position = const Value.absent(),
    this.revealed = const Value.absent(),
    required DateTime createdAt,
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardsJson = Value(cardsJson),
       createdAt = Value(createdAt);
  static Insertable<StoredReviewSession> custom({
    Expression<String>? id,
    Expression<String>? cardsJson,
    Expression<int>? position,
    Expression<bool>? revealed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardsJson != null) 'cards_json': cardsJson,
      if (position != null) 'position': position,
      if (revealed != null) 'revealed': revealed,
      if (createdAt != null) 'created_at': createdAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalReviewSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? cardsJson,
    Value<int>? position,
    Value<bool>? revealed,
    Value<DateTime>? createdAt,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return LocalReviewSessionsCompanion(
      id: id ?? this.id,
      cardsJson: cardsJson ?? this.cardsJson,
      position: position ?? this.position,
      revealed: revealed ?? this.revealed,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cardsJson.present) {
      map['cards_json'] = Variable<String>(cardsJson.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (revealed.present) {
      map['revealed'] = Variable<bool>(revealed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReviewSessionsCompanion(')
          ..write('id: $id, ')
          ..write('cardsJson: $cardsJson, ')
          ..write('position: $position, ')
          ..write('revealed: $revealed, ')
          ..write('createdAt: $createdAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalReviewEventsTable extends LocalReviewEvents
    with TableInfo<$LocalReviewEventsTable, StoredReviewEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_review_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
    'accepted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    wordId,
    position,
    quality,
    acceptedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_review_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReviewEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acceptedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredReviewEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReviewEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      )!,
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}accepted_at'],
      )!,
    );
  }

  @override
  $LocalReviewEventsTable createAlias(String alias) {
    return $LocalReviewEventsTable(attachedDatabase, alias);
  }
}

class StoredReviewEvent extends DataClass
    implements Insertable<StoredReviewEvent> {
  final String id;
  final String sessionId;
  final String wordId;
  final int position;
  final int quality;
  final DateTime acceptedAt;
  const StoredReviewEvent({
    required this.id,
    required this.sessionId,
    required this.wordId,
    required this.position,
    required this.quality,
    required this.acceptedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['word_id'] = Variable<String>(wordId);
    map['position'] = Variable<int>(position);
    map['quality'] = Variable<int>(quality);
    map['accepted_at'] = Variable<DateTime>(acceptedAt);
    return map;
  }

  LocalReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalReviewEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      wordId: Value(wordId),
      position: Value(position),
      quality: Value(quality),
      acceptedAt: Value(acceptedAt),
    );
  }

  factory StoredReviewEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReviewEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      wordId: serializer.fromJson<String>(json['wordId']),
      position: serializer.fromJson<int>(json['position']),
      quality: serializer.fromJson<int>(json['quality']),
      acceptedAt: serializer.fromJson<DateTime>(json['acceptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'wordId': serializer.toJson<String>(wordId),
      'position': serializer.toJson<int>(position),
      'quality': serializer.toJson<int>(quality),
      'acceptedAt': serializer.toJson<DateTime>(acceptedAt),
    };
  }

  StoredReviewEvent copyWith({
    String? id,
    String? sessionId,
    String? wordId,
    int? position,
    int? quality,
    DateTime? acceptedAt,
  }) => StoredReviewEvent(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    wordId: wordId ?? this.wordId,
    position: position ?? this.position,
    quality: quality ?? this.quality,
    acceptedAt: acceptedAt ?? this.acceptedAt,
  );
  StoredReviewEvent copyWithCompanion(LocalReviewEventsCompanion data) {
    return StoredReviewEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      position: data.position.present ? data.position.value : this.position,
      quality: data.quality.present ? data.quality.value : this.quality,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReviewEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('wordId: $wordId, ')
          ..write('position: $position, ')
          ..write('quality: $quality, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, wordId, position, quality, acceptedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReviewEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.wordId == this.wordId &&
          other.position == this.position &&
          other.quality == this.quality &&
          other.acceptedAt == this.acceptedAt);
}

class LocalReviewEventsCompanion extends UpdateCompanion<StoredReviewEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> wordId;
  final Value<int> position;
  final Value<int> quality;
  final Value<DateTime> acceptedAt;
  final Value<int> rowid;
  const LocalReviewEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.wordId = const Value.absent(),
    this.position = const Value.absent(),
    this.quality = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalReviewEventsCompanion.insert({
    required String id,
    required String sessionId,
    required String wordId,
    required int position,
    required int quality,
    required DateTime acceptedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       wordId = Value(wordId),
       position = Value(position),
       quality = Value(quality),
       acceptedAt = Value(acceptedAt);
  static Insertable<StoredReviewEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? wordId,
    Expression<int>? position,
    Expression<int>? quality,
    Expression<DateTime>? acceptedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (wordId != null) 'word_id': wordId,
      if (position != null) 'position': position,
      if (quality != null) 'quality': quality,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalReviewEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? wordId,
    Value<int>? position,
    Value<int>? quality,
    Value<DateTime>? acceptedAt,
    Value<int>? rowid,
  }) {
    return LocalReviewEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      wordId: wordId ?? this.wordId,
      position: position ?? this.position,
      quality: quality ?? this.quality,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReviewEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('wordId: $wordId, ')
          ..write('position: $position, ')
          ..write('quality: $quality, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalExamAttemptsTable extends LocalExamAttempts
    with TableInfo<$LocalExamAttemptsTable, StoredExamAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalExamAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageVersionMeta = const VerificationMeta(
    'packageVersion',
  );
  @override
  late final GeneratedColumn<String> packageVersion = GeneratedColumn<String>(
    'package_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLevelMeta = const VerificationMeta(
    'targetLevel',
  );
  @override
  late final GeneratedColumn<int> targetLevel = GeneratedColumn<int>(
    'target_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionsJsonMeta = const VerificationMeta(
    'questionsJson',
  );
  @override
  late final GeneratedColumn<String> questionsJson = GeneratedColumn<String>(
    'questions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersJsonMeta = const VerificationMeta(
    'answersJson',
  );
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
    'answers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timedOutMeta = const VerificationMeta(
    'timedOut',
  );
  @override
  late final GeneratedColumn<bool> timedOut = GeneratedColumn<bool>(
    'timed_out',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("timed_out" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    packageId,
    packageVersion,
    targetLevel,
    mode,
    questionsJson,
    answersJson,
    position,
    startedAt,
    deadline,
    submittedAt,
    timedOut,
    correctCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_exam_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredExamAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('package_version')) {
      context.handle(
        _packageVersionMeta,
        packageVersion.isAcceptableOrUnknown(
          data['package_version']!,
          _packageVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_packageVersionMeta);
    }
    if (data.containsKey('target_level')) {
      context.handle(
        _targetLevelMeta,
        targetLevel.isAcceptableOrUnknown(
          data['target_level']!,
          _targetLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetLevelMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('questions_json')) {
      context.handle(
        _questionsJsonMeta,
        questionsJson.isAcceptableOrUnknown(
          data['questions_json']!,
          _questionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionsJsonMeta);
    }
    if (data.containsKey('answers_json')) {
      context.handle(
        _answersJsonMeta,
        answersJson.isAcceptableOrUnknown(
          data['answers_json']!,
          _answersJsonMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    } else if (isInserting) {
      context.missing(_deadlineMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    }
    if (data.containsKey('timed_out')) {
      context.handle(
        _timedOutMeta,
        timedOut.isAcceptableOrUnknown(data['timed_out']!, _timedOutMeta),
      );
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredExamAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredExamAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      packageVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_version'],
      )!,
      targetLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_level'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      questionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions_json'],
      )!,
      answersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers_json'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      )!,
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}submitted_at'],
      ),
      timedOut: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}timed_out'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      ),
    );
  }

  @override
  $LocalExamAttemptsTable createAlias(String alias) {
    return $LocalExamAttemptsTable(attachedDatabase, alias);
  }
}

class StoredExamAttempt extends DataClass
    implements Insertable<StoredExamAttempt> {
  final String id;
  final String packageId;
  final String packageVersion;
  final int targetLevel;
  final String mode;
  final String questionsJson;
  final String answersJson;
  final int position;
  final DateTime startedAt;
  final DateTime deadline;
  final DateTime? submittedAt;
  final bool timedOut;
  final int? correctCount;
  const StoredExamAttempt({
    required this.id,
    required this.packageId,
    required this.packageVersion,
    required this.targetLevel,
    required this.mode,
    required this.questionsJson,
    required this.answersJson,
    required this.position,
    required this.startedAt,
    required this.deadline,
    this.submittedAt,
    required this.timedOut,
    this.correctCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['package_id'] = Variable<String>(packageId);
    map['package_version'] = Variable<String>(packageVersion);
    map['target_level'] = Variable<int>(targetLevel);
    map['mode'] = Variable<String>(mode);
    map['questions_json'] = Variable<String>(questionsJson);
    map['answers_json'] = Variable<String>(answersJson);
    map['position'] = Variable<int>(position);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['deadline'] = Variable<DateTime>(deadline);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    map['timed_out'] = Variable<bool>(timedOut);
    if (!nullToAbsent || correctCount != null) {
      map['correct_count'] = Variable<int>(correctCount);
    }
    return map;
  }

  LocalExamAttemptsCompanion toCompanion(bool nullToAbsent) {
    return LocalExamAttemptsCompanion(
      id: Value(id),
      packageId: Value(packageId),
      packageVersion: Value(packageVersion),
      targetLevel: Value(targetLevel),
      mode: Value(mode),
      questionsJson: Value(questionsJson),
      answersJson: Value(answersJson),
      position: Value(position),
      startedAt: Value(startedAt),
      deadline: Value(deadline),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      timedOut: Value(timedOut),
      correctCount: correctCount == null && nullToAbsent
          ? const Value.absent()
          : Value(correctCount),
    );
  }

  factory StoredExamAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredExamAttempt(
      id: serializer.fromJson<String>(json['id']),
      packageId: serializer.fromJson<String>(json['packageId']),
      packageVersion: serializer.fromJson<String>(json['packageVersion']),
      targetLevel: serializer.fromJson<int>(json['targetLevel']),
      mode: serializer.fromJson<String>(json['mode']),
      questionsJson: serializer.fromJson<String>(json['questionsJson']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      position: serializer.fromJson<int>(json['position']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      deadline: serializer.fromJson<DateTime>(json['deadline']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      timedOut: serializer.fromJson<bool>(json['timedOut']),
      correctCount: serializer.fromJson<int?>(json['correctCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packageId': serializer.toJson<String>(packageId),
      'packageVersion': serializer.toJson<String>(packageVersion),
      'targetLevel': serializer.toJson<int>(targetLevel),
      'mode': serializer.toJson<String>(mode),
      'questionsJson': serializer.toJson<String>(questionsJson),
      'answersJson': serializer.toJson<String>(answersJson),
      'position': serializer.toJson<int>(position),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'deadline': serializer.toJson<DateTime>(deadline),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'timedOut': serializer.toJson<bool>(timedOut),
      'correctCount': serializer.toJson<int?>(correctCount),
    };
  }

  StoredExamAttempt copyWith({
    String? id,
    String? packageId,
    String? packageVersion,
    int? targetLevel,
    String? mode,
    String? questionsJson,
    String? answersJson,
    int? position,
    DateTime? startedAt,
    DateTime? deadline,
    Value<DateTime?> submittedAt = const Value.absent(),
    bool? timedOut,
    Value<int?> correctCount = const Value.absent(),
  }) => StoredExamAttempt(
    id: id ?? this.id,
    packageId: packageId ?? this.packageId,
    packageVersion: packageVersion ?? this.packageVersion,
    targetLevel: targetLevel ?? this.targetLevel,
    mode: mode ?? this.mode,
    questionsJson: questionsJson ?? this.questionsJson,
    answersJson: answersJson ?? this.answersJson,
    position: position ?? this.position,
    startedAt: startedAt ?? this.startedAt,
    deadline: deadline ?? this.deadline,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    timedOut: timedOut ?? this.timedOut,
    correctCount: correctCount.present ? correctCount.value : this.correctCount,
  );
  StoredExamAttempt copyWithCompanion(LocalExamAttemptsCompanion data) {
    return StoredExamAttempt(
      id: data.id.present ? data.id.value : this.id,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      packageVersion: data.packageVersion.present
          ? data.packageVersion.value
          : this.packageVersion,
      targetLevel: data.targetLevel.present
          ? data.targetLevel.value
          : this.targetLevel,
      mode: data.mode.present ? data.mode.value : this.mode,
      questionsJson: data.questionsJson.present
          ? data.questionsJson.value
          : this.questionsJson,
      answersJson: data.answersJson.present
          ? data.answersJson.value
          : this.answersJson,
      position: data.position.present ? data.position.value : this.position,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      timedOut: data.timedOut.present ? data.timedOut.value : this.timedOut,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredExamAttempt(')
          ..write('id: $id, ')
          ..write('packageId: $packageId, ')
          ..write('packageVersion: $packageVersion, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('mode: $mode, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('position: $position, ')
          ..write('startedAt: $startedAt, ')
          ..write('deadline: $deadline, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('timedOut: $timedOut, ')
          ..write('correctCount: $correctCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    packageId,
    packageVersion,
    targetLevel,
    mode,
    questionsJson,
    answersJson,
    position,
    startedAt,
    deadline,
    submittedAt,
    timedOut,
    correctCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredExamAttempt &&
          other.id == this.id &&
          other.packageId == this.packageId &&
          other.packageVersion == this.packageVersion &&
          other.targetLevel == this.targetLevel &&
          other.mode == this.mode &&
          other.questionsJson == this.questionsJson &&
          other.answersJson == this.answersJson &&
          other.position == this.position &&
          other.startedAt == this.startedAt &&
          other.deadline == this.deadline &&
          other.submittedAt == this.submittedAt &&
          other.timedOut == this.timedOut &&
          other.correctCount == this.correctCount);
}

class LocalExamAttemptsCompanion extends UpdateCompanion<StoredExamAttempt> {
  final Value<String> id;
  final Value<String> packageId;
  final Value<String> packageVersion;
  final Value<int> targetLevel;
  final Value<String> mode;
  final Value<String> questionsJson;
  final Value<String> answersJson;
  final Value<int> position;
  final Value<DateTime> startedAt;
  final Value<DateTime> deadline;
  final Value<DateTime?> submittedAt;
  final Value<bool> timedOut;
  final Value<int?> correctCount;
  final Value<int> rowid;
  const LocalExamAttemptsCompanion({
    this.id = const Value.absent(),
    this.packageId = const Value.absent(),
    this.packageVersion = const Value.absent(),
    this.targetLevel = const Value.absent(),
    this.mode = const Value.absent(),
    this.questionsJson = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.position = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.deadline = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.timedOut = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalExamAttemptsCompanion.insert({
    required String id,
    required String packageId,
    required String packageVersion,
    required int targetLevel,
    required String mode,
    required String questionsJson,
    this.answersJson = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime startedAt,
    required DateTime deadline,
    this.submittedAt = const Value.absent(),
    this.timedOut = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       packageId = Value(packageId),
       packageVersion = Value(packageVersion),
       targetLevel = Value(targetLevel),
       mode = Value(mode),
       questionsJson = Value(questionsJson),
       startedAt = Value(startedAt),
       deadline = Value(deadline);
  static Insertable<StoredExamAttempt> custom({
    Expression<String>? id,
    Expression<String>? packageId,
    Expression<String>? packageVersion,
    Expression<int>? targetLevel,
    Expression<String>? mode,
    Expression<String>? questionsJson,
    Expression<String>? answersJson,
    Expression<int>? position,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? deadline,
    Expression<DateTime>? submittedAt,
    Expression<bool>? timedOut,
    Expression<int>? correctCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packageId != null) 'package_id': packageId,
      if (packageVersion != null) 'package_version': packageVersion,
      if (targetLevel != null) 'target_level': targetLevel,
      if (mode != null) 'mode': mode,
      if (questionsJson != null) 'questions_json': questionsJson,
      if (answersJson != null) 'answers_json': answersJson,
      if (position != null) 'position': position,
      if (startedAt != null) 'started_at': startedAt,
      if (deadline != null) 'deadline': deadline,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (timedOut != null) 'timed_out': timedOut,
      if (correctCount != null) 'correct_count': correctCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalExamAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? packageId,
    Value<String>? packageVersion,
    Value<int>? targetLevel,
    Value<String>? mode,
    Value<String>? questionsJson,
    Value<String>? answersJson,
    Value<int>? position,
    Value<DateTime>? startedAt,
    Value<DateTime>? deadline,
    Value<DateTime?>? submittedAt,
    Value<bool>? timedOut,
    Value<int?>? correctCount,
    Value<int>? rowid,
  }) {
    return LocalExamAttemptsCompanion(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      packageVersion: packageVersion ?? this.packageVersion,
      targetLevel: targetLevel ?? this.targetLevel,
      mode: mode ?? this.mode,
      questionsJson: questionsJson ?? this.questionsJson,
      answersJson: answersJson ?? this.answersJson,
      position: position ?? this.position,
      startedAt: startedAt ?? this.startedAt,
      deadline: deadline ?? this.deadline,
      submittedAt: submittedAt ?? this.submittedAt,
      timedOut: timedOut ?? this.timedOut,
      correctCount: correctCount ?? this.correctCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (packageVersion.present) {
      map['package_version'] = Variable<String>(packageVersion.value);
    }
    if (targetLevel.present) {
      map['target_level'] = Variable<int>(targetLevel.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (questionsJson.present) {
      map['questions_json'] = Variable<String>(questionsJson.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (timedOut.present) {
      map['timed_out'] = Variable<bool>(timedOut.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalExamAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('packageId: $packageId, ')
          ..write('packageVersion: $packageVersion, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('mode: $mode, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('position: $position, ')
          ..write('startedAt: $startedAt, ')
          ..write('deadline: $deadline, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('timedOut: $timedOut, ')
          ..write('correctCount: $correctCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPracticeEntriesTable extends LocalPracticeEntries
    with TableInfo<$LocalPracticeEntriesTable, StoredPracticeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPracticeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    dataJson,
    createdAt,
    updatedAt,
    done,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_practice_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredPracticeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredPracticeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredPracticeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
    );
  }

  @override
  $LocalPracticeEntriesTable createAlias(String alias) {
    return $LocalPracticeEntriesTable(attachedDatabase, alias);
  }
}

class StoredPracticeEntry extends DataClass
    implements Insertable<StoredPracticeEntry> {
  final String id;
  final String kind;
  final String dataJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool done;
  const StoredPracticeEntry({
    required this.id,
    required this.kind,
    required this.dataJson,
    required this.createdAt,
    required this.updatedAt,
    required this.done,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['data_json'] = Variable<String>(dataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['done'] = Variable<bool>(done);
    return map;
  }

  LocalPracticeEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalPracticeEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      dataJson: Value(dataJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      done: Value(done),
    );
  }

  factory StoredPracticeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredPracticeEntry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      done: serializer.fromJson<bool>(json['done']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'dataJson': serializer.toJson<String>(dataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'done': serializer.toJson<bool>(done),
    };
  }

  StoredPracticeEntry copyWith({
    String? id,
    String? kind,
    String? dataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? done,
  }) => StoredPracticeEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    dataJson: dataJson ?? this.dataJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    done: done ?? this.done,
  );
  StoredPracticeEntry copyWithCompanion(LocalPracticeEntriesCompanion data) {
    return StoredPracticeEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      done: data.done.present ? data.done.value : this.done,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredPracticeEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, dataJson, createdAt, updatedAt, done);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredPracticeEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.dataJson == this.dataJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.done == this.done);
}

class LocalPracticeEntriesCompanion
    extends UpdateCompanion<StoredPracticeEntry> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> dataJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> done;
  final Value<int> rowid;
  const LocalPracticeEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPracticeEntriesCompanion.insert({
    required String id,
    required String kind,
    required String dataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       dataJson = Value(dataJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredPracticeEntry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? dataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? done,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (dataJson != null) 'data_json': dataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (done != null) 'done': done,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPracticeEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? dataJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? done,
    Value<int>? rowid,
  }) {
    return LocalPracticeEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      dataJson: dataJson ?? this.dataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      done: done ?? this.done,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPracticeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('done: $done, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMediaTable extends LocalMedia
    with TableInfo<$LocalMediaTable, StoredMedia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMediaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, mime, bytes, checksum, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredMedia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredMedia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredMedia(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalMediaTable createAlias(String alias) {
    return $LocalMediaTable(attachedDatabase, alias);
  }
}

class StoredMedia extends DataClass implements Insertable<StoredMedia> {
  final String id;
  final String mime;
  final Uint8List bytes;
  final String checksum;
  final DateTime createdAt;
  const StoredMedia({
    required this.id,
    required this.mime,
    required this.bytes,
    required this.checksum,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mime'] = Variable<String>(mime);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['checksum'] = Variable<String>(checksum);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalMediaCompanion toCompanion(bool nullToAbsent) {
    return LocalMediaCompanion(
      id: Value(id),
      mime: Value(mime),
      bytes: Value(bytes),
      checksum: Value(checksum),
      createdAt: Value(createdAt),
    );
  }

  factory StoredMedia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredMedia(
      id: serializer.fromJson<String>(json['id']),
      mime: serializer.fromJson<String>(json['mime']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      checksum: serializer.fromJson<String>(json['checksum']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mime': serializer.toJson<String>(mime),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'checksum': serializer.toJson<String>(checksum),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StoredMedia copyWith({
    String? id,
    String? mime,
    Uint8List? bytes,
    String? checksum,
    DateTime? createdAt,
  }) => StoredMedia(
    id: id ?? this.id,
    mime: mime ?? this.mime,
    bytes: bytes ?? this.bytes,
    checksum: checksum ?? this.checksum,
    createdAt: createdAt ?? this.createdAt,
  );
  StoredMedia copyWithCompanion(LocalMediaCompanion data) {
    return StoredMedia(
      id: data.id.present ? data.id.value : this.id,
      mime: data.mime.present ? data.mime.value : this.mime,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredMedia(')
          ..write('id: $id, ')
          ..write('mime: $mime, ')
          ..write('bytes: $bytes, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mime,
    $driftBlobEquality.hash(bytes),
    checksum,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredMedia &&
          other.id == this.id &&
          other.mime == this.mime &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.checksum == this.checksum &&
          other.createdAt == this.createdAt);
}

class LocalMediaCompanion extends UpdateCompanion<StoredMedia> {
  final Value<String> id;
  final Value<String> mime;
  final Value<Uint8List> bytes;
  final Value<String> checksum;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalMediaCompanion({
    this.id = const Value.absent(),
    this.mime = const Value.absent(),
    this.bytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMediaCompanion.insert({
    required String id,
    required String mime,
    required Uint8List bytes,
    required String checksum,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mime = Value(mime),
       bytes = Value(bytes),
       checksum = Value(checksum),
       createdAt = Value(createdAt);
  static Insertable<StoredMedia> custom({
    Expression<String>? id,
    Expression<String>? mime,
    Expression<Uint8List>? bytes,
    Expression<String>? checksum,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mime != null) 'mime': mime,
      if (bytes != null) 'bytes': bytes,
      if (checksum != null) 'checksum': checksum,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMediaCompanion copyWith({
    Value<String>? id,
    Value<String>? mime,
    Value<Uint8List>? bytes,
    Value<String>? checksum,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalMediaCompanion(
      id: id ?? this.id,
      mime: mime ?? this.mime,
      bytes: bytes ?? this.bytes,
      checksum: checksum ?? this.checksum,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMediaCompanion(')
          ..write('id: $id, ')
          ..write('mime: $mime, ')
          ..write('bytes: $bytes, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFeedbackReportsTable extends LocalFeedbackReports
    with TableInfo<$LocalFeedbackReportsTable, LocalFeedbackReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFeedbackReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    revision,
    dataJson,
    state,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_feedback_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFeedbackReport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, revision};
  @override
  LocalFeedbackReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFeedbackReport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalFeedbackReportsTable createAlias(String alias) {
    return $LocalFeedbackReportsTable(attachedDatabase, alias);
  }
}

class LocalFeedbackReport extends DataClass
    implements Insertable<LocalFeedbackReport> {
  final String id;
  final int revision;
  final String dataJson;
  final String state;
  final DateTime updatedAt;
  const LocalFeedbackReport({
    required this.id,
    required this.revision,
    required this.dataJson,
    required this.state,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['revision'] = Variable<int>(revision);
    map['data_json'] = Variable<String>(dataJson);
    map['state'] = Variable<String>(state);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalFeedbackReportsCompanion toCompanion(bool nullToAbsent) {
    return LocalFeedbackReportsCompanion(
      id: Value(id),
      revision: Value(revision),
      dataJson: Value(dataJson),
      state: Value(state),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalFeedbackReport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFeedbackReport(
      id: serializer.fromJson<String>(json['id']),
      revision: serializer.fromJson<int>(json['revision']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      state: serializer.fromJson<String>(json['state']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'revision': serializer.toJson<int>(revision),
      'dataJson': serializer.toJson<String>(dataJson),
      'state': serializer.toJson<String>(state),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalFeedbackReport copyWith({
    String? id,
    int? revision,
    String? dataJson,
    String? state,
    DateTime? updatedAt,
  }) => LocalFeedbackReport(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    dataJson: dataJson ?? this.dataJson,
    state: state ?? this.state,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalFeedbackReport copyWithCompanion(LocalFeedbackReportsCompanion data) {
    return LocalFeedbackReport(
      id: data.id.present ? data.id.value : this.id,
      revision: data.revision.present ? data.revision.value : this.revision,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      state: data.state.present ? data.state.value : this.state,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFeedbackReport(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('dataJson: $dataJson, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, revision, dataJson, state, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFeedbackReport &&
          other.id == this.id &&
          other.revision == this.revision &&
          other.dataJson == this.dataJson &&
          other.state == this.state &&
          other.updatedAt == this.updatedAt);
}

class LocalFeedbackReportsCompanion
    extends UpdateCompanion<LocalFeedbackReport> {
  final Value<String> id;
  final Value<int> revision;
  final Value<String> dataJson;
  final Value<String> state;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalFeedbackReportsCompanion({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.state = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFeedbackReportsCompanion.insert({
    required String id,
    required int revision,
    required String dataJson,
    required String state,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       revision = Value(revision),
       dataJson = Value(dataJson),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFeedbackReport> custom({
    Expression<String>? id,
    Expression<int>? revision,
    Expression<String>? dataJson,
    Expression<String>? state,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (revision != null) 'revision': revision,
      if (dataJson != null) 'data_json': dataJson,
      if (state != null) 'state': state,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFeedbackReportsCompanion copyWith({
    Value<String>? id,
    Value<int>? revision,
    Value<String>? dataJson,
    Value<String>? state,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalFeedbackReportsCompanion(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      dataJson: dataJson ?? this.dataJson,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFeedbackReportsCompanion(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('dataJson: $dataJson, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAdminRevisionsTable extends LocalAdminRevisions
    with TableInfo<$LocalAdminRevisionsTable, LocalAdminRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAdminRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportedMeta = const VerificationMeta(
    'exported',
  );
  @override
  late final GeneratedColumn<bool> exported = GeneratedColumn<bool>(
    'exported',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exported" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    revision,
    kind,
    dataJson,
    state,
    exported,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_admin_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAdminRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('exported')) {
      context.handle(
        _exportedMeta,
        exported.isAcceptableOrUnknown(data['exported']!, _exportedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, revision};
  @override
  LocalAdminRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAdminRevision(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      exported: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exported'],
      )!,
    );
  }

  @override
  $LocalAdminRevisionsTable createAlias(String alias) {
    return $LocalAdminRevisionsTable(attachedDatabase, alias);
  }
}

class LocalAdminRevision extends DataClass
    implements Insertable<LocalAdminRevision> {
  final String itemId;
  final int revision;
  final String kind;
  final String dataJson;
  final String state;
  final bool exported;
  const LocalAdminRevision({
    required this.itemId,
    required this.revision,
    required this.kind,
    required this.dataJson,
    required this.state,
    required this.exported,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['revision'] = Variable<int>(revision);
    map['kind'] = Variable<String>(kind);
    map['data_json'] = Variable<String>(dataJson);
    map['state'] = Variable<String>(state);
    map['exported'] = Variable<bool>(exported);
    return map;
  }

  LocalAdminRevisionsCompanion toCompanion(bool nullToAbsent) {
    return LocalAdminRevisionsCompanion(
      itemId: Value(itemId),
      revision: Value(revision),
      kind: Value(kind),
      dataJson: Value(dataJson),
      state: Value(state),
      exported: Value(exported),
    );
  }

  factory LocalAdminRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAdminRevision(
      itemId: serializer.fromJson<String>(json['itemId']),
      revision: serializer.fromJson<int>(json['revision']),
      kind: serializer.fromJson<String>(json['kind']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      state: serializer.fromJson<String>(json['state']),
      exported: serializer.fromJson<bool>(json['exported']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'revision': serializer.toJson<int>(revision),
      'kind': serializer.toJson<String>(kind),
      'dataJson': serializer.toJson<String>(dataJson),
      'state': serializer.toJson<String>(state),
      'exported': serializer.toJson<bool>(exported),
    };
  }

  LocalAdminRevision copyWith({
    String? itemId,
    int? revision,
    String? kind,
    String? dataJson,
    String? state,
    bool? exported,
  }) => LocalAdminRevision(
    itemId: itemId ?? this.itemId,
    revision: revision ?? this.revision,
    kind: kind ?? this.kind,
    dataJson: dataJson ?? this.dataJson,
    state: state ?? this.state,
    exported: exported ?? this.exported,
  );
  LocalAdminRevision copyWithCompanion(LocalAdminRevisionsCompanion data) {
    return LocalAdminRevision(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      revision: data.revision.present ? data.revision.value : this.revision,
      kind: data.kind.present ? data.kind.value : this.kind,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      state: data.state.present ? data.state.value : this.state,
      exported: data.exported.present ? data.exported.value : this.exported,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminRevision(')
          ..write('itemId: $itemId, ')
          ..write('revision: $revision, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('state: $state, ')
          ..write('exported: $exported')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(itemId, revision, kind, dataJson, state, exported);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAdminRevision &&
          other.itemId == this.itemId &&
          other.revision == this.revision &&
          other.kind == this.kind &&
          other.dataJson == this.dataJson &&
          other.state == this.state &&
          other.exported == this.exported);
}

class LocalAdminRevisionsCompanion extends UpdateCompanion<LocalAdminRevision> {
  final Value<String> itemId;
  final Value<int> revision;
  final Value<String> kind;
  final Value<String> dataJson;
  final Value<String> state;
  final Value<bool> exported;
  final Value<int> rowid;
  const LocalAdminRevisionsCompanion({
    this.itemId = const Value.absent(),
    this.revision = const Value.absent(),
    this.kind = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.state = const Value.absent(),
    this.exported = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAdminRevisionsCompanion.insert({
    required String itemId,
    required int revision,
    required String kind,
    required String dataJson,
    required String state,
    this.exported = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       revision = Value(revision),
       kind = Value(kind),
       dataJson = Value(dataJson),
       state = Value(state);
  static Insertable<LocalAdminRevision> custom({
    Expression<String>? itemId,
    Expression<int>? revision,
    Expression<String>? kind,
    Expression<String>? dataJson,
    Expression<String>? state,
    Expression<bool>? exported,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (revision != null) 'revision': revision,
      if (kind != null) 'kind': kind,
      if (dataJson != null) 'data_json': dataJson,
      if (state != null) 'state': state,
      if (exported != null) 'exported': exported,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAdminRevisionsCompanion copyWith({
    Value<String>? itemId,
    Value<int>? revision,
    Value<String>? kind,
    Value<String>? dataJson,
    Value<String>? state,
    Value<bool>? exported,
    Value<int>? rowid,
  }) {
    return LocalAdminRevisionsCompanion(
      itemId: itemId ?? this.itemId,
      revision: revision ?? this.revision,
      kind: kind ?? this.kind,
      dataJson: dataJson ?? this.dataJson,
      state: state ?? this.state,
      exported: exported ?? this.exported,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (exported.present) {
      map['exported'] = Variable<bool>(exported.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminRevisionsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('revision: $revision, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('state: $state, ')
          ..write('exported: $exported, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAdminInboxTable extends LocalAdminInbox
    with TableInfo<$LocalAdminInboxTable, LocalAdminInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAdminInboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reportIdMeta = const VerificationMeta(
    'reportId',
  );
  @override
  late final GeneratedColumn<String> reportId = GeneratedColumn<String>(
    'report_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision > 0)',
  );
  static const VerificationMeta _reportJsonMeta = const VerificationMeta(
    'reportJson',
  );
  @override
  late final GeneratedColumn<String> reportJson = GeneratedColumn<String>(
    'report_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptJsonMeta = const VerificationMeta(
    'receiptJson',
  );
  @override
  late final GeneratedColumn<String> receiptJson = GeneratedColumn<String>(
    'receipt_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    reportId,
    revision,
    reportJson,
    status,
    receiptJson,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_admin_inbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAdminInboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('report_id')) {
      context.handle(
        _reportIdMeta,
        reportId.isAcceptableOrUnknown(data['report_id']!, _reportIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reportIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('report_json')) {
      context.handle(
        _reportJsonMeta,
        reportJson.isAcceptableOrUnknown(data['report_json']!, _reportJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_reportJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('receipt_json')) {
      context.handle(
        _receiptJsonMeta,
        receiptJson.isAcceptableOrUnknown(
          data['receipt_json']!,
          _receiptJsonMeta,
        ),
      );
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reportId, revision};
  @override
  LocalAdminInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAdminInboxData(
      reportId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      reportJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      receiptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_json'],
      ),
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $LocalAdminInboxTable createAlias(String alias) {
    return $LocalAdminInboxTable(attachedDatabase, alias);
  }
}

class LocalAdminInboxData extends DataClass
    implements Insertable<LocalAdminInboxData> {
  final String reportId;
  final int revision;
  final String reportJson;
  final String status;
  final String? receiptJson;
  final DateTime receivedAt;
  const LocalAdminInboxData({
    required this.reportId,
    required this.revision,
    required this.reportJson,
    required this.status,
    this.receiptJson,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['report_id'] = Variable<String>(reportId);
    map['revision'] = Variable<int>(revision);
    map['report_json'] = Variable<String>(reportJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || receiptJson != null) {
      map['receipt_json'] = Variable<String>(receiptJson);
    }
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  LocalAdminInboxCompanion toCompanion(bool nullToAbsent) {
    return LocalAdminInboxCompanion(
      reportId: Value(reportId),
      revision: Value(revision),
      reportJson: Value(reportJson),
      status: Value(status),
      receiptJson: receiptJson == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptJson),
      receivedAt: Value(receivedAt),
    );
  }

  factory LocalAdminInboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAdminInboxData(
      reportId: serializer.fromJson<String>(json['reportId']),
      revision: serializer.fromJson<int>(json['revision']),
      reportJson: serializer.fromJson<String>(json['reportJson']),
      status: serializer.fromJson<String>(json['status']),
      receiptJson: serializer.fromJson<String?>(json['receiptJson']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reportId': serializer.toJson<String>(reportId),
      'revision': serializer.toJson<int>(revision),
      'reportJson': serializer.toJson<String>(reportJson),
      'status': serializer.toJson<String>(status),
      'receiptJson': serializer.toJson<String?>(receiptJson),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  LocalAdminInboxData copyWith({
    String? reportId,
    int? revision,
    String? reportJson,
    String? status,
    Value<String?> receiptJson = const Value.absent(),
    DateTime? receivedAt,
  }) => LocalAdminInboxData(
    reportId: reportId ?? this.reportId,
    revision: revision ?? this.revision,
    reportJson: reportJson ?? this.reportJson,
    status: status ?? this.status,
    receiptJson: receiptJson.present ? receiptJson.value : this.receiptJson,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  LocalAdminInboxData copyWithCompanion(LocalAdminInboxCompanion data) {
    return LocalAdminInboxData(
      reportId: data.reportId.present ? data.reportId.value : this.reportId,
      revision: data.revision.present ? data.revision.value : this.revision,
      reportJson: data.reportJson.present
          ? data.reportJson.value
          : this.reportJson,
      status: data.status.present ? data.status.value : this.status,
      receiptJson: data.receiptJson.present
          ? data.receiptJson.value
          : this.receiptJson,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminInboxData(')
          ..write('reportId: $reportId, ')
          ..write('revision: $revision, ')
          ..write('reportJson: $reportJson, ')
          ..write('status: $status, ')
          ..write('receiptJson: $receiptJson, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    reportId,
    revision,
    reportJson,
    status,
    receiptJson,
    receivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAdminInboxData &&
          other.reportId == this.reportId &&
          other.revision == this.revision &&
          other.reportJson == this.reportJson &&
          other.status == this.status &&
          other.receiptJson == this.receiptJson &&
          other.receivedAt == this.receivedAt);
}

class LocalAdminInboxCompanion extends UpdateCompanion<LocalAdminInboxData> {
  final Value<String> reportId;
  final Value<int> revision;
  final Value<String> reportJson;
  final Value<String> status;
  final Value<String?> receiptJson;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const LocalAdminInboxCompanion({
    this.reportId = const Value.absent(),
    this.revision = const Value.absent(),
    this.reportJson = const Value.absent(),
    this.status = const Value.absent(),
    this.receiptJson = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAdminInboxCompanion.insert({
    required String reportId,
    required int revision,
    required String reportJson,
    required String status,
    this.receiptJson = const Value.absent(),
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  }) : reportId = Value(reportId),
       revision = Value(revision),
       reportJson = Value(reportJson),
       status = Value(status),
       receivedAt = Value(receivedAt);
  static Insertable<LocalAdminInboxData> custom({
    Expression<String>? reportId,
    Expression<int>? revision,
    Expression<String>? reportJson,
    Expression<String>? status,
    Expression<String>? receiptJson,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reportId != null) 'report_id': reportId,
      if (revision != null) 'revision': revision,
      if (reportJson != null) 'report_json': reportJson,
      if (status != null) 'status': status,
      if (receiptJson != null) 'receipt_json': receiptJson,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAdminInboxCompanion copyWith({
    Value<String>? reportId,
    Value<int>? revision,
    Value<String>? reportJson,
    Value<String>? status,
    Value<String?>? receiptJson,
    Value<DateTime>? receivedAt,
    Value<int>? rowid,
  }) {
    return LocalAdminInboxCompanion(
      reportId: reportId ?? this.reportId,
      revision: revision ?? this.revision,
      reportJson: reportJson ?? this.reportJson,
      status: status ?? this.status,
      receiptJson: receiptJson ?? this.receiptJson,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reportId.present) {
      map['report_id'] = Variable<String>(reportId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (reportJson.present) {
      map['report_json'] = Variable<String>(reportJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (receiptJson.present) {
      map['receipt_json'] = Variable<String>(receiptJson.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminInboxCompanion(')
          ..write('reportId: $reportId, ')
          ..write('revision: $revision, ')
          ..write('reportJson: $reportJson, ')
          ..write('status: $status, ')
          ..write('receiptJson: $receiptJson, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAdminPackagesTable extends LocalAdminPackages
    with TableInfo<$LocalAdminPackagesTable, LocalAdminPackage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAdminPackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version > 0)',
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [packageId, version, bytes, checksum];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_admin_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAdminPackage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageId, version};
  @override
  LocalAdminPackage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAdminPackage(
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
    );
  }

  @override
  $LocalAdminPackagesTable createAlias(String alias) {
    return $LocalAdminPackagesTable(attachedDatabase, alias);
  }
}

class LocalAdminPackage extends DataClass
    implements Insertable<LocalAdminPackage> {
  final String packageId;
  final int version;
  final Uint8List bytes;
  final String checksum;
  const LocalAdminPackage({
    required this.packageId,
    required this.version,
    required this.bytes,
    required this.checksum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package_id'] = Variable<String>(packageId);
    map['version'] = Variable<int>(version);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['checksum'] = Variable<String>(checksum);
    return map;
  }

  LocalAdminPackagesCompanion toCompanion(bool nullToAbsent) {
    return LocalAdminPackagesCompanion(
      packageId: Value(packageId),
      version: Value(version),
      bytes: Value(bytes),
      checksum: Value(checksum),
    );
  }

  factory LocalAdminPackage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAdminPackage(
      packageId: serializer.fromJson<String>(json['packageId']),
      version: serializer.fromJson<int>(json['version']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      checksum: serializer.fromJson<String>(json['checksum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packageId': serializer.toJson<String>(packageId),
      'version': serializer.toJson<int>(version),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'checksum': serializer.toJson<String>(checksum),
    };
  }

  LocalAdminPackage copyWith({
    String? packageId,
    int? version,
    Uint8List? bytes,
    String? checksum,
  }) => LocalAdminPackage(
    packageId: packageId ?? this.packageId,
    version: version ?? this.version,
    bytes: bytes ?? this.bytes,
    checksum: checksum ?? this.checksum,
  );
  LocalAdminPackage copyWithCompanion(LocalAdminPackagesCompanion data) {
    return LocalAdminPackage(
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      version: data.version.present ? data.version.value : this.version,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminPackage(')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('bytes: $bytes, ')
          ..write('checksum: $checksum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(packageId, version, $driftBlobEquality.hash(bytes), checksum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAdminPackage &&
          other.packageId == this.packageId &&
          other.version == this.version &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.checksum == this.checksum);
}

class LocalAdminPackagesCompanion extends UpdateCompanion<LocalAdminPackage> {
  final Value<String> packageId;
  final Value<int> version;
  final Value<Uint8List> bytes;
  final Value<String> checksum;
  final Value<int> rowid;
  const LocalAdminPackagesCompanion({
    this.packageId = const Value.absent(),
    this.version = const Value.absent(),
    this.bytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAdminPackagesCompanion.insert({
    required String packageId,
    required int version,
    required Uint8List bytes,
    required String checksum,
    this.rowid = const Value.absent(),
  }) : packageId = Value(packageId),
       version = Value(version),
       bytes = Value(bytes),
       checksum = Value(checksum);
  static Insertable<LocalAdminPackage> custom({
    Expression<String>? packageId,
    Expression<int>? version,
    Expression<Uint8List>? bytes,
    Expression<String>? checksum,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageId != null) 'package_id': packageId,
      if (version != null) 'version': version,
      if (bytes != null) 'bytes': bytes,
      if (checksum != null) 'checksum': checksum,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAdminPackagesCompanion copyWith({
    Value<String>? packageId,
    Value<int>? version,
    Value<Uint8List>? bytes,
    Value<String>? checksum,
    Value<int>? rowid,
  }) {
    return LocalAdminPackagesCompanion(
      packageId: packageId ?? this.packageId,
      version: version ?? this.version,
      bytes: bytes ?? this.bytes,
      checksum: checksum ?? this.checksum,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAdminPackagesCompanion(')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('bytes: $bytes, ')
          ..write('checksum: $checksum, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalInstalledPackagesTable extends LocalInstalledPackages
    with TableInfo<$LocalInstalledPackagesTable, LocalInstalledPackage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInstalledPackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publisherIdMeta = const VerificationMeta(
    'publisherId',
  );
  @override
  late final GeneratedColumn<String> publisherId = GeneratedColumn<String>(
    'publisher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version > 0)',
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    packageId,
    publisherId,
    version,
    dataJson,
    checksum,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_installed_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalInstalledPackage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('publisher_id')) {
      context.handle(
        _publisherIdMeta,
        publisherId.isAcceptableOrUnknown(
          data['publisher_id']!,
          _publisherIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publisherIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageId};
  @override
  LocalInstalledPackage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInstalledPackage(
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      publisherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
    );
  }

  @override
  $LocalInstalledPackagesTable createAlias(String alias) {
    return $LocalInstalledPackagesTable(attachedDatabase, alias);
  }
}

class LocalInstalledPackage extends DataClass
    implements Insertable<LocalInstalledPackage> {
  final String packageId;
  final String publisherId;
  final int version;
  final String dataJson;
  final String checksum;
  const LocalInstalledPackage({
    required this.packageId,
    required this.publisherId,
    required this.version,
    required this.dataJson,
    required this.checksum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package_id'] = Variable<String>(packageId);
    map['publisher_id'] = Variable<String>(publisherId);
    map['version'] = Variable<int>(version);
    map['data_json'] = Variable<String>(dataJson);
    map['checksum'] = Variable<String>(checksum);
    return map;
  }

  LocalInstalledPackagesCompanion toCompanion(bool nullToAbsent) {
    return LocalInstalledPackagesCompanion(
      packageId: Value(packageId),
      publisherId: Value(publisherId),
      version: Value(version),
      dataJson: Value(dataJson),
      checksum: Value(checksum),
    );
  }

  factory LocalInstalledPackage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInstalledPackage(
      packageId: serializer.fromJson<String>(json['packageId']),
      publisherId: serializer.fromJson<String>(json['publisherId']),
      version: serializer.fromJson<int>(json['version']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      checksum: serializer.fromJson<String>(json['checksum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packageId': serializer.toJson<String>(packageId),
      'publisherId': serializer.toJson<String>(publisherId),
      'version': serializer.toJson<int>(version),
      'dataJson': serializer.toJson<String>(dataJson),
      'checksum': serializer.toJson<String>(checksum),
    };
  }

  LocalInstalledPackage copyWith({
    String? packageId,
    String? publisherId,
    int? version,
    String? dataJson,
    String? checksum,
  }) => LocalInstalledPackage(
    packageId: packageId ?? this.packageId,
    publisherId: publisherId ?? this.publisherId,
    version: version ?? this.version,
    dataJson: dataJson ?? this.dataJson,
    checksum: checksum ?? this.checksum,
  );
  LocalInstalledPackage copyWithCompanion(
    LocalInstalledPackagesCompanion data,
  ) {
    return LocalInstalledPackage(
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      publisherId: data.publisherId.present
          ? data.publisherId.value
          : this.publisherId,
      version: data.version.present ? data.version.value : this.version,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInstalledPackage(')
          ..write('packageId: $packageId, ')
          ..write('publisherId: $publisherId, ')
          ..write('version: $version, ')
          ..write('dataJson: $dataJson, ')
          ..write('checksum: $checksum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(packageId, publisherId, version, dataJson, checksum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInstalledPackage &&
          other.packageId == this.packageId &&
          other.publisherId == this.publisherId &&
          other.version == this.version &&
          other.dataJson == this.dataJson &&
          other.checksum == this.checksum);
}

class LocalInstalledPackagesCompanion
    extends UpdateCompanion<LocalInstalledPackage> {
  final Value<String> packageId;
  final Value<String> publisherId;
  final Value<int> version;
  final Value<String> dataJson;
  final Value<String> checksum;
  final Value<int> rowid;
  const LocalInstalledPackagesCompanion({
    this.packageId = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.version = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.checksum = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInstalledPackagesCompanion.insert({
    required String packageId,
    required String publisherId,
    required int version,
    required String dataJson,
    required String checksum,
    this.rowid = const Value.absent(),
  }) : packageId = Value(packageId),
       publisherId = Value(publisherId),
       version = Value(version),
       dataJson = Value(dataJson),
       checksum = Value(checksum);
  static Insertable<LocalInstalledPackage> custom({
    Expression<String>? packageId,
    Expression<String>? publisherId,
    Expression<int>? version,
    Expression<String>? dataJson,
    Expression<String>? checksum,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageId != null) 'package_id': packageId,
      if (publisherId != null) 'publisher_id': publisherId,
      if (version != null) 'version': version,
      if (dataJson != null) 'data_json': dataJson,
      if (checksum != null) 'checksum': checksum,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInstalledPackagesCompanion copyWith({
    Value<String>? packageId,
    Value<String>? publisherId,
    Value<int>? version,
    Value<String>? dataJson,
    Value<String>? checksum,
    Value<int>? rowid,
  }) {
    return LocalInstalledPackagesCompanion(
      packageId: packageId ?? this.packageId,
      publisherId: publisherId ?? this.publisherId,
      version: version ?? this.version,
      dataJson: dataJson ?? this.dataJson,
      checksum: checksum ?? this.checksum,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (publisherId.present) {
      map['publisher_id'] = Variable<String>(publisherId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalInstalledPackagesCompanion(')
          ..write('packageId: $packageId, ')
          ..write('publisherId: $publisherId, ')
          ..write('version: $version, ')
          ..write('dataJson: $dataJson, ')
          ..write('checksum: $checksum, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCatalogReceiptsTable extends LocalCatalogReceipts
    with TableInfo<$LocalCatalogReceiptsTable, LocalCatalogReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCatalogReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _publisherIdMeta = const VerificationMeta(
    'publisherId',
  );
  @override
  late final GeneratedColumn<String> publisherId = GeneratedColumn<String>(
    'publisher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (version > 0)',
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    publisherId,
    packageId,
    version,
    checksum,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_catalog_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCatalogReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('publisher_id')) {
      context.handle(
        _publisherIdMeta,
        publisherId.isAcceptableOrUnknown(
          data['publisher_id']!,
          _publisherIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publisherIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {publisherId, packageId, version};
  @override
  LocalCatalogReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCatalogReceipt(
      publisherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
    );
  }

  @override
  $LocalCatalogReceiptsTable createAlias(String alias) {
    return $LocalCatalogReceiptsTable(attachedDatabase, alias);
  }
}

class LocalCatalogReceipt extends DataClass
    implements Insertable<LocalCatalogReceipt> {
  final String publisherId;
  final String packageId;
  final int version;
  final String checksum;
  const LocalCatalogReceipt({
    required this.publisherId,
    required this.packageId,
    required this.version,
    required this.checksum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['publisher_id'] = Variable<String>(publisherId);
    map['package_id'] = Variable<String>(packageId);
    map['version'] = Variable<int>(version);
    map['checksum'] = Variable<String>(checksum);
    return map;
  }

  LocalCatalogReceiptsCompanion toCompanion(bool nullToAbsent) {
    return LocalCatalogReceiptsCompanion(
      publisherId: Value(publisherId),
      packageId: Value(packageId),
      version: Value(version),
      checksum: Value(checksum),
    );
  }

  factory LocalCatalogReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCatalogReceipt(
      publisherId: serializer.fromJson<String>(json['publisherId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      version: serializer.fromJson<int>(json['version']),
      checksum: serializer.fromJson<String>(json['checksum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'publisherId': serializer.toJson<String>(publisherId),
      'packageId': serializer.toJson<String>(packageId),
      'version': serializer.toJson<int>(version),
      'checksum': serializer.toJson<String>(checksum),
    };
  }

  LocalCatalogReceipt copyWith({
    String? publisherId,
    String? packageId,
    int? version,
    String? checksum,
  }) => LocalCatalogReceipt(
    publisherId: publisherId ?? this.publisherId,
    packageId: packageId ?? this.packageId,
    version: version ?? this.version,
    checksum: checksum ?? this.checksum,
  );
  LocalCatalogReceipt copyWithCompanion(LocalCatalogReceiptsCompanion data) {
    return LocalCatalogReceipt(
      publisherId: data.publisherId.present
          ? data.publisherId.value
          : this.publisherId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      version: data.version.present ? data.version.value : this.version,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCatalogReceipt(')
          ..write('publisherId: $publisherId, ')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(publisherId, packageId, version, checksum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCatalogReceipt &&
          other.publisherId == this.publisherId &&
          other.packageId == this.packageId &&
          other.version == this.version &&
          other.checksum == this.checksum);
}

class LocalCatalogReceiptsCompanion
    extends UpdateCompanion<LocalCatalogReceipt> {
  final Value<String> publisherId;
  final Value<String> packageId;
  final Value<int> version;
  final Value<String> checksum;
  final Value<int> rowid;
  const LocalCatalogReceiptsCompanion({
    this.publisherId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.version = const Value.absent(),
    this.checksum = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCatalogReceiptsCompanion.insert({
    required String publisherId,
    required String packageId,
    required int version,
    required String checksum,
    this.rowid = const Value.absent(),
  }) : publisherId = Value(publisherId),
       packageId = Value(packageId),
       version = Value(version),
       checksum = Value(checksum);
  static Insertable<LocalCatalogReceipt> custom({
    Expression<String>? publisherId,
    Expression<String>? packageId,
    Expression<int>? version,
    Expression<String>? checksum,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (publisherId != null) 'publisher_id': publisherId,
      if (packageId != null) 'package_id': packageId,
      if (version != null) 'version': version,
      if (checksum != null) 'checksum': checksum,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCatalogReceiptsCompanion copyWith({
    Value<String>? publisherId,
    Value<String>? packageId,
    Value<int>? version,
    Value<String>? checksum,
    Value<int>? rowid,
  }) {
    return LocalCatalogReceiptsCompanion(
      publisherId: publisherId ?? this.publisherId,
      packageId: packageId ?? this.packageId,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (publisherId.present) {
      map['publisher_id'] = Variable<String>(publisherId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCatalogReceiptsCompanion(')
          ..write('publisherId: $publisherId, ')
          ..write('packageId: $packageId, ')
          ..write('version: $version, ')
          ..write('checksum: $checksum, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $LocalWordsTable localWords = $LocalWordsTable(this);
  late final $LocalMetadataTable localMetadata = $LocalMetadataTable(this);
  late final $LocalReceiptsTable localReceipts = $LocalReceiptsTable(this);
  late final $LocalSchedulesTable localSchedules = $LocalSchedulesTable(this);
  late final $LocalReviewSessionsTable localReviewSessions =
      $LocalReviewSessionsTable(this);
  late final $LocalReviewEventsTable localReviewEvents =
      $LocalReviewEventsTable(this);
  late final $LocalExamAttemptsTable localExamAttempts =
      $LocalExamAttemptsTable(this);
  late final $LocalPracticeEntriesTable localPracticeEntries =
      $LocalPracticeEntriesTable(this);
  late final $LocalMediaTable localMedia = $LocalMediaTable(this);
  late final $LocalFeedbackReportsTable localFeedbackReports =
      $LocalFeedbackReportsTable(this);
  late final $LocalAdminRevisionsTable localAdminRevisions =
      $LocalAdminRevisionsTable(this);
  late final $LocalAdminInboxTable localAdminInbox = $LocalAdminInboxTable(
    this,
  );
  late final $LocalAdminPackagesTable localAdminPackages =
      $LocalAdminPackagesTable(this);
  late final $LocalInstalledPackagesTable localInstalledPackages =
      $LocalInstalledPackagesTable(this);
  late final $LocalCatalogReceiptsTable localCatalogReceipts =
      $LocalCatalogReceiptsTable(this);
  late final Index localAdminCurrentPublished = Index(
    'local_admin_current_published',
    'CREATE UNIQUE INDEX local_admin_current_published ON local_admin_revisions (item_id) WHERE state = \'published\'',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localWords,
    localMetadata,
    localReceipts,
    localSchedules,
    localReviewSessions,
    localReviewEvents,
    localExamAttempts,
    localPracticeEntries,
    localMedia,
    localFeedbackReports,
    localAdminRevisions,
    localAdminInbox,
    localAdminPackages,
    localInstalledPackages,
    localCatalogReceipts,
    localAdminCurrentPublished,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_words',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_schedules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_review_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_review_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalWordsTableCreateCompanionBuilder = LocalWordsCompanion Function({
  required String id,
  required String hanzi,
  required String pinyin,
  required String meaning,
  Value<String> exampleHanzi,
  Value<String> exampleVietnamese,
  required bool personal,
  Value<bool> saved,
  Value<String> note,
  Value<int> rowid,
});
typedef $$LocalWordsTableUpdateCompanionBuilder = LocalWordsCompanion Function({
  Value<String> id,
  Value<String> hanzi,
  Value<String> pinyin,
  Value<String> meaning,
  Value<String> exampleHanzi,
  Value<String> exampleVietnamese,
  Value<bool> personal,
  Value<bool> saved,
  Value<String> note,
  Value<int> rowid,
});

final class $$LocalWordsTableReferences
    extends BaseReferences<_$LocalDatabase, $LocalWordsTable, StoredWord> {
  $$LocalWordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalSchedulesTable, List<StoredSchedule>>
  _localSchedulesRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.localSchedules,
    aliasName: 'local_words__id__local_schedules__word_id',
  );

  $$LocalSchedulesTableProcessedTableManager get localSchedulesRefs {
    final manager = $$LocalSchedulesTableTableManager(
      $_db,
      $_db.localSchedules,
    ).filter((f) => f.wordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localSchedulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalWordsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalWordsTable> {
  $$LocalWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hanzi => $composableBuilder(
    column: $table.hanzi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinyin => $composableBuilder(
    column: $table.pinyin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleHanzi => $composableBuilder(
    column: $table.exampleHanzi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleVietnamese => $composableBuilder(
    column: $table.exampleVietnamese,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get personal => $composableBuilder(
    column: $table.personal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localSchedulesRefs(
    Expression<bool> Function($$LocalSchedulesTableFilterComposer f) f,
  ) {
    final $$LocalSchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSchedules,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSchedulesTableFilterComposer(
            $db: $db,
            $table: $db.localSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalWordsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalWordsTable> {
  $$LocalWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hanzi => $composableBuilder(
    column: $table.hanzi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinyin => $composableBuilder(
    column: $table.pinyin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleHanzi => $composableBuilder(
    column: $table.exampleHanzi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleVietnamese => $composableBuilder(
    column: $table.exampleVietnamese,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get personal => $composableBuilder(
    column: $table.personal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWordsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalWordsTable> {
  $$LocalWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hanzi =>
      $composableBuilder(column: $table.hanzi, builder: (column) => column);

  GeneratedColumn<String> get pinyin =>
      $composableBuilder(column: $table.pinyin, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get exampleHanzi => $composableBuilder(
    column: $table.exampleHanzi,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exampleVietnamese => $composableBuilder(
    column: $table.exampleVietnamese,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get personal =>
      $composableBuilder(column: $table.personal, builder: (column) => column);

  GeneratedColumn<bool> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> localSchedulesRefs<T extends Object>(
    Expression<T> Function($$LocalSchedulesTableAnnotationComposer a) f,
  ) {
    final $$LocalSchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSchedules,
      getReferencedColumn: (t) => t.wordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.localSchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalWordsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalWordsTable,
          StoredWord,
          $$LocalWordsTableFilterComposer,
          $$LocalWordsTableOrderingComposer,
          $$LocalWordsTableAnnotationComposer,
          $$LocalWordsTableCreateCompanionBuilder,
          $$LocalWordsTableUpdateCompanionBuilder,
          (StoredWord, $$LocalWordsTableReferences),
          StoredWord,
          PrefetchHooks Function({bool localSchedulesRefs})
        > {
  $$LocalWordsTableTableManager(_$LocalDatabase db, $LocalWordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hanzi = const Value.absent(),
                Value<String> pinyin = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String> exampleHanzi = const Value.absent(),
                Value<String> exampleVietnamese = const Value.absent(),
                Value<bool> personal = const Value.absent(),
                Value<bool> saved = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWordsCompanion(
                id: id,
                hanzi: hanzi,
                pinyin: pinyin,
                meaning: meaning,
                exampleHanzi: exampleHanzi,
                exampleVietnamese: exampleVietnamese,
                personal: personal,
                saved: saved,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String hanzi,
                required String pinyin,
                required String meaning,
                Value<String> exampleHanzi = const Value.absent(),
                Value<String> exampleVietnamese = const Value.absent(),
                required bool personal,
                Value<bool> saved = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWordsCompanion.insert(
                id: id,
                hanzi: hanzi,
                pinyin: pinyin,
                meaning: meaning,
                exampleHanzi: exampleHanzi,
                exampleVietnamese: exampleVietnamese,
                personal: personal,
                saved: saved,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalWordsTable, StoredWord>(table),
                  $$LocalWordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localSchedulesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localSchedulesRefs) db.localSchedules,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localSchedulesRefs)
                    await $_getPrefetchedDataByColumns<
                      StoredWord,
                      $LocalWordsTable,
                      StoredSchedule,
                      $LocalSchedulesTable
                    >(
                      currentTable: table,
                      referencedTable: $$LocalWordsTableReferences
                          ._localSchedulesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalWordsTableReferences(
                            db,
                            table,
                            p0,
                          ).localSchedulesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'word_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalWordsTable,
      StoredWord,
      $$LocalWordsTableFilterComposer,
      $$LocalWordsTableOrderingComposer,
      $$LocalWordsTableAnnotationComposer,
      $$LocalWordsTableCreateCompanionBuilder,
      $$LocalWordsTableUpdateCompanionBuilder,
      (StoredWord, $$LocalWordsTableReferences),
      StoredWord,
      PrefetchHooks Function({bool localSchedulesRefs})
    >;
typedef $$LocalMetadataTableCreateCompanionBuilder =
    LocalMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalMetadataTableUpdateCompanionBuilder =
    LocalMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalMetadataTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalMetadataTable> {
  $$LocalMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMetadataTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalMetadataTable> {
  $$LocalMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMetadataTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalMetadataTable> {
  $$LocalMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalMetadataTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalMetadataTable,
          LocalMetadataData,
          $$LocalMetadataTableFilterComposer,
          $$LocalMetadataTableOrderingComposer,
          $$LocalMetadataTableAnnotationComposer,
          $$LocalMetadataTableCreateCompanionBuilder,
          $$LocalMetadataTableUpdateCompanionBuilder,
          (
            LocalMetadataData,
            BaseReferences<
              _$LocalDatabase,
              $LocalMetadataTable,
              LocalMetadataData
            >,
          ),
          LocalMetadataData,
          PrefetchHooks Function()
        > {
  $$LocalMetadataTableTableManager(
    _$LocalDatabase db,
    $LocalMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMetadataTable, LocalMetadataData>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalMetadataTable,
                    LocalMetadataData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalMetadataTable,
      LocalMetadataData,
      $$LocalMetadataTableFilterComposer,
      $$LocalMetadataTableOrderingComposer,
      $$LocalMetadataTableAnnotationComposer,
      $$LocalMetadataTableCreateCompanionBuilder,
      $$LocalMetadataTableUpdateCompanionBuilder,
      (
        LocalMetadataData,
        BaseReferences<_$LocalDatabase, $LocalMetadataTable, LocalMetadataData>,
      ),
      LocalMetadataData,
      PrefetchHooks Function()
    >;
typedef $$LocalReceiptsTableCreateCompanionBuilder =
    LocalReceiptsCompanion Function({
      required String operationId,
      required String fingerprint,
      Value<int> rowid,
    });
typedef $$LocalReceiptsTableUpdateCompanionBuilder =
    LocalReceiptsCompanion Function({
      Value<String> operationId,
      Value<String> fingerprint,
      Value<int> rowid,
    });

class $$LocalReceiptsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalReceiptsTable> {
  $$LocalReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalReceiptsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalReceiptsTable> {
  $$LocalReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalReceiptsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalReceiptsTable> {
  $$LocalReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );
}

class $$LocalReceiptsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalReceiptsTable,
          LocalReceipt,
          $$LocalReceiptsTableFilterComposer,
          $$LocalReceiptsTableOrderingComposer,
          $$LocalReceiptsTableAnnotationComposer,
          $$LocalReceiptsTableCreateCompanionBuilder,
          $$LocalReceiptsTableUpdateCompanionBuilder,
          (
            LocalReceipt,
            BaseReferences<_$LocalDatabase, $LocalReceiptsTable, LocalReceipt>,
          ),
          LocalReceipt,
          PrefetchHooks Function()
        > {
  $$LocalReceiptsTableTableManager(
    _$LocalDatabase db,
    $LocalReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReceiptsCompanion(
                operationId: operationId,
                fingerprint: fingerprint,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String fingerprint,
                Value<int> rowid = const Value.absent(),
              }) => LocalReceiptsCompanion.insert(
                operationId: operationId,
                fingerprint: fingerprint,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalReceiptsTable, LocalReceipt>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalReceiptsTable,
                    LocalReceipt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalReceiptsTable,
      LocalReceipt,
      $$LocalReceiptsTableFilterComposer,
      $$LocalReceiptsTableOrderingComposer,
      $$LocalReceiptsTableAnnotationComposer,
      $$LocalReceiptsTableCreateCompanionBuilder,
      $$LocalReceiptsTableUpdateCompanionBuilder,
      (
        LocalReceipt,
        BaseReferences<_$LocalDatabase, $LocalReceiptsTable, LocalReceipt>,
      ),
      LocalReceipt,
      PrefetchHooks Function()
    >;
typedef $$LocalSchedulesTableCreateCompanionBuilder =
    LocalSchedulesCompanion Function({
      required String wordId,
      Value<int> repetitions,
      Value<int> intervalDays,
      Value<double> ease,
      required DateTime dueAt,
      Value<bool> active,
      Value<int> rowid,
    });
typedef $$LocalSchedulesTableUpdateCompanionBuilder =
    LocalSchedulesCompanion Function({
      Value<String> wordId,
      Value<int> repetitions,
      Value<int> intervalDays,
      Value<double> ease,
      Value<DateTime> dueAt,
      Value<bool> active,
      Value<int> rowid,
    });

final class $$LocalSchedulesTableReferences
    extends
        BaseReferences<_$LocalDatabase, $LocalSchedulesTable, StoredSchedule> {
  $$LocalSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalWordsTable _wordIdTable(_$LocalDatabase db) =>
      db.localWords.createAlias('local_schedules__word_id__local_words__id');

  $$LocalWordsTableProcessedTableManager get wordId {
    final $_column = $_itemColumn<String>('word_id')!;

    final manager = $$LocalWordsTableTableManager(
      $_db,
      $_db.localWords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalSchedulesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalWordsTableFilterComposer get wordId {
    final $$LocalWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.localWords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalWordsTableFilterComposer(
            $db: $db,
            $table: $db.localWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSchedulesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalWordsTableOrderingComposer get wordId {
    final $$LocalWordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.localWords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalWordsTableOrderingComposer(
            $db: $db,
            $table: $db.localWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSchedulesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalSchedulesTable> {
  $$LocalSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ease =>
      $composableBuilder(column: $table.ease, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  $$LocalWordsTableAnnotationComposer get wordId {
    final $$LocalWordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wordId,
      referencedTable: $db.localWords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalWordsTableAnnotationComposer(
            $db: $db,
            $table: $db.localWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSchedulesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalSchedulesTable,
          StoredSchedule,
          $$LocalSchedulesTableFilterComposer,
          $$LocalSchedulesTableOrderingComposer,
          $$LocalSchedulesTableAnnotationComposer,
          $$LocalSchedulesTableCreateCompanionBuilder,
          $$LocalSchedulesTableUpdateCompanionBuilder,
          (StoredSchedule, $$LocalSchedulesTableReferences),
          StoredSchedule,
          PrefetchHooks Function({bool wordId})
        > {
  $$LocalSchedulesTableTableManager(
    _$LocalDatabase db,
    $LocalSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSchedulesCompanion(
                wordId: wordId,
                repetitions: repetitions,
                intervalDays: intervalDays,
                ease: ease,
                dueAt: dueAt,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                Value<int> repetitions = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<double> ease = const Value.absent(),
                required DateTime dueAt,
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSchedulesCompanion.insert(
                wordId: wordId,
                repetitions: repetitions,
                intervalDays: intervalDays,
                ease: ease,
                dueAt: dueAt,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSchedulesTable, StoredSchedule>(table),
                  $$LocalSchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wordId,
                        referencedTable: $$LocalSchedulesTableReferences
                            ._wordIdTable(db),
                        referencedColumn: $$LocalSchedulesTableReferences
                            ._wordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalSchedulesTable,
      StoredSchedule,
      $$LocalSchedulesTableFilterComposer,
      $$LocalSchedulesTableOrderingComposer,
      $$LocalSchedulesTableAnnotationComposer,
      $$LocalSchedulesTableCreateCompanionBuilder,
      $$LocalSchedulesTableUpdateCompanionBuilder,
      (StoredSchedule, $$LocalSchedulesTableReferences),
      StoredSchedule,
      PrefetchHooks Function({bool wordId})
    >;
typedef $$LocalReviewSessionsTableCreateCompanionBuilder =
    LocalReviewSessionsCompanion Function({
      required String id,
      required String cardsJson,
      Value<int> position,
      Value<bool> revealed,
      required DateTime createdAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });
typedef $$LocalReviewSessionsTableUpdateCompanionBuilder =
    LocalReviewSessionsCompanion Function({
      Value<String> id,
      Value<String> cardsJson,
      Value<int> position,
      Value<bool> revealed,
      Value<DateTime> createdAt,
      Value<DateTime?> finishedAt,
      Value<int> rowid,
    });

final class $$LocalReviewSessionsTableReferences
    extends
        BaseReferences<
          _$LocalDatabase,
          $LocalReviewSessionsTable,
          StoredReviewSession
        > {
  $$LocalReviewSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalReviewEventsTable, List<StoredReviewEvent>>
  _localReviewEventsRefsTable(_$LocalDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localReviewEvents,
        aliasName: 'local_review_sessions__id__local_review_events__session_id',
      );

  $$LocalReviewEventsTableProcessedTableManager get localReviewEventsRefs {
    final manager = $$LocalReviewEventsTableTableManager(
      $_db,
      $_db.localReviewEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localReviewEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalReviewSessionsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalReviewSessionsTable> {
  $$LocalReviewSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardsJson => $composableBuilder(
    column: $table.cardsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localReviewEventsRefs(
    Expression<bool> Function($$LocalReviewEventsTableFilterComposer f) f,
  ) {
    final $$LocalReviewEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localReviewEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalReviewEventsTableFilterComposer(
            $db: $db,
            $table: $db.localReviewEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalReviewSessionsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalReviewSessionsTable> {
  $$LocalReviewSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardsJson => $composableBuilder(
    column: $table.cardsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revealed => $composableBuilder(
    column: $table.revealed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalReviewSessionsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalReviewSessionsTable> {
  $$LocalReviewSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cardsJson =>
      $composableBuilder(column: $table.cardsJson, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get revealed =>
      $composableBuilder(column: $table.revealed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  Expression<T> localReviewEventsRefs<T extends Object>(
    Expression<T> Function($$LocalReviewEventsTableAnnotationComposer a) f,
  ) {
    final $$LocalReviewEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localReviewEvents,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalReviewEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.localReviewEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalReviewSessionsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalReviewSessionsTable,
          StoredReviewSession,
          $$LocalReviewSessionsTableFilterComposer,
          $$LocalReviewSessionsTableOrderingComposer,
          $$LocalReviewSessionsTableAnnotationComposer,
          $$LocalReviewSessionsTableCreateCompanionBuilder,
          $$LocalReviewSessionsTableUpdateCompanionBuilder,
          (StoredReviewSession, $$LocalReviewSessionsTableReferences),
          StoredReviewSession,
          PrefetchHooks Function({bool localReviewEventsRefs})
        > {
  $$LocalReviewSessionsTableTableManager(
    _$LocalDatabase db,
    $LocalReviewSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReviewSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReviewSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalReviewSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cardsJson = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> revealed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewSessionsCompanion(
                id: id,
                cardsJson: cardsJson,
                position: position,
                revealed: revealed,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cardsJson,
                Value<int> position = const Value.absent(),
                Value<bool> revealed = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewSessionsCompanion.insert(
                id: id,
                cardsJson: cardsJson,
                position: position,
                revealed: revealed,
                createdAt: createdAt,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalReviewSessionsTable, StoredReviewSession>(
                    table,
                  ),
                  $$LocalReviewSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localReviewEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localReviewEventsRefs) db.localReviewEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localReviewEventsRefs)
                    await $_getPrefetchedDataByColumns<
                      StoredReviewSession,
                      $LocalReviewSessionsTable,
                      StoredReviewEvent,
                      $LocalReviewEventsTable
                    >(
                      currentTable: table,
                      referencedTable: $$LocalReviewSessionsTableReferences
                          ._localReviewEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalReviewSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).localReviewEventsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'session_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalReviewSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalReviewSessionsTable,
      StoredReviewSession,
      $$LocalReviewSessionsTableFilterComposer,
      $$LocalReviewSessionsTableOrderingComposer,
      $$LocalReviewSessionsTableAnnotationComposer,
      $$LocalReviewSessionsTableCreateCompanionBuilder,
      $$LocalReviewSessionsTableUpdateCompanionBuilder,
      (StoredReviewSession, $$LocalReviewSessionsTableReferences),
      StoredReviewSession,
      PrefetchHooks Function({bool localReviewEventsRefs})
    >;
typedef $$LocalReviewEventsTableCreateCompanionBuilder =
    LocalReviewEventsCompanion Function({
      required String id,
      required String sessionId,
      required String wordId,
      required int position,
      required int quality,
      required DateTime acceptedAt,
      Value<int> rowid,
    });
typedef $$LocalReviewEventsTableUpdateCompanionBuilder =
    LocalReviewEventsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> wordId,
      Value<int> position,
      Value<int> quality,
      Value<DateTime> acceptedAt,
      Value<int> rowid,
    });

final class $$LocalReviewEventsTableReferences
    extends
        BaseReferences<
          _$LocalDatabase,
          $LocalReviewEventsTable,
          StoredReviewEvent
        > {
  $$LocalReviewEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalReviewSessionsTable _sessionIdTable(_$LocalDatabase db) =>
      db.localReviewSessions.createAlias(
        'local_review_events__session_id__local_review_sessions__id',
      );

  $$LocalReviewSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$LocalReviewSessionsTableTableManager(
      $_db,
      $_db.localReviewSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalReviewEventsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalReviewSessionsTableFilterComposer get sessionId {
    final $$LocalReviewSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.localReviewSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalReviewSessionsTableFilterComposer(
            $db: $db,
            $table: $db.localReviewSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalReviewEventsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalReviewSessionsTableOrderingComposer get sessionId {
    final $$LocalReviewSessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.localReviewSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalReviewSessionsTableOrderingComposer(
                $db: $db,
                $table: $db.localReviewSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocalReviewEventsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );

  $$LocalReviewSessionsTableAnnotationComposer get sessionId {
    final $$LocalReviewSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.localReviewSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalReviewSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.localReviewSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocalReviewEventsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalReviewEventsTable,
          StoredReviewEvent,
          $$LocalReviewEventsTableFilterComposer,
          $$LocalReviewEventsTableOrderingComposer,
          $$LocalReviewEventsTableAnnotationComposer,
          $$LocalReviewEventsTableCreateCompanionBuilder,
          $$LocalReviewEventsTableUpdateCompanionBuilder,
          (StoredReviewEvent, $$LocalReviewEventsTableReferences),
          StoredReviewEvent,
          PrefetchHooks Function({bool sessionId})
        > {
  $$LocalReviewEventsTableTableManager(
    _$LocalDatabase db,
    $LocalReviewEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReviewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReviewEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> quality = const Value.absent(),
                Value<DateTime> acceptedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewEventsCompanion(
                id: id,
                sessionId: sessionId,
                wordId: wordId,
                position: position,
                quality: quality,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String wordId,
                required int position,
                required int quality,
                required DateTime acceptedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                wordId: wordId,
                position: position,
                quality: quality,
                acceptedAt: acceptedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalReviewEventsTable, StoredReviewEvent>(
                    table,
                  ),
                  $$LocalReviewEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$LocalReviewEventsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$LocalReviewEventsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalReviewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalReviewEventsTable,
      StoredReviewEvent,
      $$LocalReviewEventsTableFilterComposer,
      $$LocalReviewEventsTableOrderingComposer,
      $$LocalReviewEventsTableAnnotationComposer,
      $$LocalReviewEventsTableCreateCompanionBuilder,
      $$LocalReviewEventsTableUpdateCompanionBuilder,
      (StoredReviewEvent, $$LocalReviewEventsTableReferences),
      StoredReviewEvent,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$LocalExamAttemptsTableCreateCompanionBuilder =
    LocalExamAttemptsCompanion Function({
      required String id,
      required String packageId,
      required String packageVersion,
      required int targetLevel,
      required String mode,
      required String questionsJson,
      Value<String> answersJson,
      Value<int> position,
      required DateTime startedAt,
      required DateTime deadline,
      Value<DateTime?> submittedAt,
      Value<bool> timedOut,
      Value<int?> correctCount,
      Value<int> rowid,
    });
typedef $$LocalExamAttemptsTableUpdateCompanionBuilder =
    LocalExamAttemptsCompanion Function({
      Value<String> id,
      Value<String> packageId,
      Value<String> packageVersion,
      Value<int> targetLevel,
      Value<String> mode,
      Value<String> questionsJson,
      Value<String> answersJson,
      Value<int> position,
      Value<DateTime> startedAt,
      Value<DateTime> deadline,
      Value<DateTime?> submittedAt,
      Value<bool> timedOut,
      Value<int?> correctCount,
      Value<int> rowid,
    });

class $$LocalExamAttemptsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalExamAttemptsTable> {
  $$LocalExamAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageVersion => $composableBuilder(
    column: $table.packageVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get timedOut => $composableBuilder(
    column: $table.timedOut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalExamAttemptsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalExamAttemptsTable> {
  $$LocalExamAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageVersion => $composableBuilder(
    column: $table.packageVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get timedOut => $composableBuilder(
    column: $table.timedOut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalExamAttemptsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalExamAttemptsTable> {
  $$LocalExamAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get packageVersion => $composableBuilder(
    column: $table.packageVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get timedOut =>
      $composableBuilder(column: $table.timedOut, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );
}

class $$LocalExamAttemptsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalExamAttemptsTable,
          StoredExamAttempt,
          $$LocalExamAttemptsTableFilterComposer,
          $$LocalExamAttemptsTableOrderingComposer,
          $$LocalExamAttemptsTableAnnotationComposer,
          $$LocalExamAttemptsTableCreateCompanionBuilder,
          $$LocalExamAttemptsTableUpdateCompanionBuilder,
          (
            StoredExamAttempt,
            BaseReferences<
              _$LocalDatabase,
              $LocalExamAttemptsTable,
              StoredExamAttempt
            >,
          ),
          StoredExamAttempt,
          PrefetchHooks Function()
        > {
  $$LocalExamAttemptsTableTableManager(
    _$LocalDatabase db,
    $LocalExamAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalExamAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalExamAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalExamAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> packageVersion = const Value.absent(),
                Value<int> targetLevel = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> questionsJson = const Value.absent(),
                Value<String> answersJson = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> deadline = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<bool> timedOut = const Value.absent(),
                Value<int?> correctCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalExamAttemptsCompanion(
                id: id,
                packageId: packageId,
                packageVersion: packageVersion,
                targetLevel: targetLevel,
                mode: mode,
                questionsJson: questionsJson,
                answersJson: answersJson,
                position: position,
                startedAt: startedAt,
                deadline: deadline,
                submittedAt: submittedAt,
                timedOut: timedOut,
                correctCount: correctCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String packageId,
                required String packageVersion,
                required int targetLevel,
                required String mode,
                required String questionsJson,
                Value<String> answersJson = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime startedAt,
                required DateTime deadline,
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<bool> timedOut = const Value.absent(),
                Value<int?> correctCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalExamAttemptsCompanion.insert(
                id: id,
                packageId: packageId,
                packageVersion: packageVersion,
                targetLevel: targetLevel,
                mode: mode,
                questionsJson: questionsJson,
                answersJson: answersJson,
                position: position,
                startedAt: startedAt,
                deadline: deadline,
                submittedAt: submittedAt,
                timedOut: timedOut,
                correctCount: correctCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalExamAttemptsTable, StoredExamAttempt>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalExamAttemptsTable,
                    StoredExamAttempt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalExamAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalExamAttemptsTable,
      StoredExamAttempt,
      $$LocalExamAttemptsTableFilterComposer,
      $$LocalExamAttemptsTableOrderingComposer,
      $$LocalExamAttemptsTableAnnotationComposer,
      $$LocalExamAttemptsTableCreateCompanionBuilder,
      $$LocalExamAttemptsTableUpdateCompanionBuilder,
      (
        StoredExamAttempt,
        BaseReferences<
          _$LocalDatabase,
          $LocalExamAttemptsTable,
          StoredExamAttempt
        >,
      ),
      StoredExamAttempt,
      PrefetchHooks Function()
    >;
typedef $$LocalPracticeEntriesTableCreateCompanionBuilder =
    LocalPracticeEntriesCompanion Function({
      required String id,
      required String kind,
      required String dataJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> done,
      Value<int> rowid,
    });
typedef $$LocalPracticeEntriesTableUpdateCompanionBuilder =
    LocalPracticeEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> dataJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> done,
      Value<int> rowid,
    });

class $$LocalPracticeEntriesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalPracticeEntriesTable> {
  $$LocalPracticeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPracticeEntriesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalPracticeEntriesTable> {
  $$LocalPracticeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPracticeEntriesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalPracticeEntriesTable> {
  $$LocalPracticeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);
}

class $$LocalPracticeEntriesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalPracticeEntriesTable,
          StoredPracticeEntry,
          $$LocalPracticeEntriesTableFilterComposer,
          $$LocalPracticeEntriesTableOrderingComposer,
          $$LocalPracticeEntriesTableAnnotationComposer,
          $$LocalPracticeEntriesTableCreateCompanionBuilder,
          $$LocalPracticeEntriesTableUpdateCompanionBuilder,
          (
            StoredPracticeEntry,
            BaseReferences<
              _$LocalDatabase,
              $LocalPracticeEntriesTable,
              StoredPracticeEntry
            >,
          ),
          StoredPracticeEntry,
          PrefetchHooks Function()
        > {
  $$LocalPracticeEntriesTableTableManager(
    _$LocalDatabase db,
    $LocalPracticeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPracticeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPracticeEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalPracticeEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPracticeEntriesCompanion(
                id: id,
                kind: kind,
                dataJson: dataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                done: done,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String dataJson,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPracticeEntriesCompanion.insert(
                id: id,
                kind: kind,
                dataJson: dataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                done: done,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPracticeEntriesTable, StoredPracticeEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalPracticeEntriesTable,
                    StoredPracticeEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPracticeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalPracticeEntriesTable,
      StoredPracticeEntry,
      $$LocalPracticeEntriesTableFilterComposer,
      $$LocalPracticeEntriesTableOrderingComposer,
      $$LocalPracticeEntriesTableAnnotationComposer,
      $$LocalPracticeEntriesTableCreateCompanionBuilder,
      $$LocalPracticeEntriesTableUpdateCompanionBuilder,
      (
        StoredPracticeEntry,
        BaseReferences<
          _$LocalDatabase,
          $LocalPracticeEntriesTable,
          StoredPracticeEntry
        >,
      ),
      StoredPracticeEntry,
      PrefetchHooks Function()
    >;
typedef $$LocalMediaTableCreateCompanionBuilder = LocalMediaCompanion Function({
  required String id,
  required String mime,
  required Uint8List bytes,
  required String checksum,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$LocalMediaTableUpdateCompanionBuilder = LocalMediaCompanion Function({
  Value<String> id,
  Value<String> mime,
  Value<Uint8List> bytes,
  Value<String> checksum,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalMediaTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalMediaTable> {
  $$LocalMediaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMediaTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalMediaTable> {
  $$LocalMediaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMediaTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalMediaTable> {
  $$LocalMediaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalMediaTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalMediaTable,
          StoredMedia,
          $$LocalMediaTableFilterComposer,
          $$LocalMediaTableOrderingComposer,
          $$LocalMediaTableAnnotationComposer,
          $$LocalMediaTableCreateCompanionBuilder,
          $$LocalMediaTableUpdateCompanionBuilder,
          (
            StoredMedia,
            BaseReferences<_$LocalDatabase, $LocalMediaTable, StoredMedia>,
          ),
          StoredMedia,
          PrefetchHooks Function()
        > {
  $$LocalMediaTableTableManager(_$LocalDatabase db, $LocalMediaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMediaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMediaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMediaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMediaCompanion(
                id: id,
                mime: mime,
                bytes: bytes,
                checksum: checksum,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mime,
                required Uint8List bytes,
                required String checksum,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalMediaCompanion.insert(
                id: id,
                mime: mime,
                bytes: bytes,
                checksum: checksum,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMediaTable, StoredMedia>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalMediaTable,
                    StoredMedia
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMediaTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalMediaTable,
      StoredMedia,
      $$LocalMediaTableFilterComposer,
      $$LocalMediaTableOrderingComposer,
      $$LocalMediaTableAnnotationComposer,
      $$LocalMediaTableCreateCompanionBuilder,
      $$LocalMediaTableUpdateCompanionBuilder,
      (
        StoredMedia,
        BaseReferences<_$LocalDatabase, $LocalMediaTable, StoredMedia>,
      ),
      StoredMedia,
      PrefetchHooks Function()
    >;
typedef $$LocalFeedbackReportsTableCreateCompanionBuilder =
    LocalFeedbackReportsCompanion Function({
      required String id,
      required int revision,
      required String dataJson,
      required String state,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalFeedbackReportsTableUpdateCompanionBuilder =
    LocalFeedbackReportsCompanion Function({
      Value<String> id,
      Value<int> revision,
      Value<String> dataJson,
      Value<String> state,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalFeedbackReportsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalFeedbackReportsTable> {
  $$LocalFeedbackReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFeedbackReportsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalFeedbackReportsTable> {
  $$LocalFeedbackReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFeedbackReportsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalFeedbackReportsTable> {
  $$LocalFeedbackReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalFeedbackReportsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalFeedbackReportsTable,
          LocalFeedbackReport,
          $$LocalFeedbackReportsTableFilterComposer,
          $$LocalFeedbackReportsTableOrderingComposer,
          $$LocalFeedbackReportsTableAnnotationComposer,
          $$LocalFeedbackReportsTableCreateCompanionBuilder,
          $$LocalFeedbackReportsTableUpdateCompanionBuilder,
          (
            LocalFeedbackReport,
            BaseReferences<
              _$LocalDatabase,
              $LocalFeedbackReportsTable,
              LocalFeedbackReport
            >,
          ),
          LocalFeedbackReport,
          PrefetchHooks Function()
        > {
  $$LocalFeedbackReportsTableTableManager(
    _$LocalDatabase db,
    $LocalFeedbackReportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFeedbackReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFeedbackReportsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalFeedbackReportsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFeedbackReportsCompanion(
                id: id,
                revision: revision,
                dataJson: dataJson,
                state: state,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int revision,
                required String dataJson,
                required String state,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFeedbackReportsCompanion.insert(
                id: id,
                revision: revision,
                dataJson: dataJson,
                state: state,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalFeedbackReportsTable, LocalFeedbackReport>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalFeedbackReportsTable,
                    LocalFeedbackReport
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFeedbackReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalFeedbackReportsTable,
      LocalFeedbackReport,
      $$LocalFeedbackReportsTableFilterComposer,
      $$LocalFeedbackReportsTableOrderingComposer,
      $$LocalFeedbackReportsTableAnnotationComposer,
      $$LocalFeedbackReportsTableCreateCompanionBuilder,
      $$LocalFeedbackReportsTableUpdateCompanionBuilder,
      (
        LocalFeedbackReport,
        BaseReferences<
          _$LocalDatabase,
          $LocalFeedbackReportsTable,
          LocalFeedbackReport
        >,
      ),
      LocalFeedbackReport,
      PrefetchHooks Function()
    >;
typedef $$LocalAdminRevisionsTableCreateCompanionBuilder =
    LocalAdminRevisionsCompanion Function({
      required String itemId,
      required int revision,
      required String kind,
      required String dataJson,
      required String state,
      Value<bool> exported,
      Value<int> rowid,
    });
typedef $$LocalAdminRevisionsTableUpdateCompanionBuilder =
    LocalAdminRevisionsCompanion Function({
      Value<String> itemId,
      Value<int> revision,
      Value<String> kind,
      Value<String> dataJson,
      Value<String> state,
      Value<bool> exported,
      Value<int> rowid,
    });

class $$LocalAdminRevisionsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalAdminRevisionsTable> {
  $$LocalAdminRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exported => $composableBuilder(
    column: $table.exported,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAdminRevisionsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalAdminRevisionsTable> {
  $$LocalAdminRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exported => $composableBuilder(
    column: $table.exported,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAdminRevisionsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalAdminRevisionsTable> {
  $$LocalAdminRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get exported =>
      $composableBuilder(column: $table.exported, builder: (column) => column);
}

class $$LocalAdminRevisionsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalAdminRevisionsTable,
          LocalAdminRevision,
          $$LocalAdminRevisionsTableFilterComposer,
          $$LocalAdminRevisionsTableOrderingComposer,
          $$LocalAdminRevisionsTableAnnotationComposer,
          $$LocalAdminRevisionsTableCreateCompanionBuilder,
          $$LocalAdminRevisionsTableUpdateCompanionBuilder,
          (
            LocalAdminRevision,
            BaseReferences<
              _$LocalDatabase,
              $LocalAdminRevisionsTable,
              LocalAdminRevision
            >,
          ),
          LocalAdminRevision,
          PrefetchHooks Function()
        > {
  $$LocalAdminRevisionsTableTableManager(
    _$LocalDatabase db,
    $LocalAdminRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAdminRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAdminRevisionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalAdminRevisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<bool> exported = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminRevisionsCompanion(
                itemId: itemId,
                revision: revision,
                kind: kind,
                dataJson: dataJson,
                state: state,
                exported: exported,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required int revision,
                required String kind,
                required String dataJson,
                required String state,
                Value<bool> exported = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminRevisionsCompanion.insert(
                itemId: itemId,
                revision: revision,
                kind: kind,
                dataJson: dataJson,
                state: state,
                exported: exported,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAdminRevisionsTable, LocalAdminRevision>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalAdminRevisionsTable,
                    LocalAdminRevision
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAdminRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalAdminRevisionsTable,
      LocalAdminRevision,
      $$LocalAdminRevisionsTableFilterComposer,
      $$LocalAdminRevisionsTableOrderingComposer,
      $$LocalAdminRevisionsTableAnnotationComposer,
      $$LocalAdminRevisionsTableCreateCompanionBuilder,
      $$LocalAdminRevisionsTableUpdateCompanionBuilder,
      (
        LocalAdminRevision,
        BaseReferences<
          _$LocalDatabase,
          $LocalAdminRevisionsTable,
          LocalAdminRevision
        >,
      ),
      LocalAdminRevision,
      PrefetchHooks Function()
    >;
typedef $$LocalAdminInboxTableCreateCompanionBuilder =
    LocalAdminInboxCompanion Function({
      required String reportId,
      required int revision,
      required String reportJson,
      required String status,
      Value<String?> receiptJson,
      required DateTime receivedAt,
      Value<int> rowid,
    });
typedef $$LocalAdminInboxTableUpdateCompanionBuilder =
    LocalAdminInboxCompanion Function({
      Value<String> reportId,
      Value<int> revision,
      Value<String> reportJson,
      Value<String> status,
      Value<String?> receiptJson,
      Value<DateTime> receivedAt,
      Value<int> rowid,
    });

class $$LocalAdminInboxTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalAdminInboxTable> {
  $$LocalAdminInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reportId => $composableBuilder(
    column: $table.reportId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptJson => $composableBuilder(
    column: $table.receiptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAdminInboxTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalAdminInboxTable> {
  $$LocalAdminInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reportId => $composableBuilder(
    column: $table.reportId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptJson => $composableBuilder(
    column: $table.receiptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAdminInboxTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalAdminInboxTable> {
  $$LocalAdminInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reportId =>
      $composableBuilder(column: $table.reportId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get receiptJson => $composableBuilder(
    column: $table.receiptJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$LocalAdminInboxTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalAdminInboxTable,
          LocalAdminInboxData,
          $$LocalAdminInboxTableFilterComposer,
          $$LocalAdminInboxTableOrderingComposer,
          $$LocalAdminInboxTableAnnotationComposer,
          $$LocalAdminInboxTableCreateCompanionBuilder,
          $$LocalAdminInboxTableUpdateCompanionBuilder,
          (
            LocalAdminInboxData,
            BaseReferences<
              _$LocalDatabase,
              $LocalAdminInboxTable,
              LocalAdminInboxData
            >,
          ),
          LocalAdminInboxData,
          PrefetchHooks Function()
        > {
  $$LocalAdminInboxTableTableManager(
    _$LocalDatabase db,
    $LocalAdminInboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAdminInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAdminInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAdminInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> reportId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> reportJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> receiptJson = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminInboxCompanion(
                reportId: reportId,
                revision: revision,
                reportJson: reportJson,
                status: status,
                receiptJson: receiptJson,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String reportId,
                required int revision,
                required String reportJson,
                required String status,
                Value<String?> receiptJson = const Value.absent(),
                required DateTime receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminInboxCompanion.insert(
                reportId: reportId,
                revision: revision,
                reportJson: reportJson,
                status: status,
                receiptJson: receiptJson,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAdminInboxTable, LocalAdminInboxData>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalAdminInboxTable,
                    LocalAdminInboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAdminInboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalAdminInboxTable,
      LocalAdminInboxData,
      $$LocalAdminInboxTableFilterComposer,
      $$LocalAdminInboxTableOrderingComposer,
      $$LocalAdminInboxTableAnnotationComposer,
      $$LocalAdminInboxTableCreateCompanionBuilder,
      $$LocalAdminInboxTableUpdateCompanionBuilder,
      (
        LocalAdminInboxData,
        BaseReferences<
          _$LocalDatabase,
          $LocalAdminInboxTable,
          LocalAdminInboxData
        >,
      ),
      LocalAdminInboxData,
      PrefetchHooks Function()
    >;
typedef $$LocalAdminPackagesTableCreateCompanionBuilder =
    LocalAdminPackagesCompanion Function({
      required String packageId,
      required int version,
      required Uint8List bytes,
      required String checksum,
      Value<int> rowid,
    });
typedef $$LocalAdminPackagesTableUpdateCompanionBuilder =
    LocalAdminPackagesCompanion Function({
      Value<String> packageId,
      Value<int> version,
      Value<Uint8List> bytes,
      Value<String> checksum,
      Value<int> rowid,
    });

class $$LocalAdminPackagesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalAdminPackagesTable> {
  $$LocalAdminPackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAdminPackagesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalAdminPackagesTable> {
  $$LocalAdminPackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAdminPackagesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalAdminPackagesTable> {
  $$LocalAdminPackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);
}

class $$LocalAdminPackagesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalAdminPackagesTable,
          LocalAdminPackage,
          $$LocalAdminPackagesTableFilterComposer,
          $$LocalAdminPackagesTableOrderingComposer,
          $$LocalAdminPackagesTableAnnotationComposer,
          $$LocalAdminPackagesTableCreateCompanionBuilder,
          $$LocalAdminPackagesTableUpdateCompanionBuilder,
          (
            LocalAdminPackage,
            BaseReferences<
              _$LocalDatabase,
              $LocalAdminPackagesTable,
              LocalAdminPackage
            >,
          ),
          LocalAdminPackage,
          PrefetchHooks Function()
        > {
  $$LocalAdminPackagesTableTableManager(
    _$LocalDatabase db,
    $LocalAdminPackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAdminPackagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAdminPackagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAdminPackagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> packageId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminPackagesCompanion(
                packageId: packageId,
                version: version,
                bytes: bytes,
                checksum: checksum,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packageId,
                required int version,
                required Uint8List bytes,
                required String checksum,
                Value<int> rowid = const Value.absent(),
              }) => LocalAdminPackagesCompanion.insert(
                packageId: packageId,
                version: version,
                bytes: bytes,
                checksum: checksum,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAdminPackagesTable, LocalAdminPackage>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalAdminPackagesTable,
                    LocalAdminPackage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAdminPackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalAdminPackagesTable,
      LocalAdminPackage,
      $$LocalAdminPackagesTableFilterComposer,
      $$LocalAdminPackagesTableOrderingComposer,
      $$LocalAdminPackagesTableAnnotationComposer,
      $$LocalAdminPackagesTableCreateCompanionBuilder,
      $$LocalAdminPackagesTableUpdateCompanionBuilder,
      (
        LocalAdminPackage,
        BaseReferences<
          _$LocalDatabase,
          $LocalAdminPackagesTable,
          LocalAdminPackage
        >,
      ),
      LocalAdminPackage,
      PrefetchHooks Function()
    >;
typedef $$LocalInstalledPackagesTableCreateCompanionBuilder =
    LocalInstalledPackagesCompanion Function({
      required String packageId,
      required String publisherId,
      required int version,
      required String dataJson,
      required String checksum,
      Value<int> rowid,
    });
typedef $$LocalInstalledPackagesTableUpdateCompanionBuilder =
    LocalInstalledPackagesCompanion Function({
      Value<String> packageId,
      Value<String> publisherId,
      Value<int> version,
      Value<String> dataJson,
      Value<String> checksum,
      Value<int> rowid,
    });

class $$LocalInstalledPackagesTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalInstalledPackagesTable> {
  $$LocalInstalledPackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalInstalledPackagesTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalInstalledPackagesTable> {
  $$LocalInstalledPackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalInstalledPackagesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalInstalledPackagesTable> {
  $$LocalInstalledPackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);
}

class $$LocalInstalledPackagesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalInstalledPackagesTable,
          LocalInstalledPackage,
          $$LocalInstalledPackagesTableFilterComposer,
          $$LocalInstalledPackagesTableOrderingComposer,
          $$LocalInstalledPackagesTableAnnotationComposer,
          $$LocalInstalledPackagesTableCreateCompanionBuilder,
          $$LocalInstalledPackagesTableUpdateCompanionBuilder,
          (
            LocalInstalledPackage,
            BaseReferences<
              _$LocalDatabase,
              $LocalInstalledPackagesTable,
              LocalInstalledPackage
            >,
          ),
          LocalInstalledPackage,
          PrefetchHooks Function()
        > {
  $$LocalInstalledPackagesTableTableManager(
    _$LocalDatabase db,
    $LocalInstalledPackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInstalledPackagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalInstalledPackagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalInstalledPackagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> packageId = const Value.absent(),
                Value<String> publisherId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInstalledPackagesCompanion(
                packageId: packageId,
                publisherId: publisherId,
                version: version,
                dataJson: dataJson,
                checksum: checksum,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packageId,
                required String publisherId,
                required int version,
                required String dataJson,
                required String checksum,
                Value<int> rowid = const Value.absent(),
              }) => LocalInstalledPackagesCompanion.insert(
                packageId: packageId,
                publisherId: publisherId,
                version: version,
                dataJson: dataJson,
                checksum: checksum,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalInstalledPackagesTable,
                    LocalInstalledPackage
                  >(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalInstalledPackagesTable,
                    LocalInstalledPackage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalInstalledPackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalInstalledPackagesTable,
      LocalInstalledPackage,
      $$LocalInstalledPackagesTableFilterComposer,
      $$LocalInstalledPackagesTableOrderingComposer,
      $$LocalInstalledPackagesTableAnnotationComposer,
      $$LocalInstalledPackagesTableCreateCompanionBuilder,
      $$LocalInstalledPackagesTableUpdateCompanionBuilder,
      (
        LocalInstalledPackage,
        BaseReferences<
          _$LocalDatabase,
          $LocalInstalledPackagesTable,
          LocalInstalledPackage
        >,
      ),
      LocalInstalledPackage,
      PrefetchHooks Function()
    >;
typedef $$LocalCatalogReceiptsTableCreateCompanionBuilder =
    LocalCatalogReceiptsCompanion Function({
      required String publisherId,
      required String packageId,
      required int version,
      required String checksum,
      Value<int> rowid,
    });
typedef $$LocalCatalogReceiptsTableUpdateCompanionBuilder =
    LocalCatalogReceiptsCompanion Function({
      Value<String> publisherId,
      Value<String> packageId,
      Value<int> version,
      Value<String> checksum,
      Value<int> rowid,
    });

class $$LocalCatalogReceiptsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalCatalogReceiptsTable> {
  $$LocalCatalogReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCatalogReceiptsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalCatalogReceiptsTable> {
  $$LocalCatalogReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCatalogReceiptsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalCatalogReceiptsTable> {
  $$LocalCatalogReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);
}

class $$LocalCatalogReceiptsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalCatalogReceiptsTable,
          LocalCatalogReceipt,
          $$LocalCatalogReceiptsTableFilterComposer,
          $$LocalCatalogReceiptsTableOrderingComposer,
          $$LocalCatalogReceiptsTableAnnotationComposer,
          $$LocalCatalogReceiptsTableCreateCompanionBuilder,
          $$LocalCatalogReceiptsTableUpdateCompanionBuilder,
          (
            LocalCatalogReceipt,
            BaseReferences<
              _$LocalDatabase,
              $LocalCatalogReceiptsTable,
              LocalCatalogReceipt
            >,
          ),
          LocalCatalogReceipt,
          PrefetchHooks Function()
        > {
  $$LocalCatalogReceiptsTableTableManager(
    _$LocalDatabase db,
    $LocalCatalogReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCatalogReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCatalogReceiptsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalCatalogReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> publisherId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCatalogReceiptsCompanion(
                publisherId: publisherId,
                packageId: packageId,
                version: version,
                checksum: checksum,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String publisherId,
                required String packageId,
                required int version,
                required String checksum,
                Value<int> rowid = const Value.absent(),
              }) => LocalCatalogReceiptsCompanion.insert(
                publisherId: publisherId,
                packageId: packageId,
                version: version,
                checksum: checksum,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCatalogReceiptsTable, LocalCatalogReceipt>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $LocalCatalogReceiptsTable,
                    LocalCatalogReceipt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCatalogReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalCatalogReceiptsTable,
      LocalCatalogReceipt,
      $$LocalCatalogReceiptsTableFilterComposer,
      $$LocalCatalogReceiptsTableOrderingComposer,
      $$LocalCatalogReceiptsTableAnnotationComposer,
      $$LocalCatalogReceiptsTableCreateCompanionBuilder,
      $$LocalCatalogReceiptsTableUpdateCompanionBuilder,
      (
        LocalCatalogReceipt,
        BaseReferences<
          _$LocalDatabase,
          $LocalCatalogReceiptsTable,
          LocalCatalogReceipt
        >,
      ),
      LocalCatalogReceipt,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$LocalWordsTableTableManager get localWords =>
      $$LocalWordsTableTableManager(_db, _db.localWords);
  $$LocalMetadataTableTableManager get localMetadata =>
      $$LocalMetadataTableTableManager(_db, _db.localMetadata);
  $$LocalReceiptsTableTableManager get localReceipts =>
      $$LocalReceiptsTableTableManager(_db, _db.localReceipts);
  $$LocalSchedulesTableTableManager get localSchedules =>
      $$LocalSchedulesTableTableManager(_db, _db.localSchedules);
  $$LocalReviewSessionsTableTableManager get localReviewSessions =>
      $$LocalReviewSessionsTableTableManager(_db, _db.localReviewSessions);
  $$LocalReviewEventsTableTableManager get localReviewEvents =>
      $$LocalReviewEventsTableTableManager(_db, _db.localReviewEvents);
  $$LocalExamAttemptsTableTableManager get localExamAttempts =>
      $$LocalExamAttemptsTableTableManager(_db, _db.localExamAttempts);
  $$LocalPracticeEntriesTableTableManager get localPracticeEntries =>
      $$LocalPracticeEntriesTableTableManager(_db, _db.localPracticeEntries);
  $$LocalMediaTableTableManager get localMedia =>
      $$LocalMediaTableTableManager(_db, _db.localMedia);
  $$LocalFeedbackReportsTableTableManager get localFeedbackReports =>
      $$LocalFeedbackReportsTableTableManager(_db, _db.localFeedbackReports);
  $$LocalAdminRevisionsTableTableManager get localAdminRevisions =>
      $$LocalAdminRevisionsTableTableManager(_db, _db.localAdminRevisions);
  $$LocalAdminInboxTableTableManager get localAdminInbox =>
      $$LocalAdminInboxTableTableManager(_db, _db.localAdminInbox);
  $$LocalAdminPackagesTableTableManager get localAdminPackages =>
      $$LocalAdminPackagesTableTableManager(_db, _db.localAdminPackages);
  $$LocalInstalledPackagesTableTableManager get localInstalledPackages =>
      $$LocalInstalledPackagesTableTableManager(
        _db,
        _db.localInstalledPackages,
      );
  $$LocalCatalogReceiptsTableTableManager get localCatalogReceipts =>
      $$LocalCatalogReceiptsTableTableManager(_db, _db.localCatalogReceipts);
}
