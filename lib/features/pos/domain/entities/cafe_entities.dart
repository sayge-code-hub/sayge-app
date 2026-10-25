import 'package:equatable/equatable.dart';

enum CafeOrderType { dineIn, takeaway }

enum CafePrepStatus { neu, preparing, ready, completed, cancelled }

enum CafePaymentStatus { pending, paid, refunded }

enum CafePaymentMethod { cash, upi, card }

extension CafeOrderTypeX on CafeOrderType {
  String get dbValue => switch (this) {
        CafeOrderType.dineIn => 'dine_in',
        CafeOrderType.takeaway => 'takeaway',
      };

  String get label => switch (this) {
        CafeOrderType.dineIn => 'Dine-in',
        CafeOrderType.takeaway => 'Takeaway',
      };

  static CafeOrderType fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'takeaway':
        return CafeOrderType.takeaway;
      default:
        return CafeOrderType.dineIn;
    }
  }
}

extension CafePrepStatusX on CafePrepStatus {
  /// DB value — `new` is reserved in Dart enums so we use [CafePrepStatus.neu].
  String get dbValue => switch (this) {
        CafePrepStatus.neu => 'new',
        CafePrepStatus.preparing => 'preparing',
        CafePrepStatus.ready => 'ready',
        CafePrepStatus.completed => 'completed',
        CafePrepStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        CafePrepStatus.neu => 'New',
        CafePrepStatus.preparing => 'Preparing',
        CafePrepStatus.ready => 'Ready',
        CafePrepStatus.completed => 'Completed',
        CafePrepStatus.cancelled => 'Cancelled',
      };

  static CafePrepStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'preparing':
        return CafePrepStatus.preparing;
      case 'ready':
        return CafePrepStatus.ready;
      case 'completed':
        return CafePrepStatus.completed;
      case 'cancelled':
        return CafePrepStatus.cancelled;
      default:
        return CafePrepStatus.neu;
    }
  }
}

extension CafePaymentStatusX on CafePaymentStatus {
  String get dbValue => name;

  String get label => switch (this) {
        CafePaymentStatus.pending => 'Pending',
        CafePaymentStatus.paid => 'Paid',
        CafePaymentStatus.refunded => 'Refunded',
      };

  static CafePaymentStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'paid':
        return CafePaymentStatus.paid;
      case 'refunded':
        return CafePaymentStatus.refunded;
      default:
        return CafePaymentStatus.pending;
    }
  }
}

extension CafePaymentMethodX on CafePaymentMethod {
  String get dbValue => name;

  String get label => switch (this) {
        CafePaymentMethod.cash => 'Cash',
        CafePaymentMethod.upi => 'UPI',
        CafePaymentMethod.card => 'Card',
      };

  static CafePaymentMethod fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'upi':
        return CafePaymentMethod.upi;
      case 'card':
        return CafePaymentMethod.card;
      default:
        return CafePaymentMethod.cash;
    }
  }
}

/// Guest QR menu layout presets.
enum GuestMenuLayout {
  /// Light list with accent chips and qty pills (default).
  fresh,

  /// Two-column gallery cards with + buttons.
  gallery,

  /// Soft green home + circular item detail (reference “Detailed View”).
  detailed,
}

extension GuestMenuLayoutX on GuestMenuLayout {
  String get dbValue => name;

  String get label => switch (this) {
        GuestMenuLayout.fresh => 'Fresh',
        GuestMenuLayout.gallery => 'Gallery',
        GuestMenuLayout.detailed => 'Detailed View',
      };

  String get blurb => switch (this) {
        GuestMenuLayout.fresh => 'Bright chips, menu rows',
        GuestMenuLayout.gallery => 'Photo-style grid cards',
        GuestMenuLayout.detailed => 'Recommended, grid, item detail',
      };

  static GuestMenuLayout fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'gallery':
        return GuestMenuLayout.gallery;
      case 'detailed':
      case 'detailed_view':
      case 'detail':
        return GuestMenuLayout.detailed;
      case 'fresh':
      case 'night': // legacy → fresh
      default:
        return GuestMenuLayout.fresh;
    }
  }
}

/// POS tenant — created in Cafe POS, independent of Settings clients.
class Cafe extends Equatable {
  const Cafe({
    required this.id,
    required this.name,
    this.isActive = true,
    this.showGstOnBill = true,
    this.gstLabel = 'GST',
    this.gstSplitHalves = false,
    this.tableCount = 16,
    this.guestLogoPath = '',
    this.guestShowLogo = true,
    this.guestTagline = '',
    this.guestAccentHex = '',
    this.guestLayout = GuestMenuLayout.fresh,
    this.guestShowSearch = false,
  });

  final String id;
  final String name;
  final bool isActive;

  /// Show tax / GST lines on the terminal bill.
  final bool showGstOnBill;

  /// Bill label for tax (e.g. GST).
  final String gstLabel;

  /// Split tax into CGST + SGST (half each) on the bill.
  final bool gstSplitHalves;

