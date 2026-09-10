import 'dart:convert';
import 'package:flutter/services.dart';

enum AITransactionIntent {
  atmWithdrawal,
  merchantPurchase,
  p2pTransferOut,
  p2pTransferIn,
  bankDeposit,
  balanceInquiryOnly,
  unknown
}

class AIExtractedResult {
  final AITransactionIntent intent;
  final String primaryTitle;
  final String? partyDetail;
  final double? transactionAmount;
  final double? actualBalance;
  final bool isIncome;
  final String? matchedTimestamp;
  final String? userIdentifier;

  AIExtractedResult({
    required this.intent,
    required this.primaryTitle,
    this.partyDetail,
    this.transactionAmount,
    this.actualBalance,
    required this.isIncome,
    this.matchedTimestamp,
    this.userIdentifier,
  });
}

class OnDeviceFinanceAI {
  static Map<String, int> _vocab = {};
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final vocabStr = await rootBundle.loadString('assets/models/vocab.json');
      final Map<String, dynamic> decoded = jsonDecode(vocabStr);
      _vocab = decoded.map((k, v) => MapEntry(k, v as int));
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  /// تحليل الرسالة سياقياً على المعالج المحلي
  static AIExtractedResult analyzeContext(String rawText, {required bool isWallet}) {
    final clean = rawText.replaceAll('\n', ' ').trim();
    final tokens = clean.split(RegExp(r'\s+'));

    // 1. استخراج الرصيد المتبقي الفعلي سياقياً
    double? extractedBalance;
    final balanceContextRegex = RegExp(
      r'(?:رصيد(?:ك|كم| حسابك(?: فى فودافون كاش)?)? (?:الحالي|المتاح|القائم)|رصيد محفظتك|الرصيد المتاح|متبقي|باقي|current .*?balance is|avail(?:able)? bal(?:ance)? is|balance is)\s*[:=]?\s*(\d+(?:[\.,]\d{1,2})?)',
      caseSensitive: false,
    );
    final bMatch = balanceContextRegex.firstMatch(clean);
    if (bMatch != null) {
      extractedBalance = double.tryParse(bMatch.group(1)!.replaceAll(',', ''));
    }

    // 2. فحص إذا كانت الرسالة استعلام رصيد بحت بدون أي عملية مالية
    final isBalanceInquiry = (clean.contains('balance is') && !clean.contains('transferred') && !clean.contains('were successfully')) ||
        (clean.startsWith('رصيد حسابك') && !clean.contains('تم دفع') && !clean.contains('تم تحويل') && !clean.contains('تم استلام') && !clean.contains('تم سحب'));

    if (isBalanceInquiry) {
      return AIExtractedResult(
        intent: AITransactionIntent.balanceInquiryOnly,
        primaryTitle: 'استعلام رصيد',
        actualBalance: extractedBalance,
        isIncome: false,
      );
    }

    // 3. استخراج المعرّف الشخصي (رقم المحفظة أو آخر 4 أرقام من الحساب البنكي)
    String? userIdentifier;
    if (isWallet) {
      final myPhoneMatch = RegExp(r'(?:على رقم محفظتك|محفظتك)\s*(01[0125][0-9]{8})').firstMatch(clean);
      if (myPhoneMatch != null) userIdentifier = myPhoneMatch.group(1);
    } else {
      final accMatch = RegExp(r'(?:حسابك المنتهي بـ|بطاقتك المنتهية بـ)\s*(?:\*+)?(\d{4})').firstMatch(clean);
      if (accMatch != null) userIdentifier = '•••• ${accMatch.group(1)}';
    }

    // 4. استخراج التوقيت الفعلي للعملية من متن الرسالة
    String? matchedTime;
    final timeMatch = RegExp(r'(\d{2}:\d{2})\s+(\d{2}-\d{2}-\d{2,4})').firstMatch(clean) ??
        RegExp(r'(\d{2}-\d{2}-\d{2,4})\s+(\d{2}:\d{2})').firstMatch(clean) ??
        RegExp(r'بتاريخ\s+(\d{2}-\d{2}-\d{4})\s+(\d{2}:\d{2})').firstMatch(clean);
    if (timeMatch != null) matchedTime = timeMatch.group(0);

    // 5. استخراج مبلغ المعاملة وفصله عن الرصيد ورسوم الخدمة
    double? transactionAmount;
    final amountPatterns = [
      RegExp(r'(?:مبلغ|سحب|تحويل|بمبلغ|قيمة|amount|paid)\s*[:=]?\s*(\d+(?:[\.,]\d{1,2})?)\s*(?:جنية|جنيه|ج\.م|جم|L\.E|LE|EGP)?', caseSensitive: false),
      RegExp(r'(\d+(?:[\.,]\d{1,2})?)\s*(?:L\.E|LE|EGP|جنية|جنيه|ج\.م)'),
    ];

    for (var reg in amountPatterns) {
      final matches = reg.allMatches(clean);
      for (var m in matches) {
        final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0 && val != extractedBalance) {
          // استبعاد رسوم الخدمة الصغيرة إذا وُجد مبلغ أكبر منها
          if (clean.contains('رسوم') || clean.contains('مصاريف')) {
            final feeMatch = RegExp(r'(?:مصاريف|رسوم)\s*(?:الخدمة)?\s*[:=]?\s*(\d+(?:[\.,]\d{1,2})?)').firstMatch(clean);
            if (feeMatch != null && double.tryParse(feeMatch.group(1)!) == val) {
              continue;
            }
          }
          transactionAmount = val;
          break;
        }
      }
      if (transactionAmount != null) break;
    }

