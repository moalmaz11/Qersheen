import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// 1. GLOBAL DICTIONARY & LOCALIZATION (ARABIC & ENGLISH)
// ============================================================================
class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Qersheen',
      'app_tagline': '100% Offline & Private Smart Wallet',
      'total_balance': 'Total Net Worth',
      'available_balance': 'Available Balance',
      'cards_and_wallets': 'Cards & Telecom Wallets',
      'quick_actions': 'Quick Actions',
      'add_cash': 'Add Cash / Tx',
      'sync_sms': 'Parse SMS (Offline)',
      'transactions': 'Recent Transactions',
      'view_all': 'View All',
      'no_transactions': 'No transactions recorded yet',
      'tab_wallet': 'Wallet',
      'tab_obligations': 'Obligations',
      'tab_analytics': 'Analytics',
      'tab_settings': 'Settings',
      'obligations_title': 'Monthly Installments & Loans',
      'obligations_subtitle': 'ValU, Aman, Souhoola, Bank Loans',
      'add_obligation': 'Add Installment',
      'monthly_payment': 'Monthly Payment',
      'progress': 'Progress',
      'months_left': 'months remaining',
      'due_day': 'Due Day',
      'mark_paid': 'Pay This Month',
      'already_paid_month': 'Already paid for this month',
      'overdue_alert': 'Payment Alert!',
      'due_soon_alert': 'Upcoming Payment Alert',
      'analytics_title': 'Spending & Budgets',
      'monthly_spending': 'Monthly Spending',
      'monthly_income': 'Monthly Income',
      'net_savings': 'Net Cash Flow',
      'category_breakdown': 'Category Breakdown',
      'budget_limits': 'Budget Limits',
      'set_budget': 'Set Budget',
      'settings_title': 'Privacy & Security',
      'language_setting': 'App Language',
      'language_desc': 'Switch between Arabic and English',
      'biometric_lock': 'Biometric App Lock',
      'biometric_desc': 'Require Fingerprint / FaceID to open',
      'export_csv': 'Export Transactions (CSV)',
      'export_csv_desc': 'Offline spreadsheet export',
      'export_pdf': 'Export Financial Statement (PDF)',
      'export_pdf_desc': 'Offline PDF report with Arabic font support',
      'privacy_shield_title': '100% Zero-Data-Sharing Guarantee',
      'privacy_shield_desc': 'Zero internet permission requested. No cloud servers. No analytics. Your financial logs never leave this phone.',
      'unlock_title': 'Qersheen Security',
      'unlock_desc': 'Authenticate to access your private wallet',
      'unlock_button': 'Unlock Wallet',
      'use_passcode': 'Use Device Passcode / Fallback',
      'enter_amount': 'Amount (EGP)',
      'category': 'Category',
      'note': 'Note / Description',
      'select_card': 'Select Card / Wallet',
      'type_expense': 'Expense',
      'type_income': 'Income',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'provider_name': 'Provider (e.g. ValU, Aman, CIB)',
      'title_label': 'Title (e.g. iPhone 15, Car Loan)',
      'total_months': 'Total Months',
      'paid_months': 'Months Already Paid',
      'sms_sync_dialog_title': 'Offline SMS Parser',
      'sms_sync_dialog_desc': 'Qersheen parses official Egyptian bank and wallet SMS messages locally on device via Regex without any internet connection.',
      'sample_sms_button': 'Test Egyptian SMS Parser',
      'permission_denied': 'SMS permission not granted. You can still add transactions manually.',
      'sms_parsed_success': 'Transactions parsed & added from SMS successfully!',
      'filter_card': 'Showing transactions for:',
      'clear_filter': 'Show All Cards',
      'cat_food': 'Food & Groceries',
      'cat_bills': 'Bills & Utilities',
      'cat_shopping': 'Shopping',
      'cat_transfer': 'Transfer / P2P',
      'cat_salary': 'Salary / Income',
      'cat_cash': 'Cash & ATM',
      'cat_other': 'General Expense',
      'issuer_vodafone': 'Vodafone Cash',
      'issuer_orange': 'Orange Cash',
      'issuer_instapay': 'InstaPay Egypt',
      'issuer_cib': 'CIB Bank',
      'issuer_nbe': 'National Bank of Egypt',
      'issuer_bm': 'Banque Misr',
      'issuer_cash': 'Physical Cash',
    },
    'ar': {
      'app_name': 'قرشين',
      'app_tagline': 'محفظتك الذكية - بدون إنترنت وخصوصية ١٠٠٪',
      'total_balance': 'إجمالي الرصيد الصافي',
      'available_balance': 'الرصيد المتاح',
      'cards_and_wallets': 'البطاقات والمحافظ الإلكترونية',
      'quick_actions': 'إجراءات سريعة',
      'add_cash': 'إضافة كاش / معاملة',
      'sync_sms': 'قراءة الرسائل (أوفلاين)',
      'transactions': 'أحدث المعاملات',
      'view_all': 'عرض الكل',
      'no_transactions': 'لا توجد معاملات مسجلة حتى الآن',
      'tab_wallet': 'المحفظة',
      'tab_obligations': 'الالتزامات',
      'tab_analytics': 'التحليلات',
      'tab_settings': 'الإعدادات',
      'obligations_title': 'الأقساط الشهرية والقروض',
      'obligations_subtitle': 'ڤاليو، أمان، سهولة، وقروض البنوك',
      'add_obligation': 'إضافة قسط جديد',
      'monthly_payment': 'القسط الشهري',
      'progress': 'نسبة السداد',
      'months_left': 'أشهر متبقية',
      'due_day': 'يوم الاستحقاق',
      'mark_paid': 'سداد قسط هذا الشهر',
      'already_paid_month': 'تم سداد قسط هذا الشهر بالفعل',
      'overdue_alert': 'تنبيه استحقاق!',
      'due_soon_alert': 'تنبيه: موعد استحقاق قسط قريب',
      'analytics_title': 'الميزانية والمصروفات',
      'monthly_spending': 'إجمالي المصروفات',
      'monthly_income': 'إجمالي الدخل',
      'net_savings': 'صافي التدفق المالي',
      'category_breakdown': 'توزيع المصروفات حسب الفئة',
      'budget_limits': 'حدود الميزانيات الشهرية',
      'set_budget': 'تحديد ميزانية',
      'settings_title': 'الخصوصية والأمان',
      'language_setting': 'لغة التطبيق',
      'language_desc': 'التبديل بين العربية والإنجليزية',
      'biometric_lock': 'القفل بالبصمة / التعرف على الوجه',
      'biometric_desc': 'طلب البصمة عند فتح التطبيق للحماية',
      'export_csv': 'تصدير المعاملات (ملف CSV)',
      'export_csv_desc': 'تصدير جدول البيانات أوفلاين',
      'export_pdf': 'تصدير كشف حساب (PDF)',
      'export_pdf_desc': 'تقرير PDF محلي يدعم الخط العربي بدون إنترنت',
      'privacy_shield_title': 'ضمان الخصوصية التامة ١٠٠٪ أوفلاين',
      'privacy_shield_desc': 'التطبيق لا يطلب إذن الإنترنت إطلاقاً. لا خوادم، لا تتبع، ولا إعلانات. بياناتك المالية تبقى حصرياً على جهازك.',
      'unlock_title': 'أمان تطبيق قرشين',
      'unlock_desc': 'قم بتأكيد هويتك للوصول إلى محفظتك الخاصة',
      'unlock_button': 'فتح المحفظة بالبصمة',
      'use_passcode': 'استخدام رمز الجهاز / تجاوز آمن',
      'enter_amount': 'المبلغ (جنيه مصري)',
      'category': 'التصنيف',
      'note': 'ملاحظة / الوصف',
      'select_card': 'اختر المحفظة أو البطاقة',
      'type_expense': 'مصروف',
      'type_income': 'دخل / إيداع',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'provider_name': 'الجهة (مثال: ڤاليو، أمان، بنك مصر)',
      'title_label': 'اسم الالتزام (مثال: قسط لابتوب، قرض سيارة)',
      'total_months': 'إجمالي عدد الشهور',
      'paid_months': 'عدد الشهور المسددة',
      'sms_sync_dialog_title': 'قارئ الرسائل البنكية الذكي',
      'sms_sync_dialog_desc': 'يقوم تطبيق قرشين بتحليل رسائل البنوك المصرية والمحافظ الإلكترونية محلياً بالكامل عبر محرك Regex فوري دون إرسال أي حرف خارج هاتفك.',
      'sample_sms_button': 'تجربة تحليل رسائل نموذجية',
      'permission_denied': 'لم يتم منح إذن قراءة الرسائل. يمكنك إضافة المعاملات يدوياً بسهولة.',
      'sms_parsed_success': 'تم استخراج المعاملات وإضافتها من الرسائل بنجاح!',
      'filter_card': 'عرض معاملات بطاقة:',
      'clear_filter': 'عرض كل البطاقات',
      'cat_food': 'طعام وسوبرماركت',
      'cat_bills': 'فواتير ومرافق',
      'cat_shopping': 'تسوق ومشتريات',
      'cat_transfer': 'تحويلات مالية / إنستاباي',
      'cat_salary': 'راتب / دخل',
      'cat_cash': 'كاش ومسحوبات ATM',
      'cat_other': 'مصروفات عامة',
      'issuer_vodafone': 'فودافون كاش',
      'issuer_orange': 'أورنچ كاش',
      'issuer_instapay': 'إنستاباي مصر',
      'issuer_cib': 'البنك التجاري الدولي CIB',
      'issuer_nbe': 'البنك الأهلي المصري',
      'issuer_bm': 'بنك مصر',
      'issuer_cash': 'كاش نقدي',
    }
  };

  static String get(String lang, String key) {
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

// ============================================================================
// 2. DATA MODELS
// ============================================================================
class WalletCard {
  final String id;
  final String issuer;
  final String titleAr;
  final String titleEn;
  final String maskedNumber;
  final double balance;
  final int colorStart;
  final int colorEnd;
  final String cardType;

  WalletCard({
    required this.id,
    required this.issuer,
    required this.titleAr,
    required this.titleEn,
    required this.maskedNumber,
    required this.balance,
    required this.colorStart,
    required this.colorEnd,
    required this.cardType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'issuer': issuer,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'maskedNumber': dynamicNumberFix(maskedNumber),
    'balance': balance,
    'colorStart': colorStart,
    'colorEnd': colorEnd,
    'cardType': cardType,
  };

  static String dynamicNumberFix(String num) => num;

  factory WalletCard.fromJson(Map<String, dynamic> json) => WalletCard(
    id: json['id'],
    issuer: json['issuer'],
    titleAr: json['titleAr'],
    titleEn: json['titleEn'],
    maskedNumber: json['maskedNumber'],
    balance: (json['balance'] as num).toDouble(),
    colorStart: json['colorStart'] ?? 0xFF1C1C1E,
    colorEnd: json['colorEnd'] ?? 0xFF2C2C2E,
    cardType: json['cardType'] ?? 'Debit',
  );

  WalletCard copyWith({double? balance}) => WalletCard(
    id: id,
    issuer: issuer,
    titleAr: titleAr,
    titleEn: titleEn,
    maskedNumber: maskedNumber,
    balance: balance ?? this.balance,
    colorStart: colorStart,
    colorEnd: colorEnd,
    cardType: cardType,
  );
}

class TransactionItem {
  final String id;
  final String cardId;
  final double amount;
  final String type;
  final String category;
  final String note;
  final DateTime date;
  final String bankSender;
  final bool isManual;

  TransactionItem({
    required this.id,
    required this.cardId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.date,
    this.bankSender = '',
    this.isManual = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cardId': cardId,
    'amount': amount,
    'type': type,
    'category': category,
    'note': note,
    'date': date.toIso8601String(),
    'bankSender': bankSender,
    'isManual': isManual,
  };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
    id: json['id'],
    cardId: json['cardId'],
    amount: (json['amount'] as num).toDouble(),
    type: json['type'],
    category: json['category'],
    note: json['note'],
    date: DateTime.parse(json['date']),
    bankSender: json['bankSender'] ?? '',
    isManual: json['isManual'] ?? true,
  );
}

class ObligationItem {
  final String id;
  final String title;
  final String provider;
  final double monthlyAmount;
  final int totalMonths;
  final int paidMonths;
  final int dueDayOfMonth;
  final String lastPaidMonth;

  ObligationItem({
    required this.id,
    required this.title,
    required this.provider,
    required this.monthlyAmount,
    required this.totalMonths,
    required this.paidMonths,
    required this.dueDayOfMonth,
    this.lastPaidMonth = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'provider': provider,
    'monthlyAmount': monthlyAmount,
    'totalMonths': totalMonths,
    'paidMonths': paidMonths,
    'dueDayOfMonth': dueDayOfMonth,
    'lastPaidMonth': lastPaidMonth,
  };

  factory ObligationItem.fromJson(Map<String, dynamic> json) => ObligationItem(
    id: json['id'],
    title: json['title'],
    provider: json['provider'],
    monthlyAmount: (json['monthlyAmount'] as num).toDouble(),
    totalMonths: json['totalMonths'],
    paidMonths: json['paidMonths'],
    dueDayOfMonth: json['dueDayOfMonth'],
    lastPaidMonth: json['lastPaidMonth'] ?? '',
  );

  ObligationItem markMonthPaid(String currentMonthKey) {
    if (paidMonths >= totalMonths) return this;
    return ObligationItem(
      id: id,
      title: title,
      provider: provider,
      monthlyAmount: monthlyAmount,
      totalMonths: totalMonths,
      paidMonths: paidMonths + 1,
      dueDayOfMonth: dueDayOfMonth,
      lastPaidMonth: currentMonthKey,
    );
  }
}

// ============================================================================
// 3. 100% OFFLINE SMS REGEX FINANCIAL ENGINE & LOCAL CATEGORIZER
// ============================================================================
class LocalSmsFinancialEngine {
  static final RegExp _amountRegex = RegExp(
    r'(?:EGP|LE|ج\.م|جم|جنيه|مبلغ)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:EGP|LE|ج\.م|جم|جنيه)',
    caseSensitive: false,
  );

  static final Map<String, String> _bankSenderKeywords = {
    'vodafone': 'Vodafone',
    'فودافون': 'Vodafone',
    'vf-cash': 'Vodafone',
    'orange': 'Orange',
    'أورنج': 'Orange',
    'اورنج': 'Orange',
    'instapay': 'InstaPay',
    'انستاباي': 'InstaPay',
    'cib': 'CIB',
    'nbe': 'NBE',
    'الأهلي': 'NBE',
    'الاهلي': 'NBE',
    'misr': 'BM',
    'بنك مصر': 'BM',
    'etisalat': 'Vodafone',
  };

  static final List<String> _incomeKeywords = [
    'تم استلام',
    'تم إيداع',
    'تم ايداع',
    'تحويل وارد',
    'received',
    'credited',
    'deposit',
    'refund',
    'اضافة',
  ];

  static final Map<String, List<String>> _categoryVocabulary = {
    'cat_food': [
      'talabat', 'طلب', 'مطعم', 'كافيه', 'cafe', 'mcdonald', 'kfc', 'starbucks',
      'gourmet', 'supermarket', 'ماركت', 'كارفور', 'سعودي', 'hyper', 'food', 'market'
    ],
    'cat_bills': [
      'فاتورة', 'كهرباء', 'مياه', 'غاز', 'شحن', 'we', 'telecom', 'vodafone bill',
      'orange dsl', 'fawry', 'فوري', 'bill', 'utilities', 'باقة'
    ],
    'cat_shopping': [
      'amazon', 'noon', 'zara', 'h&m', 'jumia', 'mall', 'شراء', 'مشتريات',
      'ملابس', 'purchase', 'pos', 'store'
    ],
    'cat_transfer': [
      'تحويل', 'انستاباي', 'instapay', 'p2p', 'send', 'transfer', 'إرسال'
    ],
    'cat_salary': [
      'مرتب', 'راتب', 'salary', 'payroll', 'مستحقات'
    ],
    'cat_cash': [
      'سحب نقدي', 'atm', 'ماكينة', 'cash withdrawal', 'كاش'
    ],
  };

  static String categorize(String text) {
    final lower = text.toLowerCase();
    for (final entry in _categoryVocabulary.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'cat_other';
  }

  static double? extractAmount(String sms) {
    final match = _amountRegex.firstMatch(sms);
    if (match != null) {
      String raw = match.group(1) ?? match.group(2) ?? '';
      raw = raw.replaceAll(',', '').trim();
      return double.tryParse(raw);
    }
    return null;
  }

  static String determineType(String sms) {
    final lower = sms.toLowerCase();
    for (final kw in _incomeKeywords) {
      if (lower.contains(kw)) {
        return 'Income';
      }
    }
    return 'Expense';
  }

  static String detectIssuer(String sender, String body) {
    final combined = '$sender $body'.toLowerCase();
    for (final entry in _bankSenderKeywords.entries) {
      if (combined.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'Cash';
  }
}

// ============================================================================
// 4. MAIN ENTRY POINT
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0B0C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const QersheenApp());
}

class QersheenApp extends StatefulWidget {
  const QersheenApp({super.key});

  @override
  State<QersheenApp> createState() => _QersheenAppState();
}

class _QersheenAppState extends State<QersheenApp> {
  String _currentLanguage = 'ar';
  bool _isBiometricsEnabled = true;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPreferences();
  }

  Future<void> _loadInitialPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang') ?? 'ar';
    final bioEnabled = prefs.getBool('bio_enabled') ?? true;

    setState(() {
      _currentLanguage = savedLang;
      _isBiometricsEnabled = bioEnabled;
      _isAuthenticated = !bioEnabled;
      _isLoading = false;
    });
  }

  void _updateLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
    setState(() {
      _currentLanguage = lang;
    });
  }

  void _updateBiometrics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bio_enabled', enabled);
    setState(() {
      _isBiometricsEnabled = enabled;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _currentLanguage == 'ar';

    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF000000),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Qersheen - قرشين',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFFD4AF37),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1C1C1E),
        ),
        fontFamily: isArabic ? 'Cairo' : null,
      ),
      home: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: !_isAuthenticated && _isBiometricsEnabled
            ? AuthLockScreen(
                language: _currentLanguage,
                onSuccess: _onAuthenticated,
              )
            : MainNavigationShell(
                language: _currentLanguage,
                onLanguageChange: _updateLanguage,
                isBiometricsEnabled: _isBiometricsEnabled,
                onBiometricsChange: _updateBiometrics,
              ),
      ),
    );
  }
}