  /// Numbered dine-in tables available on the terminal (1…[tableCount]).
  final int tableCount;

  /// Storage path in `brand-logos` for the guest QR menu logo.
  final String guestLogoPath;

  final bool guestShowLogo;
  final String guestTagline;

  /// Optional `#RRGGBB` accent; empty uses app highlight.
  final String guestAccentHex;

  final GuestMenuLayout guestLayout;
  final bool guestShowSearch;

  Cafe copyWith({
    String? id,
    String? name,
    bool? isActive,
    bool? showGstOnBill,
    String? gstLabel,
    bool? gstSplitHalves,
    int? tableCount,
    String? guestLogoPath,
    bool? guestShowLogo,
    String? guestTagline,
    String? guestAccentHex,
    GuestMenuLayout? guestLayout,
    bool? guestShowSearch,
  }) {
    return Cafe(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      showGstOnBill: showGstOnBill ?? this.showGstOnBill,
      gstLabel: gstLabel ?? this.gstLabel,
      gstSplitHalves: gstSplitHalves ?? this.gstSplitHalves,
      tableCount: tableCount ?? this.tableCount,
      guestLogoPath: guestLogoPath ?? this.guestLogoPath,
      guestShowLogo: guestShowLogo ?? this.guestShowLogo,
      guestTagline: guestTagline ?? this.guestTagline,
      guestAccentHex: guestAccentHex ?? this.guestAccentHex,
      guestLayout: guestLayout ?? this.guestLayout,
      guestShowSearch: guestShowSearch ?? this.guestShowSearch,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isActive,
        showGstOnBill,
        gstLabel,
        gstSplitHalves,
        tableCount,
        guestLogoPath,
        guestShowLogo,
        guestTagline,
        guestAccentHex,
        guestLayout,
        guestShowSearch,
      ];
}

class CafeCategory extends Equatable {
  const CafeCategory({
    required this.id,
    required this.cafeId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String cafeId;
  final String name;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, cafeId, name, sortOrder, isActive];
}

class CafeMenuAddon extends Equatable {
  const CafeMenuAddon({
    required this.id,
    required this.cafeId,
    required this.menuItemId,
    required this.name,
    required this.price,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String cafeId;
  final String menuItemId;
  final String name;
  final double price;
  final bool isActive;
  final int sortOrder;

  @override
  List<Object?> get props =>
      [id, cafeId, menuItemId, name, price, isActive, sortOrder];
}

class CafeMenuItem extends Equatable {
  const CafeMenuItem({
    required this.id,
    required this.cafeId,
    required this.categoryId,
    required this.name,
    required this.price,
    this.taxRate = 0,
    this.isAvailable = true,
    this.isActive = true,
    this.sortOrder = 0,
    this.categoryName = '',
    this.addons = const [],
  });

  final String id;
  final String cafeId;
  final String categoryId;
  final String name;
  final double price;
  final double taxRate;
  final bool isAvailable;
  final bool isActive;
  final int sortOrder;
  final String categoryName;
  final List<CafeMenuAddon> addons;

  CafeMenuItem copyWith({
    List<CafeMenuAddon>? addons,
    String? categoryName,
  }) {
    return CafeMenuItem(
      id: id,
      cafeId: cafeId,
      categoryId: categoryId,
      name: name,
      price: price,
      taxRate: taxRate,
      isAvailable: isAvailable,
      isActive: isActive,
      sortOrder: sortOrder,
      categoryName: categoryName ?? this.categoryName,
      addons: addons ?? this.addons,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cafeId,
        categoryId,
        name,
        price,
        taxRate,
        isAvailable,
        isActive,
        sortOrder,
        categoryName,
        addons,
      ];
}

class CafeOrderItem extends Equatable {
  const CafeOrderItem({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.taxRate = 0,
    this.notes = '',
    this.sortOrder = 0,
  });

  final String id;
  final String? menuItemId;
  final String itemName;
  final double unitPrice;
  final double taxRate;
  final double quantity;
  final double lineTotal;
  final String notes;
  final int sortOrder;

  @override
  List<Object?> get props => [
        id,
        menuItemId,
        itemName,
        unitPrice,
        taxRate,
        quantity,
        lineTotal,
        notes,
        sortOrder,
      ];
}

class CafeOrder extends Equatable {
  const CafeOrder({
    required this.id,
    required this.cafeId,
    required this.orderNo,
    required this.orderType,
    required this.prepStatus,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
    this.cancelReason = '',
    this.cancelledAt,
    this.couponId,
    this.couponCode = '',
    this.tableNo = '',
  });

  final String id;
  final String cafeId;
  final String orderNo;
  final CafeOrderType orderType;
  final CafePrepStatus prepStatus;
  final CafePaymentStatus paymentStatus;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final DateTime createdAt;
  final List<CafeOrderItem> items;
  final String cancelReason;
  final DateTime? cancelledAt;
  final String? couponId;
  final String couponCode;

  /// Dine-in table number; empty for takeaway.
  final String tableNo;

  @override
  List<Object?> get props => [
        id,
        cafeId,
        orderNo,
        orderType,
        prepStatus,
        paymentStatus,
        subtotal,
        taxAmount,
        discountAmount,
        totalAmount,
        createdAt,
        items,
        cancelReason,
        cancelledAt,
        couponId,
        couponCode,
        tableNo,
      ];
}

class CafePayment extends Equatable {
  const CafePayment({
    required this.id,
    required this.orderId,
    required this.cafeId,
    required this.method,
    required this.amount,
    required this.recordedAt,
  });

  final String id;
  final String orderId;
  final String cafeId;
  final CafePaymentMethod method;
  final double amount;
  final DateTime recordedAt;

  @override
  List<Object?> get props =>
      [id, orderId, cafeId, method, amount, recordedAt];
}

class CafeDailyReport extends Equatable {
  const CafeDailyReport({
    required this.date,
    required this.orderCount,
    required this.totalSales,
    required this.byPaymentMethod,
    required this.itemSales,
  });

  final DateTime date;
  final int orderCount;
  final double totalSales;
  final Map<CafePaymentMethod, double> byPaymentMethod;
  final List<CafeItemSale> itemSales;

  @override
  List<Object?> get props =>
      [date, orderCount, totalSales, byPaymentMethod, itemSales];
}

class CafeItemSale extends Equatable {
  const CafeItemSale({
    required this.itemName,
    required this.quantity,
    required this.value,
  });

  final String itemName;
  final double quantity;
  final double value;

  @override
  List<Object?> get props => [itemName, quantity, value];
}

class CafeCartLine {
  CafeCartLine({
    required this.menuItem,
    this.quantity = 1,
    this.notes = '',
    List<CafeMenuAddon>? addons,
  }) : addons = List<CafeMenuAddon>.of(addons ?? const []);

  final CafeMenuItem menuItem;
  double quantity;
  String notes;
  final List<CafeMenuAddon> addons;

  String get addonKey {
    final ids = addons.map((a) => a.id).toList()..sort();
    return ids.join('|');
  }

  double get addonsTotal =>
      addons.fold<double>(0, (s, a) => s + a.price);

  double get unitPrice => menuItem.price + addonsTotal;

  double get lineTotal => unitPrice * quantity;

  String get displayName {
    if (addons.isEmpty) return menuItem.name;
    final extras = addons.map((a) => a.name).join(', ');
    return '${menuItem.name} (+$extras)';
  }

  bool matches(CafeMenuItem item, List<CafeMenuAddon> selected) {
    if (item.id != menuItem.id) return false;
    final other = List<CafeMenuAddon>.of(selected)
      ..sort((a, b) => a.id.compareTo(b.id));
    final mine = List<CafeMenuAddon>.of(addons)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (mine.length != other.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i].id != other[i].id) return false;
    }
    return true;
  }
}

enum CafeDiscountType { percent, fixed }

extension CafeDiscountTypeX on CafeDiscountType {
  String get dbValue => name;