    // 6. استنتاج النية وتحديد الكيانات (NER Intent Classification)
    AITransactionIntent intent = AITransactionIntent.unknown;
    String primaryTitle = 'معاملة مالية';
    String? partyDetail;
    bool isIncome = false;

    // أ) سحب كاش أو ATM
    if (clean.contains('سحب') || clean.contains('ATM') || clean.contains('صراف') || clean.contains('withdrawn') || clean.contains('Cash withdrawal')) {
      intent = AITransactionIntent.atmWithdrawal;
      primaryTitle = 'سحب نقدي ATM';
      isIncome = false;
    }
    // ب) تحويل وارد / استلام مالي (مع كشف اسم الشخص)
    else if (clean.contains('استلام') || clean.contains('وارد') || clean.contains('لحظي') || clean.contains('received') || clean.contains('credited')) {
      intent = AITransactionIntent.p2pTransferIn;
      isIncome = true;

      final nameMatch = RegExp(r'المسجل بإسم\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+على رقم|\s+رصيدك|\s+بتاريخ|\.)').firstMatch(clean) ??
          RegExp(r'من\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+برقم مرجعي|\s+على رقم|\s+لحسابك|\s+بتاريخ|\.)').firstMatch(clean);

      final senderNum = RegExp(r'من رقم\s*(01[0125][0-9]{8})').firstMatch(clean);

      if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
        primaryTitle = 'استلام من ${nameMatch.group(1)!.trim()}';
        if (senderNum != null) partyDetail = senderNum.group(1);
      } else if (senderNum != null) {
        primaryTitle = 'استلام من ${senderNum.group(1)}';
      } else {
        primaryTitle = 'تحويل وارد';
      }
    }
    // ج) مشتريات وسداد فواتير ومدفوعات (مع كشف اسم المتجر)
    else if (clean.contains('دفع') || clean.contains('سداد') || clean.contains('شراء') || clean.contains('purchase') || clean.contains('POS')) {
      intent = AITransactionIntent.merchantPurchase;
      isIncome = false;

      final merchantMatch = RegExp(r'لـ?([A-Za-z0-9_\-\u0621-\u064A\s]+?)(?:\.|\s+رصيد|\s+رقم|\s+بمبلغ)').firstMatch(clean) ??
          RegExp(r'(?:لدى|من|at)\s+([A-Za-z0-9\u0621-\u064A\s\.\-_]+?)(?:\s+بمبلغ|\s+في|\s+بتاريخ|\s+EGP|\s+ج\.م|$)').firstMatch(clean);

      if (merchantMatch != null && merchantMatch.group(1)!.trim().isNotEmpty) {
        primaryTitle = 'دفع لـ ${merchantMatch.group(1)!.trim()}';
      } else {
        primaryTitle = 'مشتريات ومدفوعات';
      }
    }
    // د) تحويل صادر
    else if (clean.contains('تحويل') || clean.contains('transferred')) {
      intent = AITransactionIntent.p2pTransferOut;
      isIncome = false;

      final targetPhone = RegExp(r'(?:لرقم|to|إلى)\s*(01[0125][0-9]{8})').firstMatch(clean);
      if (targetPhone != null) {
        primaryTitle = 'تحويل إلى ${targetPhone.group(1)}';
      } else {
        primaryTitle = 'تحويل صادر';
      }
    }

    return AIExtractedResult(
      intent: intent,
      primaryTitle: primaryTitle,
      partyDetail: partyDetail,
      transactionAmount: transactionAmount,
      actualBalance: extractedBalance,
      isIncome: isIncome,
      matchedTimestamp: matchedTime,
      userIdentifier: userIdentifier,
    );
  }
}
