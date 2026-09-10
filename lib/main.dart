import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

// ================= بيانات البنوك والمحافظ =================
class BankEntity {
  final String id, name, type, acronym;
  final List<String> matchKeywords;
  final List<Color> gradientColors;
  final Color textColor, chipColor, logoBg, logoTextColor;
  final String? cardTypeBadge;
  final IconData logoIcon;

  const BankEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.acronym,
    required this.matchKeywords,
    required this.gradientColors,
    required this.textColor,
    required this.chipColor,
    required this.logoBg,
    required this.logoTextColor,
    required this.logoIcon,
    this.cardTypeBadge,
  });
}

class EgyptInstitutions {
  static const List<BankEntity> all = [
    BankEntity(
      id: 'nbe',
      name: 'البنك الأهلي المصري',
      type: 'National Bank of Egypt',
      acronym: 'NBE',
      cardTypeBadge: 'prepaid',
      matchKeywords: ['nbe', 'ahli', 'الأهلي', 'البنك الأهلي'],
      gradientColors: [Color(0xFF1E3A2B), Color(0xFF144533), Color(0xFFC86D2B)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF0F5132),
      logoTextColor: Color(0xFFFBBF24),
      logoIcon: Icons.account_balance,
    ),
    BankEntity(
      id: 'misr',
      name: 'بنك مصر',
      type: 'BANQUE MISR',
      acronym: 'BM',
      cardTypeBadge: 'classic debit',
      matchKeywords: ['banquemisr', 'bm', 'بنك مصر', 'bm online'],
      gradientColors: [Color(0xFF8C6527), Color(0xFFB38738), Color(0xFF5A3A0E)],
      textColor: Colors.white,
      chipColor: Color(0xFFE5C158),
      logoBg: Color(0xFF991B1B),
      logoTextColor: Colors.white,
      logoIcon: Icons.shield_rounded,
    ),
    BankEntity(
      id: 'cib',
      name: 'البنك التجاري الدولي',
      type: 'Commercial International Bank',
      acronym: 'CIB',
      cardTypeBadge: 'titanium debit',
      matchKeywords: ['cib', 'cibeg', 'التجاري الدولي'],
      gradientColors: [Color(0xFF0C1D36), Color(0xFF1B3D6B), Color(0xFF0A182B)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF0284C7),
      logoTextColor: Colors.white,
      logoIcon: Icons.layers_rounded,
    ),
    BankEntity(
      id: 'caire',
      name: 'بنك القاهرة',
      type: 'Banque Du Caire',
      acronym: 'BDC',
      cardTypeBadge: 'gold debit',
      matchKeywords: ['bdc', 'banqueducaire', 'القاهرة', 'بنك القاهرة'],
      gradientColors: [Color(0xFF431407), Color(0xFF7C2D12), Color(0xFF2A0802)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFEA580C),
      logoTextColor: Colors.white,
      logoIcon: Icons.apartment_rounded,
    ),
    BankEntity(
      id: 'alex',
      name: 'بنك الإسكندرية',
      type: 'AlexBank - Intesa Sanpaolo',
      acronym: 'ALEX',
      cardTypeBadge: 'classic',
      matchKeywords: ['alexbank', 'alex', 'الإسكندرية', 'بنك الإسكندرية'],
      gradientColors: [Color(0xFF022C22), Color(0xFF065F46), Color(0xFF021B14)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF10B981),
      logoTextColor: Colors.white,
      logoIcon: Icons.waves_rounded,
    ),
    BankEntity(
      id: 'qnb',
      name: 'بنك QNB الأهلي',
      type: 'Qatar National Bank Alahli',
      acronym: 'QNB',
      cardTypeBadge: 'platinum debit',
      matchKeywords: ['qnb', 'qnbaa', 'قطر الوطني'],
      gradientColors: [Color(0xFF2D0A1E), Color(0xFF581338), Color(0xFF1F0414)],
      textColor: Colors.white,
      chipColor: Color(0xFFE5C158),
      logoBg: Color(0xFF831843),
      logoTextColor: Colors.white,
      logoIcon: Icons.diamond_rounded,
    ),
    BankEntity(
      id: 'adib',
      name: 'مصرف أبوظبي الإسلامي',
      type: 'Abu Dhabi Islamic Bank',
      acronym: 'ADIB',
      cardTypeBadge: 'islamic debit',
      matchKeywords: ['adib', 'adibeg', 'أبوظبي الإسلامي'],
      gradientColors: [Color(0xFF0C2444), Color(0xFF1D4ED8), Color(0xFF091A33)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF2563EB),
      logoTextColor: Colors.white,
      logoIcon: Icons.token_rounded,
    ),
    BankEntity(
      id: 'aaib',
      name: 'البنك العربي الإفريقي الدولي',
      type: 'Arab African International Bank',
      acronym: 'AAIB',
      cardTypeBadge: 'signature',
      matchKeywords: ['aaib', 'العربي الإفريقي'],
      gradientColors: [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF060D17)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF0891B2),
      logoTextColor: Colors.white,
      logoIcon: Icons.public_rounded,
    ),
    BankEntity(
      id: 'faisal',
      name: 'بنك فيصل الإسلامي المصري',
      type: 'Faisal Islamic Bank of Egypt',
      acronym: 'FAISAL',
      cardTypeBadge: 'islamic gold',
      matchKeywords: ['faisal', 'fib', 'فيصل الإسلامي'],
      gradientColors: [Color(0xFF063323), Color(0xFF047857), Color(0xFF031F15)],
      textColor: Colors.white,
      chipColor: Color(0xFFFBBF24),
      logoBg: Color(0xFF059669),
      logoTextColor: Color(0xFFFEF3C7),
      logoIcon: Icons.verified_rounded,
    ),
    BankEntity(
      id: 'hdb',
      name: 'بنك التعمير والإسكان',
      type: 'Housing & Development Bank',
      acronym: 'HDB',
      cardTypeBadge: 'debit',
      matchKeywords: ['hdb', 'hdbank', 'التعمير والإسكان'],
      gradientColors: [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF100E2B)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF4F46E5),
      logoTextColor: Colors.white,
      logoIcon: Icons.home_work_rounded,
    ),
    BankEntity(
      id: 'hsbc',
      name: 'بنك HSBC مصر',
      type: 'HSBC Bank Egypt',
      acronym: 'HSBC',
      cardTypeBadge: 'premier debit',
      matchKeywords: ['hsbc', 'hsbceg'],
      gradientColors: [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF09090B)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFDC2626),
      logoTextColor: Colors.white,
      logoIcon: Icons.hexagon_outlined,
    ),
    BankEntity(
      id: 'ca',
      name: 'بنك كريدي أجريكول مصر',
      type: 'Crédit Agricole Egypt',
      acronym: 'CAE',
      cardTypeBadge: 'classic',
      matchKeywords: ['cae', 'creditagricole', 'كريدي أجريكول'],
      gradientColors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF022C22)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF059669),
      logoTextColor: Colors.white,
      logoIcon: Icons.eco_rounded,
    ),
    BankEntity(
      id: 'fab',
      name: 'بنك أبوظبي الأول مصر',
      type: 'First Abu Dhabi Bank',
      acronym: 'FABMISR',
      cardTypeBadge: 'signature',
      matchKeywords: ['fabmisr', 'fab', 'أبوظبي الأول'],
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFE11D48),
      logoTextColor: Colors.white,
      logoIcon: Icons.stars_rounded,
    ),
    BankEntity(
      id: 'adcb',
      name: 'بنك أبوظبي التجاري مصر',
      type: 'Abu Dhabi Commercial Bank',
      acronym: 'ADCB',
      cardTypeBadge: 'titanium',
      matchKeywords: ['adcb', 'أبوظبي التجاري'],
      gradientColors: [Color(0xFF450A0A), Color(0xFF7F1D1D), Color(0xFF220303)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFDC2626),
      logoTextColor: Colors.white,
      logoIcon: Icons.change_history_rounded,
    ),
    BankEntity(
      id: 'baraka',
      name: 'بنك البركة مصر',
      type: 'Al Baraka Bank Egypt',
      acronym: 'BARAKA',
      cardTypeBadge: 'islamic card',
      matchKeywords: ['albaraka', 'البركة'],
      gradientColors: [Color(0xFF0C2E20), Color(0xFF14532D), Color(0xFF051710)],
      textColor: Colors.white,
      chipColor: Color(0xFFFBBF24),
      logoBg: Color(0xFF15803D),
      logoTextColor: Color(0xFFFEF3C7),
      logoIcon: Icons.spa_rounded,
    ),
    BankEntity(
      id: 'scb',
      name: 'بنك قناة السويس',
      type: 'Suez Canal Bank',
      acronym: 'SCB',
      cardTypeBadge: 'classic debit',
      matchKeywords: ['scb', 'قناة السويس'],
      gradientColors: [Color(0xFF032541), Color(0xFF0B4F8A), Color(0xFF011424)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF0284C7),
      logoTextColor: Colors.white,
      logoIcon: Icons.directions_boat_rounded,
    ),
    BankEntity(
      id: 'enbd',
      name: 'بنك الإمارات دبي الوطني',
      type: 'Emirates NBD Egypt',
      acronym: 'ENBD',
      cardTypeBadge: 'priority banking',
      matchKeywords: ['enbd', 'الإمارات دبي الوطني'],
      gradientColors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF09122C)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF2563EB),
      logoTextColor: Colors.white,
      logoIcon: Icons.wb_sunny_rounded,
    ),
    BankEntity(
      id: 'arab',
      name: 'البنك العربي مصر',
      type: 'Arab Bank Egypt',
      acronym: 'ARAB',
      cardTypeBadge: 'arab debit',
      matchKeywords: ['arabbank', 'البنك العربي'],
      gradientColors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0E0C2B)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF4338CA),
      logoTextColor: Colors.white,
      logoIcon: Icons.language_rounded,
    ),
    BankEntity(
      id: 'nbk',
      name: 'بنك الكويت الوطني مصر',
      type: 'National Bank of Kuwait',
      acronym: 'NBK',
      cardTypeBadge: 'platinum',
      matchKeywords: ['nbk', 'الكويت الوطني'],
      gradientColors: [Color(0xFF172554), Color(0xFF1E3A8A), Color(0xFF0B1433)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF1D4ED8),
      logoTextColor: Colors.white,
      logoIcon: Icons.flag_rounded,
    ),
    BankEntity(
      id: 'abk',
      name: 'البنك الأهلي الكويتي مصر',
      type: 'Al Ahli Bank of Kuwait',
      acronym: 'ABK',
      cardTypeBadge: 'classic',
      matchKeywords: ['abk', 'الأهلي الكويتي'],
      gradientColors: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF030712)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFEF4444),
      logoTextColor: Colors.white,
      logoIcon: Icons.bookmark_rounded,
    ),
    BankEntity(
      id: 'attijari',
      name: 'التجاري وفا بنك مصر',
      type: 'Attijariwafa Bank Egypt',
      acronym: 'WAFA',
      cardTypeBadge: 'gold debit',
      matchKeywords: ['attijariwafa', 'وفا بنك'],
      gradientColors: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFF240E02)],
      textColor: Colors.white,
      chipColor: Color(0xFFF59E0B),
      logoBg: Color(0xFFD97706),
      logoTextColor: Colors.white,
      logoIcon: Icons.brightness_high_rounded,
    ),
    BankEntity(
      id: 'saib',
      name: 'بنك الشركة المصرفية العربية saib',
      type: 'saib Bank Egypt',
      acronym: 'SAIB',
      cardTypeBadge: 'debit card',
      matchKeywords: ['saib', 'بنك saib'],
      gradientColors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFFD97706),
      logoTextColor: Colors.white,
      logoIcon: Icons.shield_outlined,
    ),
    BankEntity(
      id: 'ub',
      name: 'المصرف المتحد',
      type: 'The United Bank of Egypt',
      acronym: 'UB',
      cardTypeBadge: 'classic',
      matchKeywords: ['theunitedbank', 'ub', 'المصرف المتحد'],
      gradientColors: [Color(0xFF042F2C), Color(0xFF0F766E), Color(0xFF021715)],
      textColor: Colors.white,
      chipColor: Color(0xFFD4AF37),
      logoBg: Color(0xFF0D9488),
      logoTextColor: Colors.white,
      logoIcon: Icons.handshake_rounded,
    ),
    BankEntity(
      id: 'voda',
      name: 'فودافون كاش',
      type: 'Vodafone Cash Wallet',
      acronym: 'VF-CASH',
      cardTypeBadge: 'smart wallet',
      matchKeywords: ['vf-cash', 'vodafone', 'فودافون كاش', 'vodafone cash', 'vfcash'],
      gradientColors: [Color(0xFF4A0404), Color(0xFF990000), Color(0xFF2A0000)],
      textColor: Colors.white,
      chipColor: Color(0xFFEF4444),
      logoBg: Color(0xFFE11D48),
      logoTextColor: Colors.white,
      logoIcon: Icons.phone_android_rounded,
    ),
    BankEntity(
      id: 'orange',
      name: 'أورنج كاش',
      type: 'Orange Cash Wallet',
      acronym: 'ORANGE',
      cardTypeBadge: 'e-wallet',
      matchKeywords: ['orangecash', 'orange', 'أورنج كاش'],
      gradientColors: [Color(0xFF431407), Color(0xFFC2410C), Color(0xFF240A03)],
      textColor: Colors.white,
      chipColor: Color(0xFFF97316),
      logoBg: Color(0xFFEA580C),
      logoTextColor: Colors.white,
      logoIcon: Icons.cell_tower_rounded,
    ),
    BankEntity(
      id: 'etisalat',
      name: 'إي آند كاش (اتصالات)',
      type: 'e& Cash Wallet',
      acronym: 'e& CASH',
      cardTypeBadge: 'e-wallet',
      matchKeywords: ['etisalatcash', 'e&cash', 'اتصالات كاش', 'إي آند كاش'],
      gradientColors: [Color(0xFF1E3A0F), Color(0xFF3F6212), Color(0xFF102008)],
      textColor: Colors.white,
      chipColor: Color(0xFF84CC16),
      logoBg: Color(0xFF65A30D),
      logoTextColor: Colors.white,
      logoIcon: Icons.signal_cellular_alt_rounded,
    ),
    BankEntity(
      id: 'we',
      name: 'وي باي (WE Pay)',
      type: 'WE Pay Telecom Egypt',
      acronym: 'WE PAY',
      cardTypeBadge: 'smart wallet',
      matchKeywords: ['wepay', 'telecomegypt', 'وي باي'],
      gradientColors: [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF170836)],
      textColor: Colors.white,
      chipColor: Color(0xFFA855F7),
      logoBg: Color(0xFF7E22CE),
      logoTextColor: Colors.white,
      logoIcon: Icons.bolt_rounded,
    ),
    BankEntity(
      id: 'fawry',
      name: 'محفظة فوري باي',
      type: 'Fawry Pay Wallet',
      acronym: 'FAWRY',
      cardTypeBadge: 'digital wallet',
      matchKeywords: ['fawry', 'myfawry', 'فوري'],
      gradientColors: [Color(0xFF422006), Color(0xFF854D0E), Color(0xFF201003)],
      textColor: Colors.white,
      chipColor: Color(0xFFFACC15),
      logoBg: Color(0xFFCA8A04),
      logoTextColor: Colors.black,
      logoIcon: Icons.point_of_sale_rounded,
    ),
  ];

  static BankEntity? matchText(String text) {
    final lower = text.toLowerCase();
    for (var bank in all) {
      for (var kw in bank.matchKeywords) {
        if (lower.contains(kw.toLowerCase())) return bank;
      }
    }
    return null;
  }
}

