import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'institutions_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QersheenApp(prefs: prefs));
}

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool isDarkMode;
  double dailyBudgetLimit;
  List<UserCardModel> userCards = [];
  Set<String> processedMessageFingerprints = {};

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

  void _loadCards() {
    final String? cardsJson = prefs.getString('cardsData_v15');
    if (cardsJson != null && cardsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(cardsJson);
      userCards = decoded.map((e) => UserCardModel.fromJson(e)).toList();
    }
    final List<String>? fps = prefs.getStringList('processed_fps_v15');
    if (fps != null) {
      processedMessageFingerprints = fps.toSet();
    }
  }

  void saveCards() {
    final String encoded = jsonEncode(userCards.map((c) => c.toJson()).toList());
    prefs.setString('cardsData_v15', encoded);
    prefs.setStringList('processed_fps_v15', processedMessageFingerprints.toList());
    notifyListeners();
  }

  void addNewCard(BankEntity entity, {String? customId}) {
    if (userCards.any((c) => c.bankId == entity.id)) return;
    String idStr = entity.entityType == EntityType.wallet 
        ? (customId ?? '010XXXXXXXX') 
        : (customId ?? '•••• ${(1000 + (DateTime.now().microsecond % 9000))}');

    userCards.insert(0, UserCardModel(
      id: '${entity.id}_${DateTime.now().millisecondsSinceEpoch}',
      bankId: entity.id,
      cardIdentifier: idStr,
      balance: 0.0,
      transactions: [],
    ));
    saveCards();
  }

  void clearAll() {
    userCards.clear();
    processedMessageFingerprints.clear();
    saveCards();
  }

  void _startNotificationListener() {
    try {
      NotificationListenerService.notificationsStream.listen((event) {
        final title = event.title ?? '';
        final content = event.content ?? '';
        final bank = EgyptInstitutions.matchSender(title);
        if (bank != null) {
          _processMessage(bank, '$title $content', DateTime.now(), null);
        }
      });
    } catch (_) {}
  }

  Future<void> requestBatteryOptimizationIgnore() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  Future<int> autoDetectChronological() async {
    int count = 0;
    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) return -1;

      final rawMessages = await SmsQuery().querySms(kinds: [SmsQueryKind.inbox]);
      rawMessages.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));

      // تجميع ومعالجة الرسائل المقسمة (Multipart SMS Stitching)
      List<_StitchedSMS> stitched = [];
      _StitchedSMS? current;

      for (var msg in rawMessages) {
        final sender = msg.address ?? '';
        final body = msg.body ?? '';
        final date = msg.date ?? DateTime.now();

        if (current != null && current.sender == sender && date.difference(current.date).inSeconds.abs() <= 3) {
          current.body += ' $body';
          current.ids.add(msg.id.toString());
        } else {
          if (current != null) stitched.add(current);
          current = _StitchedSMS(sender: sender, body: body, date: date, ids: [msg.id.toString()]);
        }
      }
      if (current != null) stitched.add(current);

      for (var s in stitched) {
        final bank = EgyptInstitutions.matchSender(s.sender);
        if (bank != null) {
          _processMessage(bank, s.body, s.date, s.ids.join('_'));
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  void _processMessage(BankEntity bank, String rawText, DateTime timestamp, String? uniqueSmsId) {
    final text = rawText.replaceAll('\n', ' ').trim();
    final fingerprint = uniqueSmsId ?? '${bank.id}_${timestamp.millisecondsSinceEpoch}_${text.hashCode}';

    // 1. تحديد المعرف ورقم الحساب/المحفظة
    String? phone;
    if (bank.entityType == EntityType.wallet) {
      final p = RegExp(r'(?:محفظتك|لرقم|على رقم)?\s*(01[0125][0-9]{8})').firstMatch(text);
      if (p != null) phone = p.group(1);
    }
    String? acc;
    if (bank.entityType == EntityType.bank) {
      final a = RegExp(r'(?:حسابك المنتهي بـ|بطاقتك المنتهية بـ)\s*(?:\*+)?(\d{4})').firstMatch(text);
      if (a != null) acc = '•••• ${a.group(1)}';
    }

    if (!userCards.any((c) => c.bankId == bank.id)) {
      addNewCard(bank, customId: phone ?? acc);
    }
    final card = userCards.firstWhere((c) => c.bankId == bank.id);

    if (phone != null && card.cardIdentifier.contains('X')) {
      card.cardIdentifier = phone;
      saveCards();
    } else if (acc != null && card.cardIdentifier.startsWith('•••• 0')) {
      card.cardIdentifier = acc;
      saveCards();
    }

    // 2. تحديث الرصيد حصرياً عند وجود نص صريح ومباشر
    final balMatch = RegExp(
      r'(?:رصيد(?:ك| حسابك)? (?:الحالي|المتاح)|رصيد محفظتك الحالي|current .*?balance is|balance is)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);

    if (balMatch != null) {
      final bVal = double.tryParse(balMatch.group(1)!);
      if (bVal != null) {
        card.balance = bVal;
        saveCards();
      }
    }

    final isInquiry = (text.contains('balance is') && !text.contains('transferred')) ||
        (text.startsWith('رصيد حسابك') && !text.contains('تم دفع') && !text.contains('تم تحويل') && !text.contains('تم استلام'));
    if (isInquiry) return;

    // 3. منع التكرار القاطع
    if (processedMessageFingerprints.contains(fingerprint)) return;

    // 4. تحليل المعاملة والطرف
    String title = 'معاملة مالية';
    String? sub;
    bool isIncome = false;

    if (text.contains('تم سحب') || text.contains('سحب نقدي') || text.contains('Cash withdrawal')) {
      title = 'سحب نقدي ATM';
      isIncome = false;
    } else if (text.contains('تم استلام') || text.contains('تحويل وارد') || text.contains('تحويل لحظي')) {
      isIncome = true;
      final name = RegExp(r'المسجل بإسم\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+على رقم|\s+رصيدك|\s+بتاريخ|\.)').firstMatch(text) ??
          RegExp(r'من\s+([A-Za-z\u0621-\u064A\s]+?)(?:\s+برقم مرجعي|\s+على رقم|\s+لحسابك|\s+بتاريخ|\.)').firstMatch(text);
      final pNum = RegExp(r'من رقم\s*(01[0125][0-9]{8})').firstMatch(text);
      if (name != null) {
        title = 'استلام من ${name.group(1)!.trim()}';
        if (pNum != null) sub = pNum.group(1);
      } else if (pNum != null) {
        title = 'استلام من ${pNum.group(1)}';
      } else {
        title = 'تحويل وارد';
      }
    } else if (text.contains('تم دفع') || text.contains('دفع مبلغ') || text.contains('شراء')) {
      isIncome = false;
      final m = RegExp(r'لـ?([A-Za-z0-9_\-\u0621-\u064A\s]+?)(?:\.|\s+رصيد|\s+رقم|\s+بمبلغ)').firstMatch(text);
      title = m != null ? 'دفع لـ ${m.group(1)!.trim()}' : 'سداد مشتريات';
    } else if (text.contains('تم تحويل') || text.contains('transferred to') || text.contains('تحويل إلى')) {
      isIncome = false;
      final tNum = RegExp(r'(?:لرقم|to|إلى)\s*(01[0125][0-9]{8})').firstMatch(text);
      title = tNum != null ? 'تحويل إلى ${tNum.group(1)}' : 'تحويل صادر';
    }

    final amtMatch = RegExp(r'(?:مبلغ|سحب|تحويل|transferred)\s*[:=]?\s*(\d+(?:\.\d{1,2})?)\s*(?:جنية|جنيه|ج\.م|L\.E|LE|EGP)?', caseSensitive: false).firstMatch(text) ??
        RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:L\.E|LE|EGP|جنية|جنيه|ج\.م)').firstMatch(text);

    if (amtMatch != null) {
      final amt = double.tryParse(amtMatch.group(1)!);
      if (amt != null && amt > 0 && amt != card.balance) {
        final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} • ${timestamp.day}/${timestamp.month}/${timestamp.year}';
        
        card.transactions.insert(0, TransactionItem(
          name: title, 
          subtitle: sub, 
          date: timeStr, 
          amount: amt, 
          isIncome: isIncome,
          txFingerprint: fingerprint,
        ));
        processedMessageFingerprints.add(fingerprint);
        saveCards();
      }
    }
  }
}

