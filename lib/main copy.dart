import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  parseAndSaveTransaction(message.body ?? '', message.address ?? 'SMS', 'SMS');
}

void parseAndSaveTransaction(String body, String sender, String source) async {
  // 1. فلتر الأمان: تجاهل الرسائل المؤقتة وأكواد التحقق (OTP)
  final String lowerBody = body.toLowerCase();
  final List<String> ignoreKeywords = [
    'otp',
    'الرقم السري المتغير',
    'رمز التحقق',
    'لتأكيد',
    'one time password',
    'ceiling amount',
    'valid for one time',
    'كود التأكيد'
  ];

  for (final word in ignoreKeywords) {
    if (lowerBody.contains(word)) {
      return; // تجاهل الرسالة تماماً
    }
  }

  // 2. استخراج الرصيد المتاح / المتبقي / الحالي
  double? availableBalance;
  final RegExp balanceRegex = RegExp(
    r'(?:الرصيد المتاح|رصيد حسابك.*?الحالي|رصيد محفظتك الحالي|رصيدك الحالي|المتاح|current.*?balance is)\s*:?[\s]*(?:EGP|جم|ج\.م|جنيه|جنية|LE|L\.E)?\s*([\d,]+(?:\.\d{1,2})?)\s*(?:EGP|جم|ج\.م|جنيه|جنية|LE|L\.E)?',
    caseSensitive: false,
  );

  final balanceMatch = balanceRegex.firstMatch(body);
  if (balanceMatch != null) {
    String cleanBal = (balanceMatch.group(1) ?? '0').replaceAll(',', '');
    availableBalance = double.tryParse(cleanBal);
  }

  final prefs = await SharedPreferences.getInstance();
  if (availableBalance != null) {
    await prefs.setDouble('last_known_balance', availableBalance);
  }

  // 3. استثناء جزء الرصيد لمنع التداخل مع مبلغ العملية
  String textForTx = body;
  if (balanceMatch != null) {
    textForTx = body.substring(0, balanceMatch.start);
  }

  // 4. استخراج مبلغ العملية الفعلية
  final RegExp txRegex = RegExp(
    r'(?:مبلغ|بمبلغ|خصم|سحب|تحويل|transferred|استلام)?\s*(?:EGP|جم|ج\.م|جنيه|جنية|LE|L\.E)?\s*([\d,]+(?:\.\d{1,2})?)\s*(?:EGP|جم|ج\.م|جنيه|جنية|LE|L\.E)',
    caseSensitive: false,
  );

  final txMatch = txRegex.firstMatch(textForTx);

  // إذا كانت الرسالة مجرد استعلام عن الرصيد بدون معاملة شراء أو تحويل
  if (txMatch == null) {
    return;
  }

  String cleanAmount = (txMatch.group(1) ?? '0').replaceAll(',', '');
  double amount = double.tryParse(cleanAmount) ?? 0.0;

  if (amount <= 0) return;

  // 5. تحديد نوع المعاملة (إيداع أم خصم)
  String type = 'خصم';
  final List<String> depositKeywords = [
    'إيداع',
    'إلى حسابك',
    'لحسابكم',
    'استلام',
    'تم إضافة',
    'credited',
    'received',
    'deposit'
  ];

  for (final dep in depositKeywords) {
    if (body.contains(dep)) {
      type = 'إيداع';
      break;
    }
  }

  // 6. حفظ المعاملة
  List<String> list = prefs.getStringList('transactions') ?? [];
  Map<String, dynamic> tx = {
    'amount': amount,
    'type': type,
    'sender': sender,
    'source': source,
    'balanceAfter': availableBalance,
    'date': DateTime.now().toIso8601String(),
    'body': body,
  };

  list.insert(0, jsonEncode(tx));
  await prefs.setStringList('transactions', list);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QersheenApp());
}

class QersheenApp extends StatelessWidget {
  const QersheenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qersheen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B132B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF48CAE4),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  List<Map<String, dynamic>> transactions = [];
  double currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    initListeners();
    loadData();
  }

  Future<void> initListeners() async {
    final smsStatus = await Permission.sms.request();
    if (smsStatus.isGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          parseAndSaveTransaction(message.body ?? '', message.address ?? 'SMS', 'SMS');
          loadData();
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    }

    bool isNotificationGranted = await NotificationListenerService.isPermissionGranted();
    if (!isNotificationGranted) {
      await NotificationListenerService.requestPermission();
    }

    NotificationListenerService.notificationsStream.listen((event) {
      if (event.content != null && event.content!.isNotEmpty) {
        parseAndSaveTransaction(
          '${event.title ?? ""} - ${event.content ?? ""}',
          event.packageName ?? 'Notification',
          'Notification',
        );
        loadData();
      }
    });
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('transactions') ?? [];
    double bal = prefs.getDouble('last_known_balance') ?? 0.0;
    setState(() {
      transactions = list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      currentBalance = bal;
    });
  }

  double get totalSpent {
    return transactions
        .where((t) => t['type'] == 'خصم')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qersheen | قرشين'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الرصيد الفعلي المتاح:', style: TextStyle(color: Colors.white70)),
                    Text(
                      '${currentBalance.toStringAsFixed(2)} جم',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF48CAE4)),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي المصروفات:', style: TextStyle(color: Colors.white70)),
                    Text(
                      '${totalSpent.toStringAsFixed(2)} جم',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('لا توجد معاملات مسجلة بعد'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final item = transactions[index];
                      final isExpense = item['type'] == 'خصم';
                      return Card(
                        color: const Color(0xFF1C2541),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isExpense ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            child: Icon(
                              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isExpense ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                          title: Text(
                            '${item['amount']} جم',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item['balanceAfter'] != null
                                ? 'الرصيد بعدها: ${item['balanceAfter']} جم'
                                : (item['body'] ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: Text(
                            item['type'],
                            style: TextStyle(
                              color: isExpense ? Colors.redAccent : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