// ================= State Management & Notification Listening =================
class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];

  AppData(this.prefs)
      : isDarkMode = prefs.getBool('isDark') ?? true,
        dailyBudgetLimit = prefs.getDouble('dailyLimit') ?? 600.0 {
    _loadCards();
    _startNotificationListener();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    prefs.setBool('isDark', isDarkMode);
    notifyListeners();
  }

  void updateDailyLimit(double newLimit) {
    dailyBudgetLimit = newLimit;
    prefs.setDouble('dailyLimit', newLimit);
    notifyListeners();
  }

  void _loadCards() {
    final String? cardsJson = prefs.getString('cardsData_v4');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [];
    }
  }

  void _saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData_v4', encoded);
  }

  void addNewCard(BankEntity entity) {
    if (userCards.any((c) => c.bankId == entity.id)) return;
    final newCard = UserCardModel(
      id: entity.id + DateTime.now().millisecondsSinceEpoch.toString(),
      bankId: entity.id,
      cardNumber: '•••• ${(1000 + (DateTime.now().microsecond % 9000))}',
      balance: 0.0,
      transactions: [],
    );
    userCards.insert(0, newCard);
    _saveCards();
    notifyListeners();
  }

  void addTransaction(String cardId, String name, double amount, bool isIncome, String category) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].balance += isIncome ? amount : -amount;
      userCards[idx].transactions.insert(0, TransactionItem(
        name: name, date: DateTime.now().toIso8601String(), amount: amount, isIncome: isIncome, category: category
      ));
      _saveCards();
      notifyListeners();
    }
  }

  void deleteTransaction(String cardId, TransactionItem item) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].balance += item.isIncome ? -item.amount : item.amount;
      userCards[idx].transactions.remove(item);
      _saveCards();
      notifyListeners();
    }
  }

  void clearAll() {
    userCards.clear();
    _saveCards();
    notifyListeners();
  }

  // ================= خدمة الاستماع للإشعارات لحظياً =================
  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final fullText = '$title $content';

        // محاولة مطابقة نص الإشعار مع أي بنك أو محفظة
        final matchedBank = EgyptInstitutions.matchText(fullText);
        if (matchedBank != null) {
          // إضافة الكارت لو لم يكن موجوداً
          if (!userCards.any((c) => c.bankId == matchedBank.id)) {
            addNewCard(matchedBank);
          }

          // استخراج المبلغ المالي
          final amountReg = RegExp(r'(\d+(?:[\.,]\d{1,2})?)\s*(?:EGP|ج\.م|جنيه|جم)');
          final match = amountReg.firstMatch(fullText);
          if (match != null) {
            final raw = match.group(1)!.replaceAll(',', '');
            final val = double.tryParse(raw);

            if (val != null && val > 0) {
              final isInc = fullText.contains('إيداع') || fullText.contains('وارد') || fullText.contains('استلام') || fullText.contains('credited') || fullText.contains('received');
              final target = userCards.firstWhere((c) => c.bankId == matchedBank.id);

              // منع التكرار
              if (!target.transactions.any((t) => t.amount == val && t.name.contains('إشعار'))) {
                addTransaction(
                  target.id,
                  isInc ? 'إشعار تحويل وارد' : 'إشعار سداد/خصم',
                  val,
                  isInc,
                  isInc ? 'دخل' : 'مشتريات/تحويل',
                );
              }
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<int> autoDetectBanksAndSms() async {
    int detectedCount = 0;
    try {
      var status = await Permission.sms.request();
      if (!status.isGranted) return -1;
      SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(kinds: [SmsQueryKind.inbox]);
      for (var msg in messages) {
        final address = msg.address ?? '';
        final body = msg.body ?? '';
        final full = '$address $body';
        final matchedBank = EgyptInstitutions.matchText(full);
        if (matchedBank != null) {
          if (!userCards.any((c) => c.bankId == matchedBank.id)) {
            addNewCard(matchedBank);
            detectedCount++;
          }
          final amountReg = RegExp(r'(\d+(?:[\.,]\d{1,2})?)\s*(?:EGP|ج\.م|جنيه)');
          final match = amountReg.firstMatch(body);
          if (match != null) {
            final raw = match.group(1)!.replaceAll(',', '');
            final val = double.tryParse(raw);
            if (val != null && val > 0) {
              final isInc = body.contains('إيداع') || body.contains('وارد') || body.contains('credited') || body.contains('received');
              final target = userCards.firstWhere((c) => c.bankId == matchedBank.id);
              if (!target.transactions.any((t) => t.amount == val && t.name.contains(address))) {
                addTransaction(target.id, isInc ? 'تحويل وارد ($address)' : 'سداد/خصم ($address)', val, isInc, isInc ? 'دخل' : 'مشتريات');
              }
            }
          }
        }
      }
    } catch (_) {}
    return detectedCount;
  }

  double getTodayExpenses() {
    double total = 0;
    final today = DateTime.now();
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) {
          final d = DateTime.parse(tx.date);
          if (d.year == today.year && d.month == today.month && d.day == today.day) {
            total += tx.amount;
          }
        }
      }
    }
    return total;
  }
}

