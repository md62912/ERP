import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm a');
  static final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  static String date(DateTime? d) => d == null ? '-' : _dateFmt.format(d);
  static String time(DateTime? d) => d == null ? '-' : _timeFmt.format(d);
  static String currency(num? value) => _currencyFmt.format(value ?? 0);

  static String employeeCode(String prefix, int seq) =>
      '$prefix-${seq.toString().padLeft(4, '0')}';
}
