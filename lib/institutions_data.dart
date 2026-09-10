import 'package:flutter/material.dart';

enum EntityType { bank, wallet, fintech }
enum PaymentNetwork { visa, mastercard, meeza, walletInternal }

class BankEntity {
  final String id, name, type, acronym;
  final EntityType entityType;
  final PaymentNetwork network;
  final List<String> exactSenders;
  final List<Color> gradientColors;
  final Color textColor;
  final String cardTypeBadge;
  final String logoPath;

  const BankEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.acronym,
    required this.entityType,
    required this.network,
    required this.exactSenders,
    required this.gradientColors,
    required this.textColor,
    required this.cardTypeBadge,
    required this.logoPath,
  });

  Widget buildBrandLogo({double height = 28}) {
    return Image.asset(
      'assets/logos/$logoPath',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          acronym,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
    );
  }
}

class EgyptInstitutions {
  static const List<BankEntity> all = [
    // --- المحافظ والـ FinTech ---
    BankEntity(id: 'voda', name: 'فودافون كاش', type: 'Vodafone Cash Wallet', acronym: 'VF-CASH', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['vf-cash', 'vfcash', 'vodafone'], gradientColors: [Color(0xFF3B0000), Color(0xFF800000), Color(0xFF1F0000)], textColor: Colors.white, cardTypeBadge: 'SMART E-WALLET', logoPath: 'voda.png'),
    BankEntity(id: 'instapay', name: 'إنستاباي مصر', type: 'InstaPay Egypt (EBC)', acronym: 'INSTAPAY', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['instapay', 'ebc'], gradientColors: [Color(0xFF240046), Color(0xFF3C096C), Color(0xFF10002B)], textColor: Colors.white, cardTypeBadge: 'INSTANT TRANSFER', logoPath: 'instapay.png'),
    BankEntity(id: 'orange', name: 'أورنج كاش', type: 'Orange Cash Wallet', acronym: 'ORANGE', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['orangecash', 'orange'], gradientColors: [Color(0xFF331600), Color(0xFF6B2D00), Color(0xFF1C0C00)], textColor: Colors.white, cardTypeBadge: 'ORANGE WALLET', logoPath: 'orange.png'),
    BankEntity(id: 'etisalat', name: 'إي آند كاش', type: 'e& Cash Wallet', acronym: 'e& CASH', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['etisalatcash', 'e&cash'], gradientColors: [Color(0xFF1A2E05), Color(0xFF30520A), Color(0xFF0F1A03)], textColor: Colors.white, cardTypeBadge: 'e& DIGITAL CASH', logoPath: 'etisalat.png'),
    BankEntity(id: 'we', name: 'وي باي (WE Pay)', type: 'WE Pay Telecom Egypt', acronym: 'WE PAY', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['wepay', 'telecomegypt'], gradientColors: [Color(0xFF280C4D), Color(0xFF441880), Color(0xFF16062B)], textColor: Colors.white, cardTypeBadge: 'WE PAY WALLET', logoPath: 'we.png'),
    BankEntity(id: 'fawry', name: 'محفظة فوري باي', type: 'Fawry Pay Wallet', acronym: 'FAWRY', entityType: EntityType.wallet, network: PaymentNetwork.walletInternal, exactSenders: ['fawry', 'myfawry'], gradientColors: [Color(0xFF3D2900), Color(0xFF6E4B00), Color(0xFF211700)], textColor: Colors.white, cardTypeBadge: 'YELLOW WALLET', logoPath: 'fawry.png'),
    BankEntity(id: 'telda', name: 'تيلدا', type: 'Telda Powered by BDC', acronym: 'TELDA', entityType: EntityType.fintech, network: PaymentNetwork.mastercard, exactSenders: ['telda'], gradientColors: [Color(0xFF0D0D0D), Color(0xFF1F1F1F), Color(0xFF000000)], textColor: Colors.white, cardTypeBadge: 'MASTERCARD PREPAID', logoPath: 'telda.png'),
    BankEntity(id: 'klivvr', name: 'كليفر', type: 'Klivvr FinTech', acronym: 'KLIVVR', entityType: EntityType.fintech, network: PaymentNetwork.visa, exactSenders: ['klivvr'], gradientColors: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF030712)], textColor: Colors.white, cardTypeBadge: 'PLATINUM VISA', logoPath: 'klivvr.png'),
    BankEntity(id: 'nexta', name: 'نكستا', type: 'Nexta Card', acronym: 'NEXTA', entityType: EntityType.fintech, network: PaymentNetwork.visa, exactSenders: ['nexta'], gradientColors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F0E26)], textColor: Colors.white, cardTypeBadge: 'NEXTA VISA', logoPath: 'nexta.png'),

    // --- البنوك المصرية الكبرى ---
    BankEntity(id: 'nbe', name: 'البنك الأهلي المصري', type: 'National Bank of Egypt', acronym: 'NBE', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['nbe', 'ahli'], gradientColors: [Color(0xFF003822), Color(0xFF005A36), Color(0xFF002416)], textColor: Colors.white, cardTypeBadge: 'PLATINUM DEBIT', logoPath: 'nbe.png'),
    BankEntity(id: 'misr', name: 'بنك مصر', type: 'BANQUE MISR', acronym: 'BM', entityType: EntityType.bank, network: PaymentNetwork.meeza, exactSenders: ['banquemisr', 'bm'], gradientColors: [Color(0xFF7A1518), Color(0xFF9E1F23), Color(0xFF4D0A0C)], textColor: Colors.white, cardTypeBadge: 'TITANIUM MEEZA', logoPath: 'misr.png'),
    BankEntity(id: 'cib', name: 'البنك التجاري الدولي', type: 'Commercial International Bank', acronym: 'CIB', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['cib', 'cibeg'], gradientColors: [Color(0xFF0B1F38), Color(0xFF133863), Color(0xFF071424)], textColor: Colors.white, cardTypeBadge: 'SIGNATURE VISA', logoPath: 'cib.png'),
    BankEntity(id: 'qnb', name: 'بنك QNB الأهلي', type: 'Qatar National Bank', acronym: 'QNB', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['qnb', 'qnbaa'], gradientColors: [Color(0xFF260017), Color(0xFF4D002E), Color(0xFF14000C)], textColor: Colors.white, cardTypeBadge: 'WORLD MASTERCARD', logoPath: 'qnb.png'),
    BankEntity(id: 'alex', name: 'بنك الإسكندرية', type: 'AlexBank Intesa Sanpaolo', acronym: 'ALEX', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['alexbank'], gradientColors: [Color(0xFF002B20), Color(0xFF004D39), Color(0xFF001711)], textColor: Colors.white, cardTypeBadge: 'GOLD VISA', logoPath: 'alex.png'),
    BankEntity(id: 'bdc', name: 'بنك القاهرة', type: 'Banque Du Caire', acronym: 'BDC', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['bdc', 'banqueducaire'], gradientColors: [Color(0xFF3B1506), Color(0xFF6B290E), Color(0xFF1F0B03)], textColor: Colors.white, cardTypeBadge: 'TITANIUM DEBIT', logoPath: 'bdc.png'),
    BankEntity(id: 'aaib', name: 'البنك العربي الإفريقي', type: 'Arab African Int. Bank', acronym: 'AAIB', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['aaib'], gradientColors: [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF060D17)], textColor: Colors.white, cardTypeBadge: 'SIGNATURE VISA', logoPath: 'aaib.png'),
    BankEntity(id: 'faisal', name: 'بنك فيصل الإسلامي', type: 'Faisal Islamic Bank', acronym: 'FAISAL', entityType: EntityType.bank, network: PaymentNetwork.meeza, exactSenders: ['fib', 'faisal'], gradientColors: [Color(0xFF063323), Color(0xFF065F46), Color(0xFF031F15)], textColor: Colors.white, cardTypeBadge: 'ISLAMIC GOLD', logoPath: 'faisal.png'),
    BankEntity(id: 'hsbc', name: 'بنك HSBC مصر', type: 'HSBC Bank Egypt', acronym: 'HSBC', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['hsbc', 'hsbceg'], gradientColors: [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF09090B)], textColor: Colors.white, cardTypeBadge: 'PREMIER VISA', logoPath: 'hsbc.png'),
    BankEntity(id: 'adib', name: 'مصرف أبوظبي الإسلامي', type: 'ADIB Egypt', acronym: 'ADIB', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['adib', 'adibeg'], gradientColors: [Color(0xFF0C2444), Color(0xFF1E40AF), Color(0xFF091A33)], textColor: Colors.white, cardTypeBadge: 'TITANIUM ISLAMIC', logoPath: 'adib.png'),
    BankEntity(id: 'fab', name: 'بنك أبوظبي الأول', type: 'FABMISR', acronym: 'FAB', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['fab', 'fabmisr'], gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)], textColor: Colors.white, cardTypeBadge: 'SIGNATURE MASTERCARD', logoPath: 'fab.png'),
    BankEntity(id: 'hdb', name: 'بنك التعمير والإسكان', type: 'Housing & Dev. Bank', acronym: 'HDB', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['hdb', 'hdbank'], gradientColors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F0E26)], textColor: Colors.white, cardTypeBadge: 'GOLD DEBIT', logoPath: 'hdb.png'),
    BankEntity(id: 'cae', name: 'كريدي أجريكول مصر', type: 'Crédit Agricole Egypt', acronym: 'CAE', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['cae', 'creditagricole'], gradientColors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF022C22)], textColor: Colors.white, cardTypeBadge: 'CLASSIC VISA', logoPath: 'cae.png'),
    BankEntity(id: 'albaraka', name: 'بنك البركة مصر', type: 'Al Baraka Bank Egypt', acronym: 'BARAKA', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['albaraka'], gradientColors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)], textColor: Colors.white, cardTypeBadge: 'ISLAMIC TITANIUM', logoPath: 'albaraka.png'),
    BankEntity(id: 'saib', name: 'بنك saib', type: 'Societe Arabe Internationale', acronym: 'SAIB', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['saib'], gradientColors: [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF0F0E26)], textColor: Colors.white, cardTypeBadge: 'PLATINUM DEBIT', logoPath: 'saib.png'),
    BankEntity(id: 'egb', name: 'البنك المصري لتنمية الصادرات', type: 'EBank Egypt', acronym: 'EBANK', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['ebank', 'edbe'], gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)], textColor: Colors.white, cardTypeBadge: 'CLASSIC DEBIT', logoPath: 'egb.png'),
    BankEntity(id: 'scb', name: 'بنك قناة السويس', type: 'Suez Canal Bank', acronym: 'SCB', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['scb', 'suezcanalbank'], gradientColors: [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF021B14)], textColor: Colors.white, cardTypeBadge: 'GOLD VISA', logoPath: 'scb.png'),
    BankEntity(id: 'abk', name: 'الأهلي الكويتي مصر', type: 'Al Ahli Bank of Kuwait', acronym: 'ABK', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['abk', 'abkegypt'], gradientColors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)], textColor: Colors.white, cardTypeBadge: 'WORLD MASTERCARD', logoPath: 'abk.png'),
    BankEntity(id: 'midbank', name: 'ميد بنك', type: 'MIDBANK Egypt', acronym: 'MID', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['midbank'], gradientColors: [Color(0xFF3B0721), Color(0xFF4C051E), Color(0xFF1F0414)], textColor: Colors.white, cardTypeBadge: 'CLASSIC VISA', logoPath: 'midbank.png'),
    BankEntity(id: 'ub', name: 'المصرف المتحد', type: 'The United Bank', acronym: 'UB', entityType: EntityType.bank, network: PaymentNetwork.meeza, exactSenders: ['ub', 'unitedbank'], gradientColors: [Color(0xFF0A2540), Color(0xFF0D3863), Color(0xFF051329)], textColor: Colors.white, cardTypeBadge: 'MEEZA DEBIT', logoPath: 'ub.png'),
    BankEntity(id: 'attijari', name: 'التجاري وفا بنك', type: 'Attijariwafa Bank Egypt', acronym: 'ATTIJARI', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['attijari', 'attijariwafa'], gradientColors: [Color(0xFF3F1607), Color(0xFF7C2D12), Color(0xFF230B02)], textColor: Colors.white, cardTypeBadge: 'TITANIUM DEBIT', logoPath: 'attijari.png'),
    BankEntity(id: 'egbank', name: 'البنك المصري الخليجي', type: 'EG Bank', acronym: 'EG-BANK', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['egbank'], gradientColors: [Color(0xFF0B3B24), Color(0xFF155734), Color(0xFF04180E)], textColor: Colors.white, cardTypeBadge: 'PLATINUM DEBIT', logoPath: 'egbank.png'),
    BankEntity(id: 'enbd', name: 'بنك الإمارات دبي الوطني', type: 'Emirates NBD Egypt', acronym: 'ENBD', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['enbd', 'emiratesnbd'], gradientColors: [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF060D17)], textColor: Colors.white, cardTypeBadge: 'TITANIUM DEBIT', logoPath: 'enbd.png'),
    BankEntity(id: 'nbk', name: 'بنك الكويت الوطني مصر', type: 'NBK Egypt', acronym: 'NBK', entityType: EntityType.bank, network: PaymentNetwork.mastercard, exactSenders: ['nbk', 'nbkegypt'], gradientColors: [Color(0xFF0C2444), Color(0xFF1E40AF), Color(0xFF091A33)], textColor: Colors.white, cardTypeBadge: 'PLATINUM MASTERCARD', logoPath: 'nbk.png'),
    BankEntity(id: 'arabbank', name: 'البنك العربي مصر', type: 'Arab Bank Egypt', acronym: 'ARAB', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['arabbank'], gradientColors: [Color(0xFF002B20), Color(0xFF004D39), Color(0xFF001711)], textColor: Colors.white, cardTypeBadge: 'SIGNATURE VISA', logoPath: 'arabbank.png'),
    BankEntity(id: 'abc', name: 'بنك المؤسسة العربية المصرفية', type: 'Bank ABC Egypt', acronym: 'ABC', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['bankabc', 'abc'], gradientColors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F0E26)], textColor: Colors.white, cardTypeBadge: 'GOLD VISA', logoPath: 'abc.png'),
    BankEntity(id: 'sc', name: 'بنك ستاندرد تشارترد مصر', type: 'Standard Chartered Egypt', acronym: 'SC', entityType: EntityType.bank, network: PaymentNetwork.visa, exactSenders: ['sc', 'standardchartered'], gradientColors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF022C22)], textColor: Colors.white, cardTypeBadge: 'INFINITE VISA', logoPath: 'sc.png'),
    BankEntity(id: 'abe', name: 'البنك الزراعي المصري', type: 'Agricultural Bank of Egypt', acronym: 'ABE', entityType: EntityType.bank, network: PaymentNetwork.meeza, exactSenders: ['abe'], gradientColors: [Color(0xFF003822), Color(0xFF005A36), Color(0xFF002416)], textColor: Colors.white, cardTypeBadge: 'MEEZA DEBIT', logoPath: 'abe.png'),
  ];

  static BankEntity? matchSender(String sender) {
    final clean = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (var bank in all) {
      for (var exact in bank.exactSenders) {
        if (clean == exact || clean.contains(exact)) return bank;
      }
    }
    return null;
  }
}
