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

enum EntityType { bank, wallet }
enum TransactionType { atm, purchase, transferOut, transferIn, deposit, generic }

// ================= شعارات البنوك والمحافظ الرسمية الفيكتور =================
class OfficialLogos {
  static Widget getLogo(String id, {double size = 42}) {
    switch (id) {
      case 'nbe':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF004D25), borderRadius: BorderRadius.circular(size * 0.2)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: size * 0.45, height: 4, decoration: const BoxDecoration(color: Color(0xFFEAB308), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 3, height: size * 0.35, color: Colors.white),
                    const SizedBox(width: 2.5),
                    Container(width: 3, height: size * 0.35, color: Colors.white),
                    const SizedBox(width: 2.5),
                    Container(width: 3, height: size * 0.35, color: Colors.white),
                  ],
                )
              ],
            ),
          ),
        );
      case 'misr':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF8B181B), borderRadius: BorderRadius.circular(size * 0.2), border: Border.all(color: const Color(0xFFD4AF37), width: 1.5)),
          child: Center(
            child: Container(
              width: size * 0.6, height: size * 0.6,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD4AF37), width: 1.5)),
              child: const Center(child: Text('م', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900, fontSize: 16))),
            ),
          ),
        );
      case 'cib':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF034EA2), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('CIB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.5))),
        );
      case 'voda':
        return Container(
          width: size, height: size,
          decoration: const BoxDecoration(color: Color(0xFFE60000), shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: size * 0.42, height: size * 0.52,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
            ),
          ),
        );
      case 'orange':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFFFF7900), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('orange', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9.5))),
        );
      case 'etisalat':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF719E19), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('e&', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
        );
      case 'we':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF5B2D82), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('we', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
        );
      case 'fawry':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFFFDB913), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('FAWRY', style: TextStyle(color: Color(0xFF003865), fontWeight: FontWeight.w900, fontSize: 9))),
        );
      case 'instapay':
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF4A154B), borderRadius: BorderRadius.circular(size * 0.2)),
          child: const Center(child: Text('IP', style: TextStyle(color: Color(0xFF00FF87), fontWeight: FontWeight.w900, fontSize: 16))),
        );
      default:
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(size * 0.2), border: Border.all(color: Colors.white24)),
          child: Center(child: Text(id.toUpperCase().substring(0, id.length > 3 ? 3 : id.length), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
        );
    }
  }
}

class BankEntity {
  final String id, name, type, acronym;
  final EntityType entityType;
  final List<String> exactSenders;
  final List<Color> gradientColors;
  final Color textColor, chipColor;
  final String? cardTypeBadge;

  const BankEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.acronym,
    required this.entityType,
    required this.exactSenders,
    required this.gradientColors,
    required this.textColor,
    required this.chipColor,
    this.cardTypeBadge,
  });

  Widget buildLogo({double size = 42}) => OfficialLogos.getLogo(id, size: size);
}