// ================= Models =================
class UserCardModel {
  final String id, bankId, cardNumber;
  double balance;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.bankId, required this.cardNumber, required this.balance, required this.transactions});

  BankEntity get bank => EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);

  Map<String, dynamic> toJson() => {
    'id': id, 'bankId': bankId, 'cardNumber': cardNumber, 'balance': balance,
    'transactions': transactions.map((t) => t.toJson()).toList(),
  };

  factory UserCardModel.fromJson(Map<String, dynamic> json) => UserCardModel(
    id: json['id'], bankId: json['bankId'], cardNumber: json['cardNumber'] ?? '•••• 0000', balance: json['balance'],
    transactions: (json['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name, date, category;
  final double amount;
  final bool isIncome;
  TransactionItem({required this.name, required this.date, required this.amount, required this.isIncome, required this.category});

  Map<String, dynamic> toJson() => {'name': name, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category};
  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
    name: json['name'], date: json['date'], amount: json['amount'], isIncome: json['isIncome'], category: json['category'] ?? 'عام'
  );
}

// ================= Main App =================
class QersheenApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QersheenApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData(prefs),
      builder: (context, _) {
        final appData = AppData(prefs);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'قرشين',
          themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7), fontFamily: 'sans-serif'),
          darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: MainNavigatorScreen(appData: appData),
        );
      },
    );
  }
}

