import 'dart:convert';

class BankCard {
  final String id;
  final String title;
  final String issuer;
  final String lastFour;
  final double balance;
  final int primaryColor;
  final int secondaryColor;

  BankCard({
    required this.id,
    required this.title,
    required this.issuer,
    required this.lastFour,
    required this.balance,
    required this.primaryColor,
    required this.secondaryColor,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'issuer': issuer,
    'lastFour': lastFour,
    'balance': balance,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
  };

  factory BankCard.fromMap(Map<String, dynamic> map) => BankCard(
    id: map['id'],
    title: map['title'],
    issuer: map['issuer'],
    lastFour: map['lastFour'],
    balance: (map['balance'] as num).toDouble(),
    primaryColor: map['primaryColor'],
    secondaryColor: map['secondaryColor'],
  );
}

class TransactionRecord {
  final String id;
  final String cardId;
  final double amount;
  final String type; // 'income' or 'expense'
  final String category;
  final String note;
  final DateTime date;

  TransactionRecord({
    required this.id,
    required this.cardId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'cardId': cardId,
    'amount': amount,
    'type': type,
    'category': category,
    'note': note,
    'date': date.toIso8601String(),
  };

  factory TransactionRecord.fromMap(Map<String, dynamic> map) => TransactionRecord(
    id: map['id'],
    cardId: map['cardId'],
    amount: (map['amount'] as num).toDouble(),
    type: map['type'],
    category: map['category'],
    note: map['note'],
    date: DateTime.parse(map['date']),
  );
}

class LoanObligation {
  final String id;
  final String title;
  final String provider;
  final double monthlyAmount;
  final int totalMonths;
  final int paidMonths;
  final int dueDay;

  LoanObligation({
    required this.id,
    required this.title,
    required this.provider,
    required this.monthlyAmount,
    required this.totalMonths,
    required this.paidMonths,
    required this.dueDay,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'provider': provider,
    'monthlyAmount': monthlyAmount,
    'totalMonths': totalMonths,
    'paidMonths': paidMonths,
    'dueDay': dueDay,
  };

  factory LoanObligation.fromMap(Map<String, dynamic> map) => LoanObligation(
    id: map['id'],
    title: map['title'],
    provider: map['provider'],
    monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
    totalMonths: map['totalMonths'],
    paidMonths: map['paidMonths'],
    dueDay: map['dueDay'],
  );
}
