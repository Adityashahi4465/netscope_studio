enum ProtocolType {
  tcp('TCP'),
  udp('UDP'),
  both('TCP + UDP');

  const ProtocolType(this.label);

  final String label;

  bool get includesTcp => this == tcp || this == both;
  bool get includesUdp => this == udp || this == both;

  static ProtocolType fromName(String? name) => ProtocolType.values.firstWhere(
    (ProtocolType e) => e.name == name,
    orElse: () => ProtocolType.both,
  );
}