class MainNavigatorScreen extends StatefulWidget {
  final AppData appData;
  const MainNavigatorScreen({super.key, required this.appData});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    final pages = [
      AppleWalletTab(appData: widget.appData),
      AnalyticsTab(appData: widget.appData),
      BudgetTab(appData: widget.appData),
      SettingsTab(appData: widget.appData)
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.wallet_rounded, 'المحفظة', isDark),
            _buildNavItem(1, Icons.pie_chart_outline_rounded, 'التحليلات', isDark),
            _buildNavItem(2, Icons.track_changes_rounded, 'الميزانية', isDark),
            _buildNavItem(3, Icons.tune_rounded, 'الإعدادات', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF10B981) : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ================= تبويب المحفظة بتصميم Apple Wallet =================
class AppleWalletTab extends StatefulWidget {
  final AppData appData;
  const AppleWalletTab({super.key, required this.appData});
  @override
  State<AppleWalletTab> createState() => _AppleWalletTabState();
}

class _AppleWalletTabState extends State<AppleWalletTab> {
  int? _expandedIndex;

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(margin: const EdgeInsets.all(12), width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة بطاقة إلى المحفظة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('${EgyptInstitutions.all.length} بنك ومحفظة', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: EgyptInstitutions.all.length,
                itemBuilder: (ctx, idx) {
                  final entity = EgyptInstitutions.all[idx];
                  final added = widget.appData.userCards.any((c) => c.bankId == entity.id);
                  return ListTile(
                    leading: Container(
                      width: 44, height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: entity.gradientColors),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(entity.logoIcon, color: entity.logoTextColor, size: 18),
                      ),
                    ),
                    title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(entity.type, style: const TextStyle(fontSize: 11)),
                    trailing: added ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                    onTap: added ? null : () { widget.appData.addNewCard(entity); Navigator.pop(ctx); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDialog(UserCardModel card, bool isIncome) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = isIncome ? 'راتب' : 'مشتريات';
    final categories = isIncome ? ['راتب', 'تحويل', 'أخرى'] : ['مشتريات', 'طعام', 'فواتير', 'مواصلات', 'أخرى'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          title: Text(isIncome ? 'إيداع / استلام في ${card.bank.acronym}' : 'سداد / خصم من ${card.bank.acronym}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'بيان المعاملة')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ج.م)')),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: category,
                isExpanded: true,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setD(() => category = v!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isIncome ? Colors.green : Colors.red),
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt > 0 && titleCtrl.text.isNotEmpty) {
                  widget.appData.addTransaction(card.id, titleCtrl.text, amt, isIncome, category);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('تسجيل', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.appData.userCards;
    final isDark = widget.appData.isDarkMode;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المحفظة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 26),
                      tooltip: 'فحص الرسائل والإشعارات',
                      onPressed: () async {
                        final count = await widget.appData.autoDetectBanksAndSms();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count > 0 ? 'تم التعرف على $count بنك بنجاح' : 'تم فحص الرسائل')));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 30),
                      onPressed: _openAddSheet,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 70, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('لا توجد بطاقات مضافة حتى الآن', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('إضافة بطاقة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _openAddSheet,
                        )
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildAppleWalletStack(cards),
                        ),

