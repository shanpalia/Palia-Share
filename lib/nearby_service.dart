import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NearbyDevice {
  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;

  const NearbyDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
  });
}

/// Local-network discovery for Palia Share.
///
/// Devices advertise themselves over UDP broadcast. No IP address is entered
/// by the user. The HTTP transfer server can continue to use the discovered
/// address/port when a device is selected.
class PaliaNearbyService {
  static const int discoveryPort = 8766;
  static const String protocol = 'PALIA_SHARE_DISCOVERY_V1';

  RawDatagramSocket? _socket;
  Timer? _advertiseTimer;
  Timer? _cleanupTimer;
  final Map<String, NearbyDevice> _devices = {};
  final StreamController<List<NearbyDevice>> _controller =
      StreamController<List<NearbyDevice>>.broadcast();

  Stream<List<NearbyDevice>> get devices => _controller.stream;

  Future<void> start({
    required String deviceId,
    required String deviceName,
    required int transferPort,
  }) async {
    await stop();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: false,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = _socket!.receive()) != null) {
        final d = datagram!;
        _handleAdvertisement(d, ownId: deviceId);
      }
    });

    Future<void> advertise() async {
      final payload = jsonEncode({
        'protocol': protocol,
        'id': deviceId,
        'name': deviceName,
        'port': transferPort,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      final bytes = utf8.encode(payload);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      )) {
        for (final address in interface.addresses) {
          final broadcast = _broadcastAddress(address.address, interface);
          if (broadcast != null) {
            _socket?.send(bytes, broadcast, discoveryPort);
          }
        }
      }
    }

    await advertise();
    _advertiseTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      advertise();
    });
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 7));
      _devices.removeWhere((_, d) => d.lastSeen.isBefore(cutoff));
      _emit();
    });
  }

  void _handleAdvertisement(Datagram datagram, {required String ownId}) {
    try {
      final value = jsonDecode(utf8.decode(datagram.data));
      if (value is! Map || value['protocol'] != protocol) return;
      final id = '${value['id'] ?? ''}';
      if (id.isEmpty || id == ownId) return;
      final port = int.tryParse('${value['port'] ?? ''}');
      if (port == null) return;
      _devices[id] = NearbyDevice(
        id: id,
        name: '${value['name'] ?? 'Palia Share'}',
        address: datagram.address,
        port: port,
        lastSeen: DateTime.now(),
      );
      _emit();
    } catch (_) {
      // Ignore unrelated UDP broadcast traffic on the LAN.
    }
  }

  InternetAddress? _broadcastAddress(
    String address,
    NetworkInterface interface,
  ) {
    // The common Android/Windows home-network case is covered by the global
    // broadcast above. Interface-specific calculation is intentionally omitted
    // when the platform does not expose a reliable netmask through dart:io.
    return null;
  }

  void _emit() {
    final list = _devices.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!_controller.isClosed) _controller.add(list);
  }

  Future<void> stop() async {
    _advertiseTimer?.cancel();
    _cleanupTimer?.cancel();
    _advertiseTimer = null;
    _cleanupTimer = null;
    _devices.clear();
    _emit();
    _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
