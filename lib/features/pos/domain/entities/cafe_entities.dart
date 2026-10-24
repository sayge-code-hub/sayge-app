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

class CafeCategory extends Equatable {
  const CafeCategory({
    required this.id,
    required this.clientId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String clientId;
  final String name;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, clientId, name, sortOrder, isActive];
}

class CafeMenuItem extends Equatable {
  const CafeMenuItem({
    required this.id,
    required this.clientId,
    required this.categoryId,
    required this.name,
    required this.price,
    this.taxRate = 0,
    this.isAvailable = true,
    this.isActive = true,
    this.sortOrder = 0,
    this.categoryName = '',
  });

  final String id;
  final String clientId;
  final String categoryId;
  final String name;
  final double price;
  final double taxRate;
  final bool isAvailable;
  final bool isActive;
  final int sortOrder;
  final String categoryName;

  @override
  List<Object?> get props => [
        id,
        clientId,
        categoryId,
        name,
        price,
        taxRate,
        isAvailable,
        isActive,
        sortOrder,
        categoryName,
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
    required this.clientId,
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
  });

  final String id;
  final String clientId;
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

  @override
  List<Object?> get props => [
        id,
        clientId,
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
      ];
}

class CafePayment extends Equatable {
  const CafePayment({
    required this.id,
    required this.orderId,
    required this.clientId,
    required this.method,
    required this.amount,
    required this.recordedAt,
  });

  final String id;
  final String orderId;
  final String clientId;
  final CafePaymentMethod method;
  final double amount;
  final DateTime recordedAt;

  @override
  List<Object?> get props =>
      [id, orderId, clientId, method, amount, recordedAt];
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
  });

  final CafeMenuItem menuItem;
  double quantity;
  String notes;

  double get lineTotal => menuItem.price * quantity;
}
