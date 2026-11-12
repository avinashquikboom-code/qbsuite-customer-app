import 'package:intl/intl.dart';

/// Presentation only. Inputs are INR major units; no exchange-rate conversion.
abstract final class AppCurrency {
  static const code = 'INR';
  static const symbol = '₹';
  static const locale = 'en_IN';
  static const label = '$code ($symbol)';
  static final _formatter = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: 2,
  );
  static final _number = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;

  static String format(num? amount) =>
      amount == null || !amount.isFinite ? '—' : _formatter.format(amount);

  /// For legacy composite layouts which already supply their own currency label.
  static String number(num? amount) =>
      amount == null || !amount.isFinite ? '—' : _number.format(amount);
}