class EgyptInstitutions {
  static List<BankEntity> all = [
    BankEntity(id: 'nbe', name: 'البنك الأهلي المصري', type: 'National Bank of Egypt', acronym: 'NBE', entityType: EntityType.bank, cardTypeBadge: 'prepaid / debit', exactSenders: ['nbe', 'ahli'], gradientColors: const [Color(0xFF0B3B24), Color(0xFF155734), Color(0xFFB45309)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'misr', name: 'بنك مصر', type: 'BANQUE MISR', acronym: 'BM', entityType: EntityType.bank, cardTypeBadge: 'classic debit', exactSenders: ['banquemisr', 'bm'], gradientColors: const [Color(0xFF781315), Color(0xFF9E1B1E), Color(0xFF4A0E10)], textColor: Colors.white, chipColor: const Color(0xFFE5C158)),
    BankEntity(id: 'cib', name: 'البنك التجاري الدولي', type: 'Commercial International Bank', acronym: 'CIB', entityType: EntityType.bank, cardTypeBadge: 'titanium debit', exactSenders: ['cib', 'cibeg'], gradientColors: const [Color(0xFF0A2540), Color(0xFF0D3863), Color(0xFF051329)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'voda', name: 'فودافون كاش', type: 'Vodafone Cash Wallet', acronym: 'VF-CASH', entityType: EntityType.wallet, cardTypeBadge: 'smart wallet', exactSenders: ['vf-cash', 'vfcash', 'vodafone'], gradientColors: const [Color(0xFF4A0404), Color(0xFF8B0000), Color(0xFF240000)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'instapay', name: 'إنستاباي مصر', type: 'InstaPay Egypt (EBC)', acronym: 'INSTAPAY', entityType: EntityType.wallet, cardTypeBadge: 'instant payment', exactSenders: ['instapay', 'ebc'], gradientColors: const [Color(0xFF2E0854), Color(0xFF4B0082), Color(0xFF1A0033)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'orange', name: 'أورنج كاش', type: 'Orange Cash Wallet', acronym: 'ORANGE', entityType: EntityType.wallet, cardTypeBadge: 'e-wallet', exactSenders: ['orangecash', 'orange'], gradientColors: const [Color(0xFF431407), Color(0xFF9A3412), Color(0xFF240A03)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'etisalat', name: 'إي آند كاش (اتصالات)', type: 'e& Cash Wallet', acronym: 'e& CASH', entityType: EntityType.wallet, cardTypeBadge: 'e-wallet', exactSenders: ['etisalatcash', 'e&cash'], gradientColors: const [Color(0xFF1E3A0F), Color(0xFF365314), Color(0xFF0F1E07)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'we', name: 'وي باي (WE Pay)', type: 'WE Pay Telecom Egypt', acronym: 'WE PAY', entityType: EntityType.wallet, cardTypeBadge: 'smart wallet', exactSenders: ['wepay', 'telecomegypt'], gradientColors: const [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF170836)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'fawry', name: 'محفظة فوري باي', type: 'Fawry Pay Wallet', acronym: 'FAWRY', entityType: EntityType.wallet, cardTypeBadge: 'digital wallet', exactSenders: ['fawry', 'myfawry'], gradientColors: const [Color(0xFF3B2404), Color(0xFF78350F), Color(0xFF1C1102)], textColor: Colors.white, chipColor: Colors.transparent),
    BankEntity(id: 'qnb', name: 'بنك QNB الأهلي', type: 'Qatar National Bank Alahli', acronym: 'QNB', entityType: EntityType.bank, cardTypeBadge: 'platinum debit', exactSenders: ['qnb', 'qnbaa'], gradientColors: const [Color(0xFF3B0721), Color(0xFF50072C), Color(0xFF1F0414)], textColor: Colors.white, chipColor: const Color(0xFFE5C158)),
    BankEntity(id: 'bdc', name: 'بنك القاهرة', type: 'Banque Du Caire', acronym: 'BDC', entityType: EntityType.bank, cardTypeBadge: 'gold debit', exactSenders: ['bdc', 'banqueducaire'], gradientColors: const [Color(0xFF3F1607), Color(0xFF7C2D12), Color(0xFF230B02)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'alex', name: 'بنك الإسكندرية', type: 'AlexBank - Intesa Sanpaolo', acronym: 'ALEX', entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['alexbank'], gradientColors: const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF021B14)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'faisal', name: 'بنك فيصل الإسلامي', type: 'Faisal Islamic Bank of Egypt', acronym: 'FAISAL', entityType: EntityType.bank, cardTypeBadge: 'islamic debit', exactSenders: ['fib', 'faisal'], gradientColors: const [Color(0xFF063323), Color(0xFF065F46), Color(0xFF031F15)], textColor: Colors.white, chipColor: const Color(0xFFFBBF24)),
    BankEntity(id: 'aaib', name: 'البنك العربي الإفريقي', type: 'Arab African Int. Bank', acronym: 'AAIB', entityType: EntityType.bank, cardTypeBadge: 'signature', exactSenders: ['aaib'], gradientColors: const [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF060D17)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'hsbc', name: 'بنك HSBC مصر', type: 'HSBC Bank Egypt', acronym: 'HSBC', entityType: EntityType.bank, cardTypeBadge: 'premier', exactSenders: ['hsbc', 'hsbceg'], gradientColors: const [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF09090B)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'adib', name: 'مصرف أبوظبي الإسلامي', type: 'Abu Dhabi Islamic Bank', acronym: 'ADIB', entityType: EntityType.bank, cardTypeBadge: 'islamic gold', exactSenders: ['adib', 'adibeg'], gradientColors: const [Color(0xFF0C2444), Color(0xFF1E40AF), Color(0xFF091A33)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'fab', name: 'بنك أبوظبي الأول', type: 'FABMISR', acronym: 'FAB', entityType: EntityType.bank, cardTypeBadge: 'signature', exactSenders: ['fab', 'fabmisr'], gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'hdb', name: 'بنك التعمير والإسكان', type: 'Housing & Development Bank', acronym: 'HDB', entityType: EntityType.bank, cardTypeBadge: 'debit', exactSenders: ['hdb', 'hdbank'], gradientColors: const [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F0E26)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'cae', name: 'كريدي أجريكول مصر', type: 'Credit Agricole Egypt', acronym: 'CAE', entityType: EntityType.bank, cardTypeBadge: 'classic debit', exactSenders: ['cae', 'creditagricole'], gradientColors: const [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF022C22)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'albaraka', name: 'بنك البركة مصر', type: 'Al Baraka Bank Egypt', acronym: 'BARAKA', entityType: EntityType.bank, cardTypeBadge: 'islamic debit', exactSenders: ['albaraka'], gradientColors: const [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'saib', name: 'بنك saib', type: 'Societe Arabe Internationale', acronym: 'SAIB', entityType: EntityType.bank, cardTypeBadge: 'debit card', exactSenders: ['saib'], gradientColors: const [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF0F0E26)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'egb', name: 'البنك المصري لتنمية الصادرات', type: 'EBank', acronym: 'EBANK', entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['ebank', 'edbe'], gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'scb', name: 'بنك قناة السويس', type: 'Suez Canal Bank', acronym: 'SCB', entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['scb', 'suezcanalbank'], gradientColors: const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF021B14)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'abk', name: 'الأهلي الكويتي مصر', type: 'Al Ahli Bank of Kuwait', acronym: 'ABK', entityType: EntityType.bank, cardTypeBadge: 'gold debit', exactSenders: ['abk', 'abkegypt'], gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'midbank', name: 'ميد بنك', type: 'MIDBANK', acronym: 'MID', entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['midbank'], gradientColors: const [Color(0xFF3B0721), Color(0xFF4C051E), Color(0xFF1F0414)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'ub', name: 'المصرف المتحد', type: 'The United Bank', acronym: 'UB', entityType: EntityType.bank, cardTypeBadge: 'debit', exactSenders: ['ub', 'unitedbank'], gradientColors: const [Color(0xFF0A2540), Color(0xFF0D3863), Color(0xFF051329)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'attijari', name: 'التجاري وفا بنك', type: 'Attijariwafa Bank Egypt', acronym: 'ATTIJARI', entityType: EntityType.bank, cardTypeBadge: 'debit', exactSenders: ['attijari', 'attijariwafa'], gradientColors: const [Color(0xFF3F1607), Color(0xFF7C2D12), Color(0xFF230B02)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
    BankEntity(id: 'egbank', name: 'البنك المصري الخليجي', type: 'EG Bank', acronym: 'EG-BANK', entityType: EntityType.bank, cardTypeBadge: 'classic', exactSenders: ['egbank'], gradientColors: const [Color(0xFF0B3B24), Color(0xFF155734), Color(0xFF04180E)], textColor: Colors.white, chipColor: const Color(0xFFD4AF37)),
  ];

  static BankEntity? matchSender(String sender) {
    final s = sender.toLowerCase().replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '').trim();
    for (var bank in all) {
      for (var exact in bank.exactSenders) {
        final clean = exact.toLowerCase().replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');
        if (s == clean || s.contains(clean)) return bank;
      }
    }
    return null;
  }
}

// ================= محرك التحليل الدلالي والتسلسل الزمني =================
class SmartTransactionParser {
  static void processChronologicalMessage(BankEntity bank, String body, DateTime smsTimestamp, AppData app) {
    final text = body.replaceAll('\n', ' ').trim();

    // 1. استخراج رقم المحفظة أو الحساب
    String? phone;
    if (bank.entityType == EntityType.wallet) {
      final p = RegExp(r'(?:على رقم محفظتك|محفظتك|لرقم)?\s*(01[0125][0-9]{8})').firstMatch(text);
      if (p != null) phone = p.group(1);
    }
    String? acc;
    if (bank.entityType == EntityType.bank) {
      final a = RegExp(r'(?:حسابك المنتهي بـ|بطاقتك المنتهية بـ)\s*(?:\*+)?(\d{4})').firstMatch(text);
      if (a != null) acc = '•••• ${a.group(1)}';
    }

    if (!app.userCards.any((c) => c.bankId == bank.id)) {
      app.addNewCard(bank, customIdentifier: phone ?? acc);
    }
    final card = app.userCards.firstWhere((c) => c.bankId == bank.id);

    if (phone != null && card.cardIdentifier.contains('X')) {
      card.cardIdentifier = phone;
      app.saveCards();
    } else if (acc != null && card.cardIdentifier.startsWith('•••• 0')) {
      card.cardIdentifier = acc;
      app.saveCards();
    }

    // 2. استخراج الرصيد الحقيقي بدقة مع استبعاد أرقام العمليات والتواريخ
    final balMatch = RegExp(
      r'(?:رصيد(?:ك| حسابك(?: فى فودافون كاش)?)? (?:الحالي|المتاح)|رصيد محفظتك الحالي|current .*?balance is|balance is)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (balMatch != null) {
      final bVal = double.tryParse(balMatch.group(1)!);
      if (bVal != null) {
        // نحدث الرصيد دائماً بالترتيب الزمني التصاعدي
        card.balance = bVal;
        app.saveCards();
      }
    }

    // إذا كانت الرسالة استعلام رصيد بحت (Inquiry)، نكتفي بتحديث الرصيد ولا ننشئ معاملة
    final isInquiry = (text.contains('balance is') && !text.contains('transferred') && !text.contains('were successfully')) ||
        (text.startsWith('رصيد حسابك') && !text.contains('تم دفع') && !text.contains('تم تحويل') && !text.contains('تم استلام') && !text.contains('تم سحب'));
    if (isInquiry) return;

    // 3. استخراج نوع المعاملة والطرف المعني
    TransactionType txType = TransactionType.generic;
    String title = 'معاملة مالية';
    String? subtitle;
    bool isIncome = false;

    if (text.contains('تم سحب') || text.contains('سحب نقدي') || text.contains('Cash withdrawal')) {
      txType = TransactionType.atm;
      title = 'سحب نقدي كاش (ATM)';
      isIncome = false;
    } else if (text.contains('تم استلام') || text.contains('تحويل وارد') || text.contains('تحويل لحظي')) {
      txType = TransactionType.transferIn;
      isIncome = true;

      final name = RegExp(r'المسجل بإسم\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+على رقم|\s+رصيدك|\s+بتاريخ|\.)').firstMatch(text) ??
          RegExp(r'من\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+برقم مرجعي|\s+على رقم|\s+لحسابك|\s+بتاريخ|\.)').firstMatch(text);
      final fromNum = RegExp(r'من رقم\s*(01[0125][0-9]{8})').firstMatch(text);

      if (name != null && name.group(1)!.trim().isNotEmpty) {
        title = 'استلام من ${name.group(1)!.trim()}';
        if (fromNum != null) subtitle = fromNum.group(1);
      } else if (fromNum != null) {
        title = 'استلام من ${fromNum.group(1)}';
      } else {
        title = 'تحويل وارد';
      }
    } else if (text.contains('تم دفع') || text.contains('دفع مبلغ') || text.contains('purchase') || text.contains('شراء')) {
      txType = TransactionType.purchase;
      isIncome = false;

      final merchant = RegExp(r'لـ?([A-Za-z0-9_\-\u0621-\u064A\s]+?)(?:\.|\s+رصيد|\s+رقم|\s+بمبلغ)').firstMatch(text);
      if (merchant != null && merchant.group(1)!.trim().isNotEmpty) {
        title = 'دفع لـ ${merchant.group(1)!.trim()}';
      } else {
        title = 'سداد مدفوعات وفواتير';
      }
    } else if (text.contains('تم تحويل') || text.contains('transferred to') || text.contains('تحويل إلى')) {
      txType = TransactionType.transferOut;
      isIncome = false;

      final toNum = RegExp(r'(?:لرقم|to|إلى)\s*(01[0125][0-9]{8})').firstMatch(text);
      if (toNum != null) {
        title = 'تحويل إلى ${toNum.group(1)}';
      } else {
        title = 'تحويل صادر';
      }
    }

    // 4. استخراج مبلغ المعاملة
    double? amt;
    final amtMatch = RegExp(r'(?:مبلغ|سحب|تحويل|transferred)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|ج\.م|L\.E|LE|EGP)?', caseSensitive: false).firstMatch(text) ??
        RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:L\.E|LE|EGP|جنية|جنيه|ج\.م)').firstMatch(text);

    if (amtMatch != null) {
      final parsed = double.tryParse(amtMatch.group(1)!);
      if (parsed != null && parsed > 0 && parsed != card.balance) {
        amt = parsed;
      }
    }

    if (amt != null && amt > 0) {
      final timeStr = '${smsTimestamp.hour.toString().padLeft(2, '0')}:${smsTimestamp.minute.toString().padLeft(2, '0')} • ${smsTimestamp.day}/${smsTimestamp.month}/${smsTimestamp.year}';
      final isDup = card.transactions.any((t) => t.amount == amt && t.name == title && t.date == timeStr);
      if (!isDup) {
        card.transactions.insert(0, TransactionItem(
          name: title,
          subtitle: subtitle,
          date: timeStr,
          amount: amt,
          isIncome: isIncome,
          category: _cat(txType),
          txType: txType,
        ));
        app.saveCards();
      }
    }
  }

  static String _cat(TransactionType t) {
    switch (t) {
      case TransactionType.atm: return 'سحب ATM';
      case TransactionType.purchase: return 'مشتريات وفواتير';
      case TransactionType.transferOut:
      case TransactionType.transferIn: return 'تحويلات';
      case TransactionType.deposit: return 'إيداع';
      default: return 'عام';
    }
  }
}

// ================= إدارة الحالة ومزامنة الرسائل مرتبة زمنياً =================
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
    final String? cardsJson = prefs.getString('cardsData_v11');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    } else {
      userCards = [];
    }
  }

  void saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData_v11', encoded);
    notifyListeners();
  }

  void addNewCard(BankEntity entity, {String? customIdentifier}) {
    if (userCards.any((c) => c.bankId == entity.id)) return;
    String displayId = entity.entityType == EntityType.wallet ? (customIdentifier ?? '010XXXXXXXX') : (customIdentifier ?? '•••• ${(1000 + (DateTime.now().microsecond % 9000))}');

    userCards.insert(0, UserCardModel(
      id: entity.id + DateTime.now().millisecondsSinceEpoch.toString(),
      bankId: entity.id,
      cardIdentifier: displayId,
      balance: 0.0,
      transactions: [],
    ));
    saveCards();
  }

  void deleteTransaction(String cardId, TransactionItem item) {
    final idx = userCards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      userCards[idx].transactions.remove(item);
      saveCards();
    }
  }

  void clearAll() {
    userCards.clear();
    saveCards();
  }

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final bank = EgyptInstitutions.matchSender(title);
        if (bank != null) {
          SmartTransactionParser.processChronologicalMessage(bank, '$title $content', DateTime.now(), this);
        }
      });
    } catch (_) {}
  }

