import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/pos/domain/entities/cafe_entities.dart';

CafeMenuItem _item({
  String id = 'item-1',
  String name = 'Flat White',
  double price = 170,
  List<CafeMenuAddon> addons = const [],
}) {
  return CafeMenuItem(
    id: id,
    cafeId: 'cafe-1',
    categoryId: 'cat-1',
    name: name,
    price: price,
    addons: addons,
  );
}

CafeMenuAddon _addon({
  required String id,
  required String name,
  double price = 20,
}) {
  return CafeMenuAddon(
    id: id,
    cafeId: 'cafe-1',
    menuItemId: 'item-1',
    name: name,
    price: price,
  );
}

void main() {
  group('CafeCartLine.matches', () {
    test('same item and empty add-ons match', () {
      final item = _item();
      final line = CafeCartLine(menuItem: item);
      expect(line.matches(item, const []), isTrue);
    });

    test('different add-on sets do not match', () {
      final shot = _addon(id: 'a1', name: 'Extra shot');
      final syrup = _addon(id: 'a2', name: 'Vanilla');
      final item = _item(addons: [shot, syrup]);
      final line = CafeCartLine(menuItem: item, addons: [shot]);
      expect(line.matches(item, [syrup]), isFalse);
      expect(line.matches(item, [shot]), isTrue);
      expect(line.matches(item, [shot, syrup]), isFalse);
    });

    test('add-on order does not matter', () {
      final shot = _addon(id: 'a1', name: 'Extra shot');
      final syrup = _addon(id: 'a2', name: 'Vanilla');
      final item = _item(addons: [shot, syrup]);
      final line = CafeCartLine(menuItem: item, addons: [shot, syrup]);
      expect(line.matches(item, [syrup, shot]), isTrue);
    });

    test('different notes do not match', () {
      final item = _item();
      final line = CafeCartLine(menuItem: item, notes: 'No foam');
      expect(line.matches(item, const [], notes: 'No foam'), isTrue);
      expect(line.matches(item, const [], notes: 'Extra hot'), isFalse);
      expect(line.matches(item, const []), isFalse);
    });
  });

  group('cafeCartAddOrIncrement', () {
    test('merges identical configurations', () {
      final item = _item();
      final cart = <CafeCartLine>[];
      cafeCartAddOrIncrement(cart, item);
      cafeCartAddOrIncrement(cart, item);
      expect(cart, hasLength(1));
      expect(cart.first.quantity, 2);
    });

    test('keeps different add-ons as separate line items', () {
      final shot = _addon(id: 'a1', name: 'Extra shot', price: 30);
      final syrup = _addon(id: 'a2', name: 'Vanilla', price: 25);
      final item = _item(addons: [shot, syrup]);
      final cart = <CafeCartLine>[];

      cafeCartAddOrIncrement(cart, item, addons: [shot]);
      cafeCartAddOrIncrement(cart, item, addons: [syrup]);
      cafeCartAddOrIncrement(cart, item, addons: [shot]);

      expect(cart, hasLength(2));
      expect(cart[0].displayName, 'Flat White (+Extra shot)');
      expect(cart[0].quantity, 2);
      expect(cart[0].unitPrice, 200);
      expect(cart[1].displayName, 'Flat White (+Vanilla)');
      expect(cart[1].quantity, 1);
      expect(cart[1].unitPrice, 195);
    });

    test('plain and add-on variants stay separate', () {
      final shot = _addon(id: 'a1', name: 'Extra shot');
      final item = _item(addons: [shot]);
      final cart = <CafeCartLine>[];

      cafeCartAddOrIncrement(cart, item);
      cafeCartAddOrIncrement(cart, item, addons: [shot]);

      expect(cart, hasLength(2));
      expect(cart[0].addons, isEmpty);
      expect(cart[1].addons, hasLength(1));
    });
  });
}
