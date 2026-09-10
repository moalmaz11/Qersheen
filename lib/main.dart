import 'package:flutter/material.dart';

void main() {
  runApp(const QersheenApp());
}

class QersheenApp extends StatefulWidget {
  const QersheenApp({super.key});

  @override
  State<QersheenApp> createState() => _QersheenAppState();
}

class _QersheenAppState extends State<QersheenApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'قرشين',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEEF3F8),
        fontFamily: 'sans-serif',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050811),
        fontFamily: 'sans-serif',
      ),
      home: WalletMasterScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class BankEntity {
  final String id;
  final String name;
  final String type;
  final String acronym;
  final Color primaryColor;
  final Color secondaryColor;
  final Color badgeBg;
  final Color badgeText;
  final IconData? icon;

  const BankEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.acronym,
    required this.primaryColor,
    required this.secondaryColor,
    required this.badgeBg,
    required this.badgeText,
    this.icon,
  });
}

class EgyptInstitutions {
  static const List<BankEntity> all = [
    BankEntity(id: 'cib', name: 'البنك التجاري الدولي', type: 'بنك تجاري • IPN', acronym: 'CIB', primaryColor: Color(0xFF0B1A30), secondaryColor: Color(0xFF0369A1), badgeBg: Color(0xFF38BDF8), badgeText: Color(0xFF0B1A30)),
    BankEntity(id: 'nbe', name: 'البنك الأهلي المصري', type: 'بنك قطاع عام • IPN', acronym: 'NBE', primaryColor: Color(0xFF072B19), secondaryColor: Color(0xFF0E5431), badgeBg: Color(0xFFEAB308), badgeText: Color(0xFF064E3B)),
    BankEntity(id: 'misr', name: 'بنك مصر', type: 'بنك قطاع عام • IPN', acronym: 'BM', primaryColor: Color(0xFF4A0A10), secondaryColor: Color(0xFF7F1D1D), badgeBg: Color(0xFFDC2626), badgeText: Colors.white),
    BankEntity(id: 'qnb', name: 'بنك قطر الوطني الأهلي', type: 'بنك خاص • IPN', acronym: 'QNB', primaryColor: Color(0xFF3B071A), secondaryColor: Color(0xFF5B102A), badgeBg: Color(0xFF9D174D), badgeText: Colors.white),
    BankEntity(id: 'alex', name: 'بنك الإسكندرية', type: 'بنك خاص • IPN', acronym: 'ALEX', primaryColor: Color(0xFF022C22), secondaryColor: Color(0xFF047857), badgeBg: Color(0xFF10B981), badgeText: Colors.white),
    BankEntity(id: 'caire', name: 'بنك القاهرة', type: 'بنك قطاع عام • IPN', acronym: 'BDC', primaryColor: Color(0xFF431407), secondaryColor: Color(0xFF9A3412), badgeBg: Color(0xFFF97316), badgeText: Colors.white),
    BankEntity(id: 'hsbc', name: 'بنك HSBC مصر', type: 'بنك دولي • IPN', acronym: 'HSBC', primaryColor: Color(0xFF18181B), secondaryColor: Color(0xFF27272A), badgeBg: Color(0xFFDC2626), badgeText: Colors.white),
    BankEntity(id: 'adib', name: 'مصرف أبوظبي الإسلامي', type: 'مصرف إسلامي • IPN', acronym: 'ADIB', primaryColor: Color(0xFF0C2444), secondaryColor: Color(0xFF1D4ED8), badgeBg: Color(0xFF60A5FA), badgeText: Color(0xFF0C2444)),
    BankEntity(id: 'faisal', name: 'بنك فيصل الإسلامي', type: 'مصرف إسلامي • IPN', acronym: 'FAISAL', primaryColor: Color(0xFF063323), secondaryColor: Color(0xFF047857), badgeBg: Color(0xFFFBBF24), badgeText: Color(0xFF063323)),
    BankEntity(id: 'hdb', name: 'بنك التعمير والإسكان', type: 'بنك تجاري • IPN', acronym: 'HDB', primaryColor: Color(0xFF1E1B4B), secondaryColor: Color(0xFF3730A3), badgeBg: Color(0xFF818CF8), badgeText: Colors.white),
    BankEntity(id: 'aaib', name: 'البنك العربي الإفريقي الدولي', type: 'بنك دولي • IPN', acronym: 'AAIB', primaryColor: Color(0xFF0B192C), secondaryColor: Color(0xFF1E3E62), badgeBg: Color(0xFF00ADB5), badgeText: Colors.white),
    BankEntity(id: 'fab', name: 'بنك أبوظبي الأول مصر', type: 'بنك خاص • IPN', acronym: 'FAB', primaryColor: Color(0xFF0F172A), secondaryColor: Color(0xFF1E293B), badgeBg: Color(0xFFDC2626), badgeText: Colors.white),
    BankEntity(id: 'adcb', name: 'بنك أبوظبي التجاري', type: 'بنك تجاري • IPN', acronym: 'ADCB', primaryColor: Color(0xFF450A0A), secondaryColor: Color(0xFF7F1D1D), badgeBg: Color(0xFFEF4444), badgeText: Colors.white),
    BankEntity(id: 'ca', name: 'كريدي أجريكول مصر', type: 'بنك دولي • IPN', acronym: 'CA', primaryColor: Color(0xFF064E3B), secondaryColor: Color(0xFF059669), badgeBg: Color(0xFF34D399), badgeText: Color(0xFF064E3B)),
    BankEntity(id: 'enbd', name: 'بنك الإمارات دبي الوطني', type: 'بنك خاص • IPN', acronym: 'ENBD', primaryColor: Color(0xFF172554), secondaryColor: Color(0xFF1E40AF), badgeBg: Color(0xFF3B82F6), badgeText: Colors.white),
    BankEntity(id: 'arab', name: 'البنك العربي مصر', type: 'بنك عربي • IPN', acronym: 'ARAB', primaryColor: Color(0xFF1E1B4B), secondaryColor: Color(0xFF312E81), badgeBg: Color(0xFF6366F1), badgeText: Colors.white),
    BankEntity(id: 'baraka', name: 'بنك البركة مصر', type: 'مصرف إسلامي • IPN', acronym: 'BARAKA', primaryColor: Color(0xFF0C2E20), secondaryColor: Color(0xFF14532D), badgeBg: Color(0xFFFBBF24), badgeText: Color(0xFF0C2E20)),
    BankEntity(id: 'scb', name: 'بنك قناة السويس', type: 'بنك تجاري • IPN', acronym: 'SCB', primaryColor: Color(0xFF032541), secondaryColor: Color(0xFF0B4F8A), badgeBg: Color(0xFF38BDF8), badgeText: Colors.white),
    BankEntity(id: 'saib', name: 'بنك saib', type: 'بنك خاص • IPN', acronym: 'SAIB', primaryColor: Color(0xFF1E293B), secondaryColor: Color(0xFF334155), badgeBg: Color(0xFFF59E0B), badgeText: Color(0xFF1E293B)),
    BankEntity(id: 'ub', name: 'المصرف المتحد', type: 'مصرف تجاري • IPN', acronym: 'UB', primaryColor: Color(0xFF042F2C), secondaryColor: Color(0xFF0F766E), badgeBg: Color(0xFF2DD4BF), badgeText: Color(0xFF042F2C)),
    BankEntity(id: 'nbk', name: 'بنك الكويت الوطني مصر', type: 'بنك خاص • IPN', acronym: 'NBK', primaryColor: Color(0xFF172554), secondaryColor: Color(0xFF1E3A8A), badgeBg: Color(0xFF60A5FA), badgeText: Colors.white),
    BankEntity(id: 'abk', name: 'البنك الأهلي الكويتي مصر', type: 'بنك خاص • IPN', acronym: 'ABK', primaryColor: Color(0xFF111827), secondaryColor: Color(0xFF1F2937), badgeBg: Color(0xFFEF4444), badgeText: Colors.white),
    BankEntity(id: 'attijari', name: 'التجاري وفا بنك مصر', type: 'بنك خاص • IPN', acronym: 'WAFA', primaryColor: Color(0xFF451A03), secondaryColor: Color(0xFF78350F), badgeBg: Color(0xFFF59E0B), badgeText: Colors.white),
    BankEntity(id: 'voda', name: 'فودافون كاش', type: 'محفظة إلكترونية', acronym: 'VODA CASH', primaryColor: Color(0xFF3D0714), secondaryColor: Color(0xFF991B1B), badgeBg: Color(0xFFEF4444), badgeText: Colors.white, icon: Icons.phone_android_rounded),
    BankEntity(id: 'orange', name: 'أورنج كاش', type: 'محفظة إلكترونية', acronym: 'ORANGE CASH', primaryColor: Color(0xFF431407), secondaryColor: Color(0xFFC2410C), badgeBg: Color(0xFFF97316), badgeText: Colors.white, icon: Icons.cell_tower_rounded),
    BankEntity(id: 'etisalat', name: 'إي آند كاش (اتصالات)', type: 'محفظة إلكترونية', acronym: 'e& CASH', primaryColor: Color(0xFF142900), secondaryColor: Color(0xFF365E00), badgeBg: Color(0xFF65A30D), badgeText: Colors.white, icon: Icons.wifi_calling_3_rounded),
    BankEntity(id: 'we', name: 'وي باي (WE Pay)', type: 'محفظة إلكترونية', acronym: 'WE PAY', primaryColor: Color(0xFF2E1065), secondaryColor: Color(0xFF581C87), badgeBg: Color(0xFF9333EA), badgeText: Colors.white, icon: Icons.language_rounded),
    BankEntity(id: 'fawry', name: 'محفظة فوري باي', type: 'محفظة ومدفوعات', acronym: 'FAWRY', primaryColor: Color(0xFF361C02), secondaryColor: Color(0xFF854D0E), badgeBg: Color(0xFFFACC15), badgeText: Color(0xFF361C02), icon: Icons.payment_rounded),
    BankEntity(id: 'telda', name: 'تيلدا (Telda)', type: 'بطاقة مدفوعات', acronym: 'TELDA', primaryColor: Color(0xFF09090B), secondaryColor: Color(0xFF18181B), badgeBg: Color(0xFF22C55E), badgeText: Colors.black, icon: Icons.credit_card_rounded),
    BankEntity(id: 'klivvr', name: 'كليفر (Klivvr)', type: 'بطاقة مدفوعات', acronym: 'KLIVVR', primaryColor: Color(0xFF1E1B4B), secondaryColor: Color(0xFF312E81), badgeBg: Color(0xFF818CF8), badgeText: Colors.white, icon: Icons.credit_card_rounded),
  ];