// ============================================================================
// 5. BIOMETRIC AUTHENTICATION LOCK SCREEN
// ============================================================================
class AuthLockScreen extends StatefulWidget {
  final String language;
  final VoidCallback onSuccess;

  const AuthLockScreen({
    super.key,
    required this.language,
    required this.onSuccess,
  });

  @override
  State<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends State<AuthLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isChecking = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _authenticateUser();
  }

  Future<void> _authenticateUser() async {
    setState(() {
      _isChecking = true;
      _errorMessage = '';
    });

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        widget.onSuccess();
        return;
      }

      final didAuth = await _auth.authenticate(
        localizedReason: AppStrings.get(widget.language, 'unlock_desc'),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuth) {
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = 'Authentication canceled';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF2C2D35), Color(0xFF15171E)],
                  ),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 54,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppStrings.get(lang, 'app_name'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get(lang, 'unlock_title'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _authenticateUser,
                  icon: const Icon(Icons.lock_open_rounded, color: Colors.black),
                  label: Text(
                    AppStrings.get(lang, 'unlock_button'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  widget.onSuccess();
                },
                child: Text(
                  AppStrings.get(lang, 'use_passcode'),
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6. MAIN NAVIGATION SHELL
// ============================================================================
class MainNavigationShell extends StatefulWidget {
  final String language;
  final Function(String) onLanguageChange;
  final bool isBiometricsEnabled;
  final Function(bool) onBiometricsChange;

  const MainNavigationShell({
    super.key,
    required this.language,
    required this.onLanguageChange,
    required this.isBiometricsEnabled,
    required this.onBiometricsChange,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentTabIndex = 0;

  List<WalletCard> _cards = [];
  List<TransactionItem> _transactions = [];
  List<ObligationItem> _obligations = [];
  Map<String, double> _categoryBudgets = {
    'cat_food': 5000.0,
    'cat_bills': 2500.0,
    'cat_shopping': 4000.0,
    'cat_transfer': 3000.0,
    'cat_cash': 2000.0,
  };

  @override
  void initState() {
    super.initState();
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();

    final cardsJson = prefs.getString('cards_data');
    if (cardsJson != null) {
      final List decoded = jsonDecode(cardsJson);
      _cards = decoded.map((e) => WalletCard.fromJson(e)).toList();
    } else {
      _cards = [
        WalletCard(
          id: 'card_vf',
          issuer: 'Vodafone',
          titleAr: 'فودافون كاش',
          titleEn: 'Vodafone Cash',
          maskedNumber: '**** 0101',
          balance: 4850.00,
          colorStart: 0xFFE60000,
          colorEnd: 0xFF8A0000,
          cardType: 'Wallet',
        ),
        WalletCard(
          id: 'card_instapay',
          issuer: 'InstaPay',
          titleAr: 'إنستاباي مصر',
          titleEn: 'InstaPay Egypt',
          maskedNumber: 'GPA @instapay',
          balance: 18450.00,
          colorStart: 0xFF6C2BD9,
          colorEnd: 0xFF3B0764,
          cardType: 'Instant Pay',
        ),
        WalletCard(
          id: 'card_cib',
          issuer: 'CIB',
          titleAr: 'البنك التجاري الدولي',
          titleEn: 'CIB Titanium Debit',
          maskedNumber: '**** 7741',
          balance: 34200.00,
          colorStart: 0xFF003B70,
          colorEnd: 0xFF001529,
          cardType: 'Debit Card',
        ),
        WalletCard(
          id: 'card_bm',
          issuer: 'BM',
          titleAr: 'بنك مصر',
          titleEn: 'Banque Misr Gold',
          maskedNumber: '**** 3920',
          balance: 12500.00,
          colorStart: 0xFF9E1F24,
          colorEnd: 0xFF4A0A0C,
          cardType: 'Credit Card',
        ),
        WalletCard(
          id: 'card_cash',
          issuer: 'Cash',
          titleAr: 'كاش في المحفظة',
          titleEn: 'Physical Cash',
          maskedNumber: 'EGP Cash',
          balance: 2150.00,
          colorStart: 0xFF1C1C1E,
          colorEnd: 0xFF2C2C2E,
          cardType: 'Cash',
        ),
      ];
      _saveCards();
    }

    final txJson = prefs.getString('tx_data');
    if (txJson != null) {
      final List decoded = jsonDecode(txJson);
      _transactions = decoded.map((e) => TransactionItem.fromJson(e)).toList();
    } else {
      _transactions = [
        TransactionItem(
          id: 'tx_1',
          cardId: 'card_cib',
          amount: 1450.00,
          type: 'Expense',
          category: 'cat_food',
          note: 'Carrefour Hypermarket',
          date: DateTime.now().subtract(const Duration(hours: 3)),
          bankSender: 'CIB',
        ),
        TransactionItem(
          id: 'tx_2',
          cardId: 'card_vf',
          amount: 320.00,
          type: 'Expense',
          category: 'cat_bills',
          note: 'Electricity Bill Fawry',
          date: DateTime.now().subtract(const Duration(days: 1)),
          bankSender: 'Vodafone',
        ),
        TransactionItem(
          id: 'tx_3',
          cardId: 'card_instapay',
          amount: 5000.00,
          type: 'Income',
          category: 'cat_salary',
          note: 'Freelance P2P Transfer',
          date: DateTime.now().subtract(const Duration(days: 2)),
          bankSender: 'InstaPay',
        ),
      ];
      _saveTransactions();
    }

    final obJson = prefs.getString('obligations_data');
    if (obJson != null) {
      final List decoded = jsonDecode(obJson);
      _obligations = decoded.map((e) => ObligationItem.fromJson(e)).toList();
    } else {
      _obligations = [
        ObligationItem(
          id: 'ob_1',
          title: 'MacBook Pro M3',
          provider: 'ValU (ڤاليو)',
          monthlyAmount: 2450.00,
          totalMonths: 12,
          paidMonths: 5,
          dueDayOfMonth: 15,
        ),
        ObligationItem(
          id: 'ob_2',
          title: 'Home Appliances',
          provider: 'Aman (أمان)',
          monthlyAmount: 850.00,
          totalMonths: 6,
          paidMonths: 2,
          dueDayOfMonth: 25,
        ),
      ];
      _saveObligations();
    }

    setState(() {});
    _checkUpcomingObligations();
  }

  void _checkUpcomingObligations() {
    final now = DateTime.now();
    final today = now.day;
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    for (final ob in _obligations) {
      if (ob.lastPaidMonth != currentMonthKey && ob.paidMonths < ob.totalMonths) {
        if (today >= ob.dueDayOfMonth - 3 && today <= ob.dueDayOfMonth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showDueReminderNotification(ob);
          });
          break;
        }
      }
    }
  }

  void _showDueReminderNotification(ObligationItem ob) {
    final lang = widget.language;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Text(AppStrings.get(lang, 'due_soon_alert'), style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          '${ob.title} (${ob.provider})\n${AppStrings.get(lang, 'monthly_payment')}: ${ob.monthlyAmount.toStringAsFixed(0)} EGP\n${AppStrings.get(lang, 'due_day')}: ${ob.dueDayOfMonth}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get(lang, 'cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _markObligationPaid(ob.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: Text(AppStrings.get(lang, 'mark_paid'), style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cards.map((e) => e.toJson()).toList());
    await prefs.setString('cards_data', encoded);
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('tx_data', encoded);
  }

  Future<void> _saveObligations() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_obligations.map((e) => e.toJson()).toList());
    await prefs.setString('obligations_data', encoded);
  }

  void _addTransaction(TransactionItem item) {
    setState(() {
      _transactions.insert(0, item);
      final cardIdx = _cards.indexWhere((c) => c.id == item.cardId);
      if (cardIdx != -1) {
        final card = _cards[cardIdx];
        final newBal = item.type == 'Income' ? card.balance + item.amount : card.balance - item.amount;
        _cards[cardIdx] = card.copyWith(balance: newBal);
      }
    });
    _saveTransactions();
    _saveCards();
  }

  void _addObligation(ObligationItem ob) {
    setState(() {
      _obligations.add(ob);
    });
    _saveObligations();
  }

  void _markObligationPaid(String id) {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    setState(() {
      final idx = _obligations.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final current = _obligations[idx];
        _obligations[idx] = current.markMonthPaid(currentMonthKey);
        if (_cards.isNotEmpty) {
          final defaultCard = _cards.first;
          _addTransaction(TransactionItem(
            id: 'tx_ob_${DateTime.now().millisecondsSinceEpoch}',
            cardId: defaultCard.id,
            amount: current.monthlyAmount,
            type: 'Expense',
            category: 'cat_bills',
            note: '${current.title} (${current.provider})',
            date: DateTime.now(),
            isManual: true,
          ));
        }
      }
    });
    _saveObligations();
  }

  double get _totalBalance => _cards.fold(0.0, (acc, c) => acc + c.balance);

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;

    final tabs = [
      WalletStackScreen(
        language: lang,
        cards: _cards,
        transactions: _transactions,
        totalBalance: _totalBalance,
        onAddTransaction: _addTransaction,
        onSyncSmsRequested: _handleSmsSync,
      ),
      ObligationsScreen(
        language: lang,
        obligations: _obligations,
        onAddObligation: _addObligation,
        onMarkPaid: _markObligationPaid,
      ),
      AnalyticsScreen(
        language: lang,
        transactions: _transactions,
        categoryBudgets: _categoryBudgets,
        onUpdateBudget: (cat, limit) {
          setState(() {
            _categoryBudgets[cat] = limit;
          });
        },
      ),
      SettingsScreen(
        language: lang,
        onLanguageChange: widget.onLanguageChange,
        isBiometricsEnabled: widget.isBiometricsEnabled,
        onBiometricsChange: widget.onBiometricsChange,
        cards: _cards,
        transactions: _transactions,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0B0C),
          border: Border(
            top: BorderSide(color: Color(0xFF1F1F24), width: 0.8),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.account_balance_wallet_rounded, AppStrings.get(lang, 'tab_wallet')),
                _buildNavItem(1, Icons.assignment_turned_in_rounded, AppStrings.get(lang, 'tab_obligations')),
                _buildNavItem(2, Icons.bar_chart_rounded, AppStrings.get(lang, 'tab_analytics')),
                _buildNavItem(3, Icons.shield_rounded, AppStrings.get(lang, 'tab_settings')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSmsSync() async {
    final lang = widget.language;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.sms_rounded, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Text(AppStrings.get(lang, 'sms_sync_dialog_title'), style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get(lang, 'sms_sync_dialog_desc'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% On-Device Regex Execution',
                      style: TextStyle(color: const Color(0xFF10B981).withOpacity(0.9), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get(lang, 'cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runOfflineSmsSimulation();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: Text(
              AppStrings.get(lang, 'sample_sms_button'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _runOfflineSmsSimulation() {
    final sampleMessages = [
      {
        'sender': 'Vodafone-Cash',
        'body': 'تم سحب مبلغ 350.00 ج.م من محفظة فودافون كاش لـ فواتير كهرباء. الرصيد المتبقي 4,500.00 ج.م',
      },
      {
        'sender': 'InstaPay',
        'body': 'تم تحويل مبلغ EGP 1,200.00 بنجاح عبر انستاباي إلى أحمد علي. المرجع: 938210.',
      },
      {
        'sender': 'CIB',
        'body': 'Purchase approved on CIB Titanium card for EGP 890.00 at Gourmet Market Zamalek.',
      },
      {
        'sender': 'BanqueMisr',
        'body': 'عملية إيداع مرتب بمبلغ 15,000.00 جم في حساب بنك مصر الخاص بك.',
      },
    ];

    int addedCount = 0;
    for (final sample in sampleMessages) {
      final body = sample['body']!;
      final sender = sample['sender']!;
      final amount = LocalSmsFinancialEngine.extractAmount(body);
      if (amount != null) {
        final type = LocalSmsFinancialEngine.determineType(body);
        final category = LocalSmsFinancialEngine.categorize(body);
        final issuer = LocalSmsFinancialEngine.detectIssuer(sender, body);

        String targetCardId = _cards.isNotEmpty ? _cards.first.id : 'card_cash';
        for (final c in _cards) {
          if (c.issuer.toLowerCase() == issuer.toLowerCase()) {
            targetCardId = c.id;
            break;
          }
        }

        _addTransaction(TransactionItem(
          id: 'tx_sms_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
          cardId: targetCardId,
          amount: amount,
          type: type,
          category: category,
          note: body.substring(0, min(body.length, 45)) + '...',
          date: DateTime.now(),
          bankSender: sender,
          isManual: false,
        ));
        addedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          '$addedCount ${AppStrings.get(widget.language, 'sms_parsed_success')}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ============================================================================
// 7. TAB 1: WALLET SCREEN (APPLE PAY STACKED CARDS)
// ============================================================================
class WalletStackScreen extends StatefulWidget {
  final String language;
  final List<WalletCard> cards;
  final List<TransactionItem> transactions;
  final double totalBalance;
  final Function(TransactionItem) onAddTransaction;
  final VoidCallback onSyncSmsRequested;

  const WalletStackScreen({
    super.key,
    required this.language,
    required this.cards,
    required this.transactions,
    required this.totalBalance,
    required this.onAddTransaction,
    required this.onSyncSmsRequested,
  });

  @override
  State<WalletStackScreen> createState() => _WalletStackScreenState();
}

class _WalletStackScreenState extends State<WalletStackScreen> {
  int? _expandedCardIndex;

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    final isExpanded = _expandedCardIndex != null;

    final displayedTransactions = isExpanded
        ? widget.transactions.where((tx) => tx.cardId == widget.cards[_expandedCardIndex!].id).toList()
        : widget.transactions;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD4AF37), Color(0xFF8A7320)],
                                ),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.black, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.get(lang, 'app_name'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Strictly Offline',
                                      style: TextStyle(
                                        color: const Color(0xFF10B981).withOpacity(0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isExpanded)
                          TextButton.icon(
                            onPressed: () => setState(() => _expandedCardIndex = null),
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFD4AF37)),
                            label: Text(
                              AppStrings.get(lang, 'clear_filter'),
                              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get(lang, 'total_balance'),
                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                NumberFormat('#,##0.00').format(widget.totalBalance),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'EGP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddTransactionDialog(context),
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 18),
                                  label: Text(
                                    AppStrings.get(lang, 'add_cash'),
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: widget.onSyncSmsRequested,
                                  icon: const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                                  label: Text(
                                    AppStrings.get(lang, 'sync_sms'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF24242A),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.get(lang, 'cards_and_wallets'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: isExpanded
                    ? _buildExpandedCard(widget.cards[_expandedCardIndex!], lang)
                    : _buildAppleWalletStack(lang),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isExpanded
                          ? '${AppStrings.get(lang, 'filter_card')} ${lang == 'ar' ? widget.cards[_expandedCardIndex!].titleAr : widget.cards[_expandedCardIndex!].titleEn}'
                          : AppStrings.get(lang, 'transactions'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${displayedTransactions.length} items',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ),
            displayedTransactions.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          AppStrings.get(lang, 'no_transactions'),
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                        child: _buildTransactionTile(displayedTransactions[index], lang),
                      ),
                      childCount: displayedTransactions.length,
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleWalletStack(String lang) {
    final cardCount = widget.cards.length;
    const double cardHeight = 185.0;
    const double peekHeight = 65.0;
    final double stackHeight = cardHeight + (cardCount - 1) * peekHeight;

    return SizedBox(
      height: stackHeight,
      child: Stack(
        children: List.generate(cardCount, (index) {
          final card = widget.cards[index];
          final topOffset = index * peekHeight;
          return Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            height: cardHeight,
            child: GestureDetector(
              onTap: () => setState(() => _expandedCardIndex = index),
              child: _buildCardView(card, lang, isFocused: false),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExpandedCard(WalletCard card, String lang) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: _buildCardView(card, lang, isFocused: true),
        ),
      ],
    );
  }

  Widget _buildCardView(WalletCard card, String lang, {required bool isFocused}) {
    final title = lang == 'ar' ? card.titleAr : card.titleEn;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(card.colorStart), Color(card.colorEnd)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFocused ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.18),
          width: isFocused ? 2.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: isFocused ? 20 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  card.cardType,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get(lang, 'available_balance'),
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat('#,##0.00').format(card.balance)} EGP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                card.maskedNumber,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionItem item, String lang) {
    final isIncome = item.type == 'Income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24242A), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: amountColor.withOpacity(0.12),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.note,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppStrings.get(lang, item.category)} • ${DateFormat('dd MMM, hh:mm a').format(item.date)}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Text(
            '$sign ${NumberFormat('#,##0.00').format(item.amount)} EGP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final lang = widget.language;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedType = 'Expense';
    String selectedCategory = 'cat_food';
    String selectedCardId = widget.cards.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get(lang, 'add_cash'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(AppStrings.get(lang, 'type_expense'))),
                      selected: selectedType == 'Expense',
                      selectedColor: const Color(0xFFEF4444),
                      onSelected: (val) => setModalState(() => selectedType = 'Expense'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(AppStrings.get(lang, 'type_income'))),
                      selected: selectedType == 'Income',
                      selectedColor: const Color(0xFF10B981),
                      onSelected: (val) => setModalState(() => selectedType = 'Income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppStrings.get(lang, 'enter_amount'),
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppStrings.get(lang, 'note'),
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text);
                    if (amt != null && amt > 0) {
                      widget.onAddTransaction(TransactionItem(
                        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                        cardId: selectedCardId,
                        amount: amt,
                        type: selectedType,
                        category: selectedCategory,
                        note: noteController.text.isEmpty
                            ? AppStrings.get(lang, 'add_cash')
                            : noteController.text,
                        date: DateTime.now(),
                        isManual: true,
                      ));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppStrings.get(lang, 'save'),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 8. TAB 2: OBLIGATIONS & INSTALLMENTS
// ============================================================================
class ObligationsScreen extends StatelessWidget {
  final String language;
  final List<ObligationItem> obligations;
  final Function(ObligationItem) onAddObligation;
  final Function(String) onMarkPaid;

  const ObligationsScreen({
    super.key,
    required this.language,
    required this.obligations,
    required this.onAddObligation,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final lang = language;
    final totalMonthly = obligations
        .where((ob) => ob.paidMonths < ob.totalMonths)
        .fold(0.0, (acc, ob) => acc + ob.monthlyAmount);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get(lang, 'obligations_title'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        AppStrings.get(lang, 'obligations_subtitle'),
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showAddObligationDialog(context),
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFD4AF37), size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get(lang, 'monthly_payment'),
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${NumberFormat('#,##0.00').format(totalMonthly)} EGP',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFFD4AF37), size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: obligations.length,
                  itemBuilder: (ctx, index) {
                    final ob = obligations[index];
                    final progress = ob.totalMonths > 0 ? ob.paidMonths / ob.totalMonths : 0.0;
                    final isComplete = ob.paidMonths >= ob.totalMonths;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isComplete ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFF24242A),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ob.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                '${NumberFormat('#,##0.00').format(ob.monthlyAmount)} EGP',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ob.provider,
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                              Text(
                                '${AppStrings.get(lang, 'due_day')}: ${ob.dueDayOfMonth}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFF2C2C2E),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isComplete ? const Color(0xFF10B981) : const Color(0xFFD4AF37),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${ob.paidMonths}/${ob.totalMonths} (${ob.totalMonths - ob.paidMonths} ${AppStrings.get(lang, 'months_left')})',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                              if (!isComplete)
                                ElevatedButton(
                                  onPressed: () => onMarkPaid(ob.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C2C2E),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  child: Text(
                                    AppStrings.get(lang, 'mark_paid'),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                const Text(
                                  'Completed',
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddObligationDialog(BuildContext context) {
    final lang = language;
    final titleController = TextEditingController();
    final providerController = TextEditingController();
    final amountController = TextEditingController();
    final totalMonthsController = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStrings.get(lang, 'add_obligation'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppStrings.get(lang, 'title_label'),
                labelStyle: const TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: providerController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppStrings.get(lang, 'provider_name'),
                labelStyle: const TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppStrings.get(lang, 'monthly_payment'),
                labelStyle: const TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: totalMonthsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppStrings.get(lang, 'total_months'),
                labelStyle: const TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get(lang, 'cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text) ?? 0.0;
              final months = int.tryParse(totalMonthsController.text) ?? 12;
              if (titleController.text.isNotEmpty && amt > 0) {
                onAddObligation(ObligationItem(
                  id: 'ob_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleController.text,
                  provider: providerController.text.isEmpty ? 'Loan' : providerController.text,
                  monthlyAmount: amt,
                  totalMonths: months,
                  paidMonths: 0,
                  dueDayOfMonth: 15,
                ));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: Text(AppStrings.get(lang, 'save'), style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. TAB 3: BUDGETS & ANALYTICS
// ============================================================================
class AnalyticsScreen extends StatelessWidget {
  final String language;
  final List<TransactionItem> transactions;
  final Map<String, double> categoryBudgets;
  final Function(String, double) onUpdateBudget;

  const AnalyticsScreen({
    super.key,
    required this.language,
    required this.transactions,
    required this.categoryBudgets,
    required this.onUpdateBudget,
  });

  @override
  Widget build(BuildContext context) {
    final lang = language;
    final totalExpense = transactions
        .where((t) => t.type == 'Expense')
        .fold(0.0, (acc, t) => acc + t.amount);
    final totalIncome = transactions
        .where((t) => t.type == 'Income')
        .fold(0.0, (acc, t) => acc + t.amount);
    final netCashFlow = totalIncome - totalExpense;

    final Map<String, double> categorySpending = {};
    for (final tx in transactions.where((t) => t.type == 'Expense')) {
      categorySpending[tx.category] = (categorySpending[tx.category] ?? 0.0) + tx.amount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Text(
                AppStrings.get(lang, 'analytics_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: AppStrings.get(lang, 'monthly_spending'),
                      amount: totalExpense,
                      color: const Color(0xFFEF4444),
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: AppStrings.get(lang, 'monthly_income'),
                      amount: totalIncome,
                      color: const Color(0xFF10B981),
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.get(lang, 'net_savings'),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    Text(
                      '${netCashFlow >= 0 ? '+' : ''}${NumberFormat('#,##0.00').format(netCashFlow)} EGP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.get(lang, 'budget_limits'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ...categoryBudgets.entries.map((entry) {
                final cat = entry.key;
                final limit = entry.value;
                final spent = categorySpending[cat] ?? 0.0;
                final progress = limit > 0 ? (spent / limit) : 0.0;
                final isOver = spent > limit;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOver ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF24242A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.get(lang, cat),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${NumberFormat('#,##0').format(spent)} / ${NumberFormat('#,##0').format(limit)} EGP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOver ? const Color(0xFFEF4444) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF2C2C2E),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOver ? const Color(0xFFEF4444) : const Color(0xFFD4AF37),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat('#,##0.00').format(amount),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            'EGP',
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. TAB 4: SETTINGS & OFFLINE EXPORT (PDF & CSV)
// ============================================================================
class SettingsScreen extends StatelessWidget {
  final String language;
  final Function(String) onLanguageChange;
  final bool isBiometricsEnabled;
  final Function(bool) onBiometricsChange;
  final List<WalletCard> cards;
  final List<TransactionItem> transactions;

  const SettingsScreen({
    super.key,
    required this.language,
    required this.onLanguageChange,
    required this.isBiometricsEnabled,
    required this.onBiometricsChange,
    required this.cards,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final lang = language;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Text(
                AppStrings.get(lang, 'settings_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get(lang, 'privacy_shield_title'),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.get(lang, 'privacy_shield_desc'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSettingTile(
                title: AppStrings.get(lang, 'language_setting'),
                subtitle: AppStrings.get(lang, 'language_desc'),
                trailing: TextButton(
                  onPressed: () => onLanguageChange(lang == 'ar' ? 'en' : 'ar'),
                  child: Text(
                    lang == 'ar' ? 'English' : 'العربية',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _buildSettingTile(
                title: AppStrings.get(lang, 'biometric_lock'),
                subtitle: AppStrings.get(lang, 'biometric_desc'),
                trailing: Switch.adaptive(
                  value: isBiometricsEnabled,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: onBiometricsChange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Data & Export (100% Offline)',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                title: AppStrings.get(lang, 'export_csv'),
                subtitle: AppStrings.get(lang, 'export_csv_desc'),
                trailing: const Icon(Icons.table_chart_rounded, color: Color(0xFFD4AF37)),
                onTap: () => _exportCsv(context),
              ),
              _buildSettingTile(
                title: AppStrings.get(lang, 'export_pdf'),
                subtitle: AppStrings.get(lang, 'export_pdf_desc'),
                trailing: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD4AF37)),
                onTap: () => _exportPdf(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24242A)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        trailing: trailing,
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final buffer = StringBuffer();
    buffer.writeln('ID,CardID,Amount,Type,Category,Note,Date,BankSender');
    for (final tx in transactions) {
      buffer.writeln(
        '${tx.id},${tx.cardId},${tx.amount},${tx.type},${tx.category},"${tx.note.replaceAll('"', '""')}",${tx.date.toIso8601String()},${tx.bankSender}',
      );
    }

    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/qersheen_report.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Qersheen Financial Report (CSV)',
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final pdf = pw.Document();

    pw.Font? cairoFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      cairoFont = pw.Font.ttf(fontData);
    } catch (_) {
      cairoFont = null;
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: cairoFont),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Qersheen Financial Statement',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: ['Date', 'Note', 'Category', 'Type', 'Amount (EGP)'],
            data: transactions.map((t) => [
              DateFormat('yyyy-MM-dd').format(t.date),
              t.note,
              t.category,
              t.type,
              '${t.type == 'Expense' ? '-' : '+'}${t.amount.toStringAsFixed(2)}',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'qersheen_statement.pdf');
  }
}