  String get label => switch (this) {
        CafeDiscountType.percent => 'Percent %',
        CafeDiscountType.fixed => 'Fixed amount',
      };

  static CafeDiscountType fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'fixed':
        return CafeDiscountType.fixed;
      default:
        return CafeDiscountType.percent;
    }
  }
}

class CafeCoupon extends Equatable {
  const CafeCoupon({
    required this.id,
    required this.cafeId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.name = '',
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.maxUses,
    this.usageCount = 0,
  });

  final String id;
  final String cafeId;
  final String code;
  final String name;
  final CafeDiscountType discountType;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? maxUses;
  final int usageCount;

  /// Discount amount for a cart subtotal (before tax). Never exceeds [subtotal]+[tax].
  double discountFor({required double subtotal, required double tax}) {
    if (subtotal <= 0) return 0;
    if (minOrderAmount > 0 && subtotal < minOrderAmount) return 0;
    double amount;
    if (discountType == CafeDiscountType.percent) {
      amount = subtotal * (discountValue / 100);
      final cap = maxDiscountAmount;
      if (cap != null && cap > 0 && amount > cap) amount = cap;
    } else {
      amount = discountValue;
    }
    final maxAllowed = subtotal + tax;
    if (amount > maxAllowed) amount = maxAllowed;
    if (amount < 0) return 0;
    return double.parse(amount.toStringAsFixed(2));
  }

  String? validationError({required double subtotal}) {
    if (!isActive) return 'This coupon is inactive.';
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) {
      return 'This coupon is not active yet.';
    }
    if (endsAt != null && now.isAfter(endsAt!)) {
      return 'This coupon has expired.';
    }
    if (maxUses != null && usageCount >= maxUses!) {
      return 'This coupon has reached its usage limit.';
    }
    if (minOrderAmount > 0 && subtotal < minOrderAmount) {
      return 'Minimum order is required for this coupon.';
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        cafeId,
        code,
        name,
        discountType,
        discountValue,
        minOrderAmount,
        maxDiscountAmount,
        isActive,
        startsAt,
        endsAt,
        maxUses,
        usageCount,
      ];
}
