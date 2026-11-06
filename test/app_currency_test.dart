import 'package:flutter_test/flutter_test.dart';
import 'package:qb_customer/core/utils/app_currency.dart';

void main() {
  test('INR format uses Indian grouping and two decimal places', () {
    final cases = <num, String>{
      0: '₹0.00',
      1000: '₹1,000.00',
      10000: '₹10,000.00',
      100000: '₹1,00,000.00',
      1000000: '₹10,00,000.00',
      10000000: '₹1,00,00,000.00',
      1234.56: '₹1,234.56',
      -123456.78: '-₹1,23,456.78',
    };
    for (final entry in cases.entries) {
      expect(AppCurrency.format(entry.key), entry.value);
    }
    expect(AppCurrency.code, 'INR');
    expect(AppCurrency.locale, 'en_IN');
    expect(AppCurrency.label, 'INR (₹)');
    expect(AppCurrency.number(100000), '1,00,000.00');
  });
  test('unavailable amounts remain unavailable rather than becoming zero', () {
    expect(AppCurrency.format(null), '—');
    expect(AppCurrency.format(double.nan), '—');
    expect(AppCurrency.format(double.infinity), '—');
  });
  test('formatting preserves the original rupee amount', () {
    const amount = 100000.25;
    expect(AppCurrency.format(amount), '₹1,00,000.25');
    expect(amount, 100000.25);
  });
}
