class Formatters {
  Formatters._();

  static String mbps(double value) {
    if (value.isNaN || value.isInfinite) return '-';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)} Gbps';
    return '${value.toStringAsFixed(2)} Mbps';
  }

  static String ms(double value) {
    if (value.isNaN || value.isInfinite) return '-';
    if (value < 1) return '${(value * 1000).toStringAsFixed(0)} µs';
    return '${value.toStringAsFixed(2)} ms';
  }

  static String percent(double value, {int digits = 1}) {
    if (value.isNaN || value.isInfinite) return '-';
    return '${value.toStringAsFixed(digits)}%';
  }

  static String bytes(int value) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double size = value.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return unit == 0
        ? '$value B'
        : '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
  }

  static String duration(Duration d) {
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  static String dateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