class _StitchedSMS {
  final String sender;
  String body;
  final DateTime date;
  final List<String> ids;
  _StitchedSMS({required this.sender, required this.body, required this.date, required this.ids});
}

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
  final String date;
  final double amount;
  final bool isIncome;
  final String? txFingerprint;

  TransactionItem({required this.name, this.subtitle, required this.date, required this.amount, required this.isIncome, this.txFingerprint});
  Map<String, dynamic> toJson() => {'name': name, 'subtitle': subtitle, 'date': date, 'amount': amount, 'isIncome': isIncome, 'txFingerprint': txFingerprint};
  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
    name: j['name'], subtitle: j['subtitle'], date: j['date'], amount: (j['amount'] as num).toDouble(), isIncome: j['isIncome'], txFingerprint: j['txFingerprint'],
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
        theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF2F4F7), fontFamily: 'sans-serif'),
        darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black, fontFamily: 'sans-serif'),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: AppleWalletScreen(appData: appData),
      ),
    );
  }
}

class AppleWalletScreen extends StatefulWidget {
  final AppData appData;
  const AppleWalletScreen({super.key, required this.appData});
  @override
  State<AppleWalletScreen> createState() => _AppleWalletScreenState();
}

class _AppleWalletScreenState extends State<AppleWalletScreen> {
  int? _expandedIndex;

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.appData.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(margin: const EdgeInsets.all(12), width: 44, height: 4.5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة بطاقة إلى المحفظة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${EgyptInstitutions.all.length} مؤسسة مصرية', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
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
                    leading: Container(
                      width: 52, height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                      child: entity.buildBrandLogo(height: 28),
                    ),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المحفظة', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 28),
                        tooltip: 'مزامنة دقيقة بدون تكرار',
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مزامنة تسلسلية دقيقة لمنع التكرار وتحديث الأرصدة...')));
                          await widget.appData.autoDetectChronological();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت مزامنة المعاملات بأمان')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.battery_charging_full_rounded, color: Colors.amber, size: 26),
                        tooltip: 'استثناء البطارية للعمل بالخلفية',
                        onPressed: () async {
                          await widget.appData.requestBatteryOptimizationIgnore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ضبط صلاحيات العمل بالخلفية')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 32),
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
                          Icon(Icons.credit_card_rounded, size: 70, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 14),
                          const Text('اضغط على علامة التزامن لمسح رسائل البنوك بالترتيب', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('إضافة بطاقة يدوياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: _openAddSheet,
                          )
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAppleStack(cards)),
                          if (_expandedIndex != null && _expandedIndex! < cards.length) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              onPressed: () => setState(() => _expandedIndex = null),
                              icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                              label: const Text('طي البطاقة'),
                            ),
                            const SizedBox(height: 16),
                            _buildTransactions(cards[_expandedIndex!], isDark),
                          ]
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleStack(List<UserCardModel> cards) {
    const double cardH = 220.0;
    const double peekH = 68.0;
    final double totalH = _expandedIndex == null ? (cardH + (cards.length - 1) * peekH) : (cardH + 20);

    return SizedBox(
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(cards.length, (i) {
          final card = cards[i];
          final isSelected = _expandedIndex == i;
          final top = _expandedIndex == null ? (i * peekH) : (isSelected ? 0.0 : (cardH + 30));
          final opacity = _expandedIndex == null ? 1.0 : (isSelected ? 1.0 : 0.0);

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            top: top, left: 0, right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: opacity,
              child: GestureDetector(
                onTap: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                child: _buildRealAppleCard(card),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRealAppleCard(UserCardModel card) {
    final bank = card.bank;
    final isWallet = bank.entityType == EntityType.wallet;

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bank.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withOpacity(0.12), Colors.transparent]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.cardTypeBadge,
                    style: TextStyle(color: bank.textColor.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  bank.buildBrandLogo(height: 32),
                ],
              ),
              Row(
                children: [
                  if (!isWallet) ...[
                    Container(
                      width: 44, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFAA8010), Color(0xFFF9E8A2)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: Center(
                        child: Container(
                          width: 30, height: 20,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black45, width: 0.8), borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.rotate(angle: 1.5708, child: Icon(Icons.wifi, size: 22, color: bank.textColor.withOpacity(0.7))),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 16, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('محفظة إلكترونية', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الرصيد الفعلي المتاح', style: TextStyle(color: bank.textColor.withOpacity(0.7), fontSize: 10)),
                      Text(
                        '${card.balance.toStringAsFixed(2)} ج.م',
                        style: TextStyle(color: bank.textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.cardIdentifier,
                    style: TextStyle(color: bank.textColor, fontSize: isWallet ? 17 : 16, fontWeight: FontWeight.bold, letterSpacing: isWallet ? 1.5 : 2.5),
                  ),
                  _buildPaymentNetworkLogo(bank.network),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentNetworkLogo(PaymentNetwork net) {
    switch (net) {
      case PaymentNetwork.visa:
        return const Text('VISA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 18));
      case PaymentNetwork.mastercard:
        return Row(
          children: [
            Container(width: 18, height: 18, decoration: const BoxDecoration(color: Color(0xFFEB001B), shape: BoxShape.circle)),
            Transform.translate(offset: const Offset(-6, 0), child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFF79E1B).withOpacity(0.85), shape: BoxShape.circle))),
          ],
        );
      case PaymentNetwork.meeza:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF005696), borderRadius: BorderRadius.circular(4)),
          child: const Text('ميزة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
        );
      case PaymentNetwork.walletInternal:
        return const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20);
    }
  }

  Widget _buildTransactions(UserCardModel card, bool isDark) {
    if (card.transactions.isEmpty) {
      return const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد معاملات مسجلة على هذا الحساب بعد', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: card.transactions.length,
      itemBuilder: (ctx, i) {
        final tx = card.transactions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(tx.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: tx.isIncome ? Colors.green : Colors.redAccent, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (tx.subtitle != null) Text(tx.subtitle!, style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                      Text(tx.date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
        );
      },
    );
  }
}