  // فرز زمني صارم من الأقدم إلى الأحدث لضمان دقة الرصيد اللحظي
  Future<int> autoDetectBanksAndSmsChronologically() async {
    int count = 0;
    try {
      var status = await Permission.sms.request();
      if (!status.isGranted) return -1;

      SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(kinds: [SmsQueryKind.inbox]);

      // ترتيب تصاعدي: القديم أولاً ثم الجديد
      messages.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));

      for (var msg in messages) {
        final sender = msg.address ?? '';
        final bank = EgyptInstitutions.matchSender(sender);
        if (bank != null) {
          SmartTransactionParser.processChronologicalMessage(bank, msg.body ?? '', msg.date ?? DateTime.now(), this);
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  double getTodayExpenses() {
    double total = 0;
    final now = DateTime.now();
    for (var card in userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome && tx.date.contains('${now.day}/${now.month}/${now.year}')) {
          total += tx.amount;
        }
      }
    }
    return total;
  }
}

// ================= النماذج والواجهات =================
class UserCardModel {
  final String id, bankId;
  String cardIdentifier;
  double balance;
  final List<TransactionItem> transactions;

  UserCardModel({required this.id, required this.bankId, required this.cardIdentifier, required this.balance, required this.transactions});
  BankEntity get bank => EgyptInstitutions.all.firstWhere((b) => b.id == bankId, orElse: () => EgyptInstitutions.all.first);