                        if (_expandedIndex != null && _expandedIndex! < cards.length) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                                  label: const Text('إيداع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showTransactionDialog(cards[_expandedIndex!], true),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                                  label: const Text('مصروف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showTransactionDialog(cards[_expandedIndex!], false),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  onPressed: () => setState(() => _expandedIndex = null),
                                  child: const Text('طي الكارت'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCardTransactions(cards[_expandedIndex!], isDark),
                        ]
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleWalletStack(List<UserCardModel> cards) {
    const double cardHeight = 210.0;
    const double headerPeek = 65.0;

    double totalHeight;
    if (_expandedIndex == null) {
      totalHeight = cardHeight + ((cards.length - 1) * headerPeek);
    } else {
      totalHeight = cardHeight + 30;
    }

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(cards.length, (index) {
          final card = cards[index];
          final bool isSelected = _expandedIndex == index;

          double topPosition;
          double opacity = 1.0;

          if (_expandedIndex == null) {
            topPosition = index * headerPeek;
          } else {
            if (isSelected) {
              topPosition = 0;
            } else {
              topPosition = cardHeight + 20;
              opacity = 0.0;
            }
          }

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            top: topPosition,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: opacity,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_expandedIndex == index) {
                      _expandedIndex = null;
                    } else {
                      _expandedIndex = index;
                    }
                  });
                },
                child: _buildPhysicalCard(card, isSelected),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhysicalCard(UserCardModel card, bool isExpanded) {
    final bank = card.bank;

    return Container(
      height: 210,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bank.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bank.cardTypeBadge ?? 'card',
                style: TextStyle(color: bank.textColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(bank.name, style: TextStyle(color: bank.textColor, fontWeight: FontWeight.w900, fontSize: 15)),
                      Text(bank.type, style: TextStyle(color: bank.textColor.withValues(alpha: 0.7), fontSize: 9.5)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bank.logoBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: Icon(bank.logoIcon, color: bank.logoTextColor, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 32,
                decoration: BoxDecoration(
                  color: bank.chipColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black26),
                ),
                child: Center(
                  child: Container(
                    width: 28, height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black38, width: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Transform.rotate(
                angle: 1.5708,
                child: Icon(Icons.wifi, size: 20, color: bank.textColor.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الرصيد المتاح', style: TextStyle(color: bank.textColor.withValues(alpha: 0.7), fontSize: 10)),
                  Text(
                    '${card.balance.toStringAsFixed(2)} ج.م',
                    style: TextStyle(color: bank.textColor, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.cardNumber,
                style: TextStyle(color: bank.textColor.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bank.acronym,
                  style: TextStyle(color: bank.textColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardTransactions(UserCardModel card, bool isDark) {
    if (card.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('لا توجد معاملات مسجلة على هذه البطاقة حتى الآن', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: card.transactions.length,
      itemBuilder: (ctx, i) {
        final tx = card.transactions[i];
        return Dismissible(
          key: Key(tx.date + tx.name + i.toString()),
          direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => widget.appData.deleteTransaction(card.id, tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (tx.isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(tx.isIncome ? Icons.south_west : Icons.north_east, color: tx.isIncome ? Colors.green : Colors.red, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(tx.category, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: tx.isIncome ? Colors.green : Colors.redAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================= Tab 2: Analytics =================
class AnalyticsTab extends StatelessWidget {
  final AppData appData;
  const AnalyticsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    Map<String, double> expenses = {};
    for (var card in appData.userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) expenses[tx.category] = (expenses[tx.category] ?? 0) + tx.amount;
      }
    }
    final colors = [Colors.redAccent, Colors.blueAccent, Colors.amber, Colors.purpleAccent, Colors.teal];
    int cIdx = 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل المصروفات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            if (expenses.isEmpty)
              const Center(child: Text('لا توجد مصروفات مسجلة'))
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: expenses.entries.map((e) {
                      final c = colors[cIdx++ % colors.length];
                      return PieChartSectionData(color: c, value: e.value, title: e.key, radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12));
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: ListView(
                  children: expenses.entries.map((e) => ListTile(
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('${e.value.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  )).toList(),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ================= Tab 3: Budget =================
class BudgetTab extends StatefulWidget {
  final AppData appData;
  const BudgetTab({super.key, required this.appData});
  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.appData.dailyBudgetLimit.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    final spent = widget.appData.getTodayExpenses();
    final limit = widget.appData.dailyBudgetLimit;
    final double pct = (spent / limit).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الميزانية اليومية', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مصروفات اليوم', style: TextStyle(color: Colors.grey)),
                      Text('${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: pct, minHeight: 12, backgroundColor: Colors.grey.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تعديل سقف الصرف اليومي (ج.م)', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () {
                  final val = double.tryParse(_ctrl.text) ?? limit;
                  widget.appData.updateDailyLimit(val);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ================= Tab 4: Settings =================
class SettingsTab extends StatelessWidget {
  final AppData appData;
  const SettingsTab({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('المظهر الداكن'),
            trailing: Switch(value: appData.isDarkMode, onChanged: (_) => appData.toggleTheme(), activeColor: const Color(0xFF10B981)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
            title: const Text('تفعيل الاستماع للإشعارات لحظياً'),
            subtitle: const Text('لقراءة إشعارات التحويلات والسحب فور وصولها'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              final status = await NotificationListenerService.isPermissionGranted();
              if (!status) {
                await NotificationListenerService.requestPermission();
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صلاحية الوصول للإشعارات مفعلة بالفعل')));
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('تصفير كل البطاقات والبيانات'),
            leading: const Icon(Icons.delete, color: Colors.red),
            onTap: () {
              appData.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم المسح')));
            },
          ),
        ],
      ),
    );
  }
}