  static BankEntity getById(String id) {
    return all.firstWhere((e) => e.id == id, orElse: () => all[0]);
  }
}

class UserCardModel {
  final BankEntity entity;
  final String title;
  final String balance;
  final String subText;
  final List<TransactionItem> transactions;

  UserCardModel({
    required this.entity,
    required this.title,
    required this.balance,
    required this.subText,
    required this.transactions,
  });
}

class TransactionItem {
  final String name;
  final String date;
  final String amount;
  final bool isIncome;

  TransactionItem({
    required this.name,
    required this.date,
    required this.amount,
    required this.isIncome,
  });
}

class WalletMasterScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const WalletMasterScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<WalletMasterScreen> createState() => _WalletMasterScreenState();
}

class _WalletMasterScreenState extends State<WalletMasterScreen> {
  int _activeNav = 0;
  List<int> _stackOrder = [];

  late final List<UserCardModel> _userCards = [
    UserCardModel(
      entity: EgyptInstitutions.getById('cib'),
      title: 'الحساب الجاري الرئيسي',
      balance: '48,250.00 ج.م',
      subText: 'متزامن مع إشعارات SMS •••• 9042',
      transactions: [
        TransactionItem(name: 'تحويل وارد عبر إنستاباي', date: 'أحمد كمال • اليوم 02:15 م', amount: '+3,500 ج.م', isIncome: true),
        TransactionItem(name: 'فاتورة الكهرباء والغاز', date: 'سداد فوري إلكتروني', amount: '-420.00 ج.م', isIncome: false),
        TransactionItem(name: 'اشتراك Netflix الشهري', date: 'استحقاق خلال 48 ساعة', amount: '-950.00 ج.م', isIncome: false),
      ],
    ),
    UserCardModel(
      entity: EgyptInstitutions.getById('nbe'),
      title: 'حساب المرتبات والمعاملات',
      balance: '18,500.00 ج.م',
      subText: 'ربط الحساب البنكي •••• 1845',
      transactions: [
        TransactionItem(name: 'إيداع المرتب الشهري', date: 'تحويل بنكي • 1 سبتمبر', amount: '+18,500 ج.م', isIncome: true),
        TransactionItem(name: 'سحب صراف آلي ATM', date: 'ماكينة الأهلي • أمس', amount: '-2,000 ج.م', isIncome: false),
      ],
    ),
    UserCardModel(
      entity: EgyptInstitutions.getById('misr'),
      title: 'حساب التوفير والودائع',
      balance: '35,000.00 ج.م',
      subText: 'عائد شهري منتظم •••• 6120',
      transactions: [
        TransactionItem(name: 'إيداع عائد الشهادة البنكية', date: 'بنك مصر • أول الشهر', amount: '+640.00 ج.م', isIncome: true),
      ],
    ),
    UserCardModel(
      entity: EgyptInstitutions.getById('voda'),
      title: 'رصيد الكاش والمحفظة الرقمية',
      balance: '2,450.00 ج.م',
      subText: 'جاهز للدفع الفوري 010 •••• 9921',
      transactions: [
        TransactionItem(name: 'شحن رصيد باقة فليكس', date: 'فودافون مصر • منذ ساعتين', amount: '-150.00 ج.م', isIncome: false),
        TransactionItem(name: 'استلام كاش من عميل', date: 'تحويل فوري • أمس', amount: '+1,200 ج.م', isIncome: true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _stackOrder = List.generate(_userCards.length, (i) => i);
  }

  void _bringCardToFront(int cardIndex) {
    final currentPos = _stackOrder.indexOf(cardIndex);
    if (currentPos == 0) return;

    setState(() {
      _stackOrder.removeAt(currentPos);
      _stackOrder.insert(0, cardIndex);
    });
  }

  void _openAddCardDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0D1424) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة حساب بنكي أو محفظة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${EgyptInstitutions.all.length} متاح',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: EgyptInstitutions.all.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final entity = EgyptInstitutions.all[idx];
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        tileColor: widget.isDarkMode ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9),
                        leading: _buildInstitutionBadge(entity),
                        title: Text(entity.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(entity.type, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        trailing: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF10B981)),
                        onTap: () {
                          setState(() {
                            _userCards.insert(
                              0,
                              UserCardModel(
                                entity: entity,
                                title: 'حساب جديد',
                                balance: '0.00 ج.م',
                                subText: 'تم الربط حديثاً • متزامن',
                                transactions: [
                                  TransactionItem(name: 'تفعيل الحساب في قرشين', date: 'الآن', amount: '0.00 ج.م', isIncome: true),
                                ],
                              ),
                            );
                            _stackOrder = List.generate(_userCards.length, (i) => i);
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final activeCard = _userCards[_stackOrder[0]];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
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
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قرشين',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'المحفظة الذكية • متزامن لحظياً',
                            style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _openAddCardDialog,
                        icon: const Icon(Icons.add_circle_rounded),
                        color: const Color(0xFF10B981),
                        tooltip: 'إضافة حساب جديد',
                      ),
                      IconButton(
                        onPressed: widget.onToggleTheme,
                        icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 310,
                child: Stack(
                  children: List.generate(_userCards.length, (cardIndex) {
                    final position = _stackOrder.indexOf(cardIndex);
                    return _buildAnimatedCard(cardIndex, position);
                  }),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121A2B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('معدل الصرف اليومي الآمن:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    Text('620.00 ج.م / اليوم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'عمليات: ${activeCard.entity.name}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                  ),
                  const Text('عرض الكشف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 6),

              Expanded(
                child: ListView.separated(
                  itemCount: activeCard.transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = activeCard.transactions[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121A2B).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (item.isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  size: 16,
                                  color: item.isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text(item.date, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            item.amount,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: item.isIncome ? const Color(0xFF10B981) : (item.amount.startsWith('-') ? const Color(0xFFEF4444) : null),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D121E).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(0, Icons.wallet_rounded, 'المحفظة'),
                    _navItem(1, Icons.show_chart_rounded, 'التحليلات'),
                    _navItem(2, Icons.pie_chart_outline_rounded, 'الميزانية'),
                    _navItem(3, Icons.tune_rounded, 'الإعدادات'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(int cardIndex, int position) {
    final card = _userCards[cardIndex];
    final double topOffset = position * 44.0;
    final double scale = 1.0 - (position * 0.035);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      top: topOffset,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => _bringCardToFront(cardIndex),
        child: Transform.scale(
          scale: scale,
          child: Container(
            height: 190,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [card.entity.primaryColor, card.entity.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: card.entity.badgeBg.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInstitutionBadge(card.entity),
                    Text(
                      card.entity.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      card.balance,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Text(card.subText, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildInstitutionBadge(BankEntity entity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entity.badgeBg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: entity.badgeBg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entity.icon != null) ...[
            Icon(entity.icon, size: 12, color: entity.badgeBg),
            const SizedBox(width: 4),
          ],
          Text(
            entity.acronym,
            style: TextStyle(color: entity.badgeBg, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _activeNav == index;
    final color = isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B);

    return InkWell(
      onTap: () => setState(() => _activeNav = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