  Map<String, dynamic> toJson() => {'id': id, 'bankId': bankId, 'cardIdentifier': cardIdentifier, 'balance': balance, 'transactions': transactions.map((t) => t.toJson()).toList()};
  factory UserCardModel.fromJson(Map<String, dynamic> j) => UserCardModel(
    id: j['id'], bankId: j['bankId'], cardIdentifier: j['cardIdentifier'] ?? '•••• 0000', balance: (j['balance'] as num).toDouble(),
    transactions: (j['transactions'] as List).map((t) => TransactionItem.fromJson(t)).toList(),
  );
}

class TransactionItem {
  final String name;
  final String? subtitle;
  final String date, category;
  final double amount;
  final bool isIncome;
  final TransactionType txType;

  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, required this.category, this.txType = TransactionType.generic});

  Map<String, dynamic> toJson() => {'name': name, 'subtitle': subtitle, 'date': date, 'amount': amount, 'isIncome': isIncome, 'category': category, 'txType': txType.index};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
    name: j['name'], subtitle: j['subtitle'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'],
    category: j['category'] ?? 'عام', txType: TransactionType.values[(j['txType'] ?? TransactionType.generic.index)],
  );
}

class QersheenApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QersheenApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final appData = AppData(prefs);
    return ListenableBuilder(
      listenable: appData,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'قرشين',
        themeMode: appData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF1F5F9), fontFamily: 'sans-serif'),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: MainScreen(appData: appData),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppData appData;
  const MainScreen({super.key, required this.appData});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final isDark = widget.appData.isDarkMode;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          WalletView(appData: widget.appData),
          AnalyticsView(appData: widget.appData),
          BudgetView(appData: widget.appData),
          SettingsView(appData: widget.appData),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF111827) : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _barBtn(0, Icons.wallet, 'المحفظة'),
            _barBtn(1, Icons.pie_chart, 'التحليلات'),
            _barBtn(2, Icons.flag, 'الميزانية'),
            _barBtn(3, Icons.settings, 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    final c = sel ? const Color(0xFF10B981) : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _tab = idx),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: c, size: 24), Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))]),
    );
  }
}

class WalletView extends StatefulWidget {
  final AppData appData;
  const WalletView({super.key, required this.appData});
  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  int? _expanded;

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(margin: const EdgeInsets.all(12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('إضافة حساب إلى المحفظة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${EgyptInstitutions.all.length} مؤسسة مصرية', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: EgyptInstitutions.all.length,
                itemBuilder: (ctx, i) {
                  final entity = EgyptInstitutions.all[i];
                  final exists = widget.appData.userCards.any((c) => c.bankId == entity.id);
                  return ListTile(
                    leading: entity.buildLogo(size: 40),
                    title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(entity.type, style: const TextStyle(fontSize: 11)),
                    trailing: exists ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                    onTap: exists ? null : () {
                      Navigator.pop(ctx);
                      widget.appData.addNewCard(entity);
                    },
                  );
                },
              ),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المحفظة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28),
                      tooltip: 'مزامنة مرتبة زمنياً',
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري الفرز الزمني الدقيق للرسائل وتحديث الأرصدة الحقيقية...')));
                        await widget.appData.autoDetectBanksAndSmsChronologically();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة كل الرسائل بترتيبها الزمني الصحيح')));
                        }
                      },
                    ),
                    IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 30), onPressed: _showAddSheet),
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
                        const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('اضغط على زر التزامن لمسح رسائل البنوك بالترتيب الزمني', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: _showAddSheet, child: const Text('إضافة بطاقة يدوياً', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildStack(cards)),
                        if (_expanded != null && _expanded! < cards.length) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _expanded = null),
                            icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                            label: const Text('طي الكارت'),
                          ),
                          const SizedBox(height: 16),
                          _buildTxList(cards[_expanded!], isDark),
                        ]
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStack(List<UserCardModel> cards) {
    const double h = 210.0;
    const double peek = 65.0;
    final totalH = _expanded == null ? (h + (cards.length - 1) * peek) : (h + 20);

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(cards.length, (idx) {
          final card = cards[idx];
          final isSel = _expanded == idx;
          final top = _expanded == null ? (idx * peek) : (isSel ? 0.0 : (h + 30));
          final op = _expanded == null ? 1.0 : (isSel ? 1.0 : 0.0);

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            top: top, left: 0, right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: op,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = _expanded == idx ? null : idx),
                child: _buildCardUI(card),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCardUI(UserCardModel card) {
    final bank = card.bank;
    final isWallet = bank.entityType == EntityType.wallet;

    return Container(
      height: 210,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 8))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bank.cardTypeBadge ?? 'card', style: TextStyle(color: bank.textColor.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(bank.name, style: TextStyle(color: bank.textColor, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(bank.type, style: TextStyle(color: bank.textColor.withValues(alpha: 0.7), fontSize: 9.5)),
                  ]),
                  const SizedBox(width: 10),
                  bank.buildLogo(size: 40),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (!isWallet) ...[
                Container(
                  width: 42, height: 30,
                  decoration: BoxDecoration(color: bank.chipColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black26)),
                  child: Center(child: Container(width: 26, height: 16, decoration: BoxDecoration(border: Border.all(color: Colors.black38), borderRadius: BorderRadius.circular(2)))),
                ),
                const SizedBox(width: 12),
                Transform.rotate(angle: 1.5708, child: Icon(Icons.wifi, size: 20, color: bank.textColor.withValues(alpha: 0.7))),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.phone_android, size: 16, color: Colors.white70), SizedBox(width: 4), Text('محفظة هاتف', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                )
              ],
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الرصيد المتاح الحقيقي', style: TextStyle(color: bank.textColor.withValues(alpha: 0.75), fontSize: 10)),
                Text('${card.balance.toStringAsFixed(2)} ج.م', style: TextStyle(color: bank.textColor, fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(card.cardIdentifier, style: TextStyle(color: bank.textColor, fontSize: isWallet ? 18 : 15, fontWeight: FontWeight.bold, letterSpacing: isWallet ? 1.5 : 2)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)), child: Text(bank.acronym, style: TextStyle(color: bank.textColor, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTxList(UserCardModel card, bool isDark) {
    if (card.transactions.isEmpty) {
      return const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد معاملات مسجلة بعد', style: TextStyle(color: Colors.grey)));
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
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(tx.txType == TransactionType.atm ? Icons.local_atm : (tx.isIncome ? Icons.south_west : Icons.north_east), color: tx.isIncome ? Colors.green : Colors.redAccent),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (tx.subtitle != null) Text(tx.subtitle!, style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                        Text('${tx.category} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                Text('${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ج.م', style: TextStyle(fontWeight: FontWeight.w900, color: tx.isIncome ? Colors.green : Colors.redAccent)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnalyticsView extends StatelessWidget {
  final AppData appData;
  const AnalyticsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    Map<String, double> expenses = {};
    for (var card in appData.userCards) {
      for (var tx in card.transactions) {
        if (!tx.isIncome) expenses[tx.category] = (expenses[tx.category] ?? 0) + tx.amount;
      }
    }
    final colors = [Colors.redAccent, Colors.blueAccent, Colors.amber, Colors.purpleAccent, Colors.teal];
    int c = 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل المصروفات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            if (expenses.isEmpty)
              const Center(child: Text('لا توجد مصروفات'))
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 45, sections: expenses.entries.map((e) => PieChartSectionData(color: colors[c++ % colors.length], value: e.value, title: e.key, radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11))).toList())),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(children: expenses.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))).toList()),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class BudgetView extends StatefulWidget {
  final AppData appData;
  const BudgetView({super.key, required this.appData});
  @override
  State<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<BudgetView> {
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
    final pct = (spent / limit).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الميزانية اليومية', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: widget.appData.isDarkMode ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('مصروفات اليوم', style: TextStyle(color: Colors.grey)), Text('${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 15),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, minHeight: 12, backgroundColor: Colors.grey.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
              ]),
            ),
            const SizedBox(height: 30),
            TextField(controller: _ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سقف الصرف اليومي (ج.م)', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.all(14)),
                onPressed: () {
                  widget.appData.updateDailyLimit(double.tryParse(_ctrl.text) ?? limit);
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

class SettingsView extends StatelessWidget {
  final AppData appData;
  const SettingsView({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(title: const Text('المظهر الداكن'), trailing: Switch(value: appData.isDarkMode, onChanged: (_) => appData.toggleTheme(), activeColor: const Color(0xFF10B981))),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
            title: const Text('تفعيل الاستماع للإشعارات لحظياً'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async => await NotificationListenerService.requestPermission(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('تصفير كل البطاقات والبيانات القديمة'),
            onTap: () {
              appData.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير البيانات لتصحيح التسلسل الزمني')));
            },
          ),
        ],
      ),
    );
  }
}
