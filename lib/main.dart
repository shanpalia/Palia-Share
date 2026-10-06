import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

const mint = Color(0xFF18B78A);
const hubUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = '${hubUrl}update.json';
const currentVersion = '1.0.0';
const discoveryPort = 8766;
const transferPort = 8765;

String? downloadDirectory;
ThemeMode appThemeMode = ThemeMode.light;
String appLanguage = 'English';

void main() => runApp(const PaliaShareApp());

class NearbyDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  DateTime lastSeen;
  NearbyDevice({required this.id, required this.name, required this.ip, required this.port, DateTime? lastSeen}) : lastSeen = lastSeen ?? DateTime.now();
}

class IncomingRequest {
  final String id;
  final String senderName;
  final String senderIp;
  final List<Map<String, dynamic>> files;
  final HttpRequest request;
  IncomingRequest({required this.id, required this.senderName, required this.senderIp, required this.files, required this.request});
}

class NearbyTransferService {
  NearbyTransferService._();
  static final NearbyTransferService instance = NearbyTransferService._();

  RawDatagramSocket? _discovery;
  HttpServer? _server;
  Timer? _announceTimer;
  Timer? _cleanupTimer;
  final Map<String, NearbyDevice> devices = {};
  IncomingRequest? incoming;
  final ValueNotifier<int> changed = ValueNotifier<int>(0);
  final ValueNotifier<IncomingRequest?> incomingNotifier = ValueNotifier<IncomingRequest?>(null);
  bool _started = false;

  String get deviceName {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return 'Palia Share';
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _discovery = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true, reusePort: true);
      _discovery!.broadcastEnabled = true;
      _discovery!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final socket = _discovery;
        if (socket == null) return;
        Datagram? packet;
        while ((packet = socket.receive()) != null) {
          final p = packet!;
          try {
            final data = jsonDecode(utf8.decode(p.data)) as Map<String, dynamic>;
            if (data['type'] != 'palia-share') return;
            final id = '${data['id'] ?? ''}';
            final name = '${data['name'] ?? 'Palia Share'}';
            final port = int.tryParse('${data['port'] ?? transferPort}') ?? transferPort;
            if (id.isEmpty || id == _deviceId()) return;
            devices[id] = NearbyDevice(id: id, name: name, ip: p.address.address, port: port);
            changed.value++;
          } catch (_) {}
        }
      });
      _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) => _announce());
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        devices.removeWhere((_, d) => now.difference(d.lastSeen).inSeconds > 7);
        changed.value++;
      });
      await _startHttpServer();
      _announce();
    } catch (_) {
      _started = false;
      rethrow;
    }
  }

  String _deviceId() {
    try {
      final host = Platform.localHostname.trim();
      if (host.isNotEmpty) return host;
    } catch (_) {}
    return 'palia-share-device';
  }

  void _announce() {
    final socket = _discovery;
    if (socket == null) return;
    final message = utf8.encode(jsonEncode({'type': 'palia-share', 'id': _deviceId(), 'name': deviceName, 'port': transferPort}));
    try { socket.send(message, InternetAddress('255.255.255.255'), discoveryPort); } catch (_) {}
  }

  Future<void> _startHttpServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, transferPort, shared: true);
    _server!.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST' && request.uri.path == '/request') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final files = ((data['files'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final req = IncomingRequest(
          id: '${data['id'] ?? DateTime.now().millisecondsSinceEpoch}',
          senderName: '${data['senderName'] ?? 'Palia Share'}',
          senderIp: request.connectionInfo?.remoteAddress.address ?? '',
          files: files,
          request: request,
        );
        incoming = req;
        incomingNotifier.value = req;
        return;
      }
      if (request.method == 'PUT' && request.uri.path == '/upload') {
        final name = Uri.decodeComponent(request.headers.value('x-file-name') ?? 'received.bin').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final dir = downloadDirectory ?? (await getApplicationDocumentsDirectory()).path;
        await Directory(dir).create(recursive: true);
        final target = File('$dir/$name');
        final sink = target.openWrite();
        await for (final chunk in request) { sink.add(chunk); }
        await sink.close();
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (e) {
      try { request.response.statusCode = HttpStatus.internalServerError; await request.response.close(); } catch (_) {}
    }
  }

  Future<bool> requestSend(NearbyDevice device, List<PlatformFile> files, {ValueChanged<double>? onProgress, ValueChanged<String>? onStatus}) async {
    final payloadFiles = files.map((f) => {'name': f.name, 'size': f.size}).toList();
    onStatus?.call('Waiting for ${device.name} to accept…');
    final requestId = '${DateTime.now().millisecondsSinceEpoch}-${device.id}';
    try {
      final response = await http.post(
        Uri.parse('http://${device.ip}:${device.port}/request'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'id': requestId, 'senderName': deviceName, 'files': payloadFiles}),
      ).timeout(const Duration(minutes: 10));
      if (response.statusCode != HttpStatus.ok) {
        onStatus?.call('Transfer rejected');
        return false;
      }
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        if (f.path == null) continue;
        final file = File(f.path!);
        final upload = http.StreamedRequest('PUT', Uri.parse('http://${device.ip}:${device.port}/upload'));
        upload.headers['x-file-name'] = Uri.encodeComponent(f.name);
        upload.headers['content-type'] = 'application/octet-stream';
        upload.contentLength = await file.length();
        var sent = 0;
        await for (final chunk in file.openRead()) {
          upload.sink.add(Uint8List.fromList(chunk));
          sent += chunk.length;
          final total = await file.length();
          onProgress?.call((i + (total == 0 ? 1 : sent / total)) / files.length);
        }
        await upload.sink.close();
        final result = await upload.send();
        if (result.statusCode != HttpStatus.ok) throw Exception('HTTP ${result.statusCode}');
        onProgress?.call((i + 1) / files.length);
      }
      onStatus?.call('Transfer complete');
      return true;
    } catch (e) {
      onStatus?.call('Transfer failed: $e');
      return false;
    }
  }

  Future<void> acceptIncoming() async {
    final req = incoming;
    if (req == null) return;
    try {
      req.request.response.statusCode = HttpStatus.ok;
      await req.request.response.close();
    } catch (_) {}
    incoming = null;
    incomingNotifier.value = null;
  }

  Future<void> rejectIncoming() async {
    final req = incoming;
    if (req == null) return;
    try {
      req.request.response.statusCode = HttpStatus.forbidden;
      await req.request.response.close();
    } catch (_) {}
    incoming = null;
    incomingNotifier.value = null;
  }

  Future<void> dispose() async {
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    _discovery?.close();
    await _server?.close(force: true);
    _discovery = null;
    _server = null;
    _started = false;
  }
}

class PaliaShareApp extends StatefulWidget {
  const PaliaShareApp({super.key});
  @override State<PaliaShareApp> createState() => _PaliaShareAppState();
}
class _PaliaShareAppState extends State<PaliaShareApp> {
  void setTheme(ThemeMode mode) => setState(() => appThemeMode = mode);
  void setLanguage(String language) => setState(() => appLanguage = language);
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Palia Share',
    themeMode: appThemeMode,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: mint, scaffoldBackgroundColor: Colors.white),
    darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: mint, brightness: Brightness.dark),
    home: SplashPage(onThemeChanged: setTheme, onLanguageChanged: setLanguage),
  );
}

class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 52});
  @override Widget build(BuildContext context) => SizedBox(width: size, height: size, child: SvgPicture.asset('assets/palia_share_logo.svg'));
}

Future<void> openHub(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(hubUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open PaliaAPK HUB')));
}

Future<void> requestAllPermissions() async {
  if (!Platform.isAndroid) return;
  final permissions = <Permission>[Permission.notification, Permission.photos, Permission.videos];
  for (final permission in permissions) { try { await permission.request(); } catch (_) {} }
}

class SplashPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged; final ValueChanged<String> onLanguageChanged;
  const SplashPage({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override void initState() { super.initState(); Future.delayed(const Duration(milliseconds: 1400), () async { await requestAllPermissions(); try { await NearbyTransferService.instance.start(); } catch (_) {} if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeShell(onThemeChanged: widget.onThemeChanged, onLanguageChanged: widget.onLanguageChanged))); }); }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [BrandIcon(size: 110), SizedBox(height: 18), Text('Palia Share', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)), SizedBox(height: 22), Text('Developer by Shanpalia', style: TextStyle(color: Colors.black45)), SizedBox(height: 28), CircularProgressIndicator()])));
}

class HomeShell extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged; final ValueChanged<String> onLanguageChanged;
  const HomeShell({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int selected = 0; final history = <String>[];
  void addHistory(String value) => setState(() => history.insert(0, value));
  @override Widget build(BuildContext context) {
    final pages = [HomePage(onHistory: addHistory), TransfersPage(items: history), DevicesPage(onHistory: addHistory), HistoryPage(items: history), SettingsPage(onThemeChanged: widget.onThemeChanged, onLanguageChanged: widget.onLanguageChanged)];
    return Scaffold(body: SafeArea(child: pages[selected]), bottomNavigationBar: NavigationBar(selectedIndex: selected, onDestinationSelected: (i) => setState(() => selected = i), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfers'), NavigationDestination(icon: Icon(Icons.devices_other), label: 'Devices'), NavigationDestination(icon: Icon(Icons.history), label: 'History'), NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings')]));
  }
}

class HomePage extends StatelessWidget {
  final ValueChanged<String> onHistory; const HomePage({super.key, required this.onHistory});
  Future<void> pick(BuildContext context) async { final result = await FilePicker.platform.pickFiles(allowMultiple: true); if (result == null || !context.mounted) return; Navigator.push(context, MaterialPageRoute(builder: (_) => SendPage(files: result.files, onDone: onHistory))); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
    const Row(children: [BrandIcon(size: 52), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Palia Share', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54))]))]),
    const SizedBox(height: 22), Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEFFFFA), Color(0xFFF8FFFC)]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Share files at lightning speed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Transfer photos, videos, apps and documents directly between nearby Palia Share devices.', style: TextStyle(color: Colors.black54, height: 1.4)), const SizedBox(height: 18), Row(children: [Expanded(child: FilledButton.icon(onPressed: () => pick(context), icon: const Icon(Icons.send_rounded), label: const Text('Send Files'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceivePage(onDone: onHistory))), icon: const Icon(Icons.download_rounded), label: const Text('Receive')))])])),
    const SizedBox(height: 24), const Text('Quick Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), Row(children: [_quick(context, Icons.photo_library_outlined, 'Photos'), _quick(context, Icons.videocam_outlined, 'Videos'), _quick(context, Icons.android, 'Apps'), _quick(context, Icons.folder_outlined, 'Files')]),
    const SizedBox(height: 24), InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesPage())), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: mint.withValues(alpha: .18))), child: const Row(children: [CircleAvatar(backgroundColor: Color(0xFFE8FBF5), child: Icon(Icons.wifi_tethering, color: mint)), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Nearby devices', style: TextStyle(fontWeight: FontWeight.w700)), Text('Tap to see Palia Share devices on this network.', style: TextStyle(color: Colors.black54))])), Icon(Icons.chevron_right, color: mint)]))),
    const SizedBox(height: 14), InkWell(onTap: () => openHub(context), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF3FBF8), borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.rocket_launch_outlined, color: mint, size: 30), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('More Apps & Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 4), Text('Open PaliaAPK HUB', style: TextStyle(color: Colors.black54))])), Icon(Icons.arrow_forward_ios, size: 16, color: mint)]))),
  ]);
  Widget _quick(BuildContext context, IconData icon, String label) => Expanded(child: InkWell(onTap: () => pick(context), borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1FBF8), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 12))]))));
}

class SendPage extends StatefulWidget {
  final List<PlatformFile> files; final ValueChanged<String> onDone;
  const SendPage({super.key, required this.files, required this.onDone});
  @override State<SendPage> createState() => _SendPageState();
}
class _SendPageState extends State<SendPage> {
  final service = NearbyTransferService.instance; double progress = 0; bool busy = false; String status = 'Searching for nearby Palia Share devices…';
  @override void initState() { super.initState(); service.changed.addListener(_refresh); try { service.start(); } catch (_) {} }
  void _refresh() { if (mounted) setState(() {}); }
  @override void dispose() { service.changed.removeListener(_refresh); super.dispose(); }
  Future<void> sendTo(NearbyDevice device) async {
    if (busy) return; setState(() { busy = true; progress = 0; status = 'Requesting ${device.name}…'; });
    final ok = await service.requestSend(device, widget.files, onProgress: (p) { if (mounted) setState(() => progress = p); }, onStatus: (s) { if (mounted) setState(() => status = s); });
    if (ok && mounted) { widget.onDone('${widget.files.length} file(s) sent to ${device.name}'); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) {
    final list = service.devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(appBar: AppBar(title: const Text('Choose Device')), body: ListView(padding: const EdgeInsets.all(20), children: [Text('${widget.files.length} file(s) selected', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(status, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 14), LinearProgressIndicator(value: busy ? progress : null, minHeight: 7), const SizedBox(height: 20), if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.devices_other, size: 50, color: mint), SizedBox(height: 10), Text('No nearby Palia Share device found', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('Open Palia Share on the other phone and keep both devices on the same Wi-Fi network.', textAlign: TextAlign.center)]))) else ...list.map((d) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: busy ? null : () => sendTo(d), leading: const CircleAvatar(backgroundColor: Color(0xFFE8FBF5), child: Icon(Icons.phone_android, color: mint)), title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Nearby • Tap to send'), trailing: const Icon(Icons.arrow_forward_ios, size: 17, color: mint)))), if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: Text('The receiver must tap Accept before the file transfer starts.', textAlign: TextAlign.center))]));
  }
}

class ReceivePage extends StatefulWidget {
  final ValueChanged<String> onDone; const ReceivePage({super.key, required this.onDone});
  @override State<ReceivePage> createState() => _ReceivePageState();
}
class _ReceivePageState extends State<ReceivePage> {
  final service = NearbyTransferService.instance; IncomingRequest? request;
  @override void initState() { super.initState(); request = service.incoming; service.incomingNotifier.addListener(_incomingChanged); try { service.start(); } catch (_) {} }
  void _incomingChanged() { if (mounted) setState(() => request = service.incomingNotifier.value); }
  @override void dispose() { service.incomingNotifier.removeListener(_incomingChanged); super.dispose(); }
  Future<void> accept() async { final r = request; if (r == null) return; await service.acceptIncoming(); if (mounted) { setState(() => request = null); widget.onDone('Receiving ${r.files.length} file(s) from ${r.senderName}'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted. Transfer is starting…'))); } }
  Future<void> reject() async { await service.rejectIncoming(); if (mounted) setState(() => request = null); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Receive Files')), body: ListView(padding: const EdgeInsets.all(20), children: [const BrandIcon(size: 70), const SizedBox(height: 10), const Text('Ready to Receive', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Keep this screen open. Nearby Palia Share devices can send a request to you automatically.', style: TextStyle(color: Colors.black54, height: 1.4)), const SizedBox(height: 24), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFEFFFFA), borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.wifi_tethering, color: mint, size: 32), SizedBox(width: 12), Expanded(child: Text('Visible to nearby Palia Share devices', style: TextStyle(fontWeight: FontWeight.w700)))])), const SizedBox(height: 20), if (request != null) Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Incoming File', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text('${request!.senderName} wants to send ${request!.files.length} file(s).'), const SizedBox(height: 12), ...request!.files.map((f) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.insert_drive_file_outlined, color: mint), title: Text('${f['name'] ?? 'File'}'), subtitle: Text('${f['size'] ?? 0} bytes'))), const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton(onPressed: reject, child: const Text('Reject'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: accept, icon: const Icon(Icons.download_rounded), label: const Text('Accept')))])]))) else const Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.hourglass_empty, size: 44, color: mint), SizedBox(height: 10), Text('Waiting for incoming files…', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('When another Palia Share user taps your device, the request will appear here.', textAlign: TextAlign.center)])))]));
}

class TransfersPage extends StatelessWidget { final List<String> items; const TransfersPage({super.key, required this.items}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('Transfers', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Current and completed transfers.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18), if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No transfers yet.'))) else ...items.map((x) => ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(x)))]); }

class DevicesPage extends StatefulWidget { final ValueChanged<String>? onHistory; const DevicesPage({super.key, this.onHistory}); @override State<DevicesPage> createState() => _DevicesPageState(); }
class _DevicesPageState extends State<DevicesPage> {
  final service = NearbyTransferService.instance;
  @override void initState() { super.initState(); service.changed.addListener(_refresh); try { service.start(); } catch (_) {} }
  void _refresh() { if (mounted) setState(() {}); }
  @override void dispose() { service.changed.removeListener(_refresh); super.dispose(); }
  @override Widget build(BuildContext context) { final list = service.devices.values.toList()..sort((a,b) => a.name.compareTo(b.name)); return ListView(padding: const EdgeInsets.all(20), children: [const Text('Devices', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Nearby Palia Share devices', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18), if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.search, size: 45, color: mint), SizedBox(height: 8), Text('Searching…', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('Open Palia Share on another device and connect both devices to the same Wi-Fi.', textAlign: TextAlign.center)]))) else ...list.map((d) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE8FBF5), child: Icon(Icons.devices, color: mint)), title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Nearby • Ready to receive'), trailing: const Icon(Icons.check_circle, color: mint)))), const SizedBox(height: 12), Card(child: ListTile(onTap: () => openAppSettings(), leading: const Icon(Icons.settings_outlined), title: const Text('Connection settings'), subtitle: const Text('Open Android settings.')))]); }
}

class HistoryPage extends StatelessWidget { final List<String> items; const HistoryPage({super.key, required this.items}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('History', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (items.isEmpty) const Text('No transfer history yet.', style: TextStyle(color: Colors.black54)) else ...items.map((x) => Card(child: ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(x))))]); }

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged; final ValueChanged<String> onLanguageChanged;
  const SettingsPage({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  String updateStatus = 'Check the latest Palia Share version.'; bool checking = false;
  Future<void> updates() async { setState(() { checking = true; updateStatus = 'Checking…'; }); try { final r = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 10)); if (r.statusCode != 200) throw Exception(); final d = jsonDecode(r.body) as Map<String, dynamic>; final latest = '${d['version'] ?? currentVersion}'; if (newer(latest, currentVersion)) { if (!mounted) return; setState(() => updateStatus = 'New version $latest available'); await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Update Available'), content: Text('Palia Share $latest is available.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')), FilledButton(onPressed: () { Navigator.pop(c); openHub(context); }, child: const Text('Update Now'))])); } else if (mounted) setState(() => updateStatus = 'You are up to date • v$currentVersion'); } catch (_) { if (mounted) setState(() => updateStatus = 'Check failed • tap again'); } finally { if (mounted) setState(() => checking = false); } }
  bool newer(String a, String b) { final x = a.split('.').map(int.parse).toList(), y = b.split('.').map(int.parse).toList(); for (var i = 0; i < 3; i++) { final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0; if (p != q) return p > q; } return false; }
  void detail(String title, String subtitle, IconData icon, List<Widget> children) => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(title: title, subtitle: subtitle, icon: icon, children: children)));
  Future<void> chooseDirectory() async { final path = await FilePicker.platform.getDirectoryPath(); if (path != null) { downloadDirectory = path; if (mounted) setState(() {}); } }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [const Row(children: [BrandIcon(size: 50), SizedBox(width: 12), Expanded(child: Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)))]), const SizedBox(height: 16), const Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)), const Text('Customize your experience', style: TextStyle(color: Colors.black54, fontSize: 16)), const SizedBox(height: 18), tile('My Device', 'Device name, visibility and info', Icons.phone_android_outlined, () => detail('My Device', 'Device information', Icons.phone_android_outlined, const [ListTile(title: Text('Device name'), subtitle: Text('Palia Share')), ListTile(title: Text('Visibility'), subtitle: Text('Visible while Palia Share is open')), ListTile(title: Text('Connection'), subtitle: Text('Local Wi-Fi'))])), tile('Notifications', 'Manage Palia Share notifications', Icons.notifications_none, () => detail('Notifications', 'Android notifications', Icons.notifications_none, [const Text('Notification permission is requested after the splash screen.'), const SizedBox(height: 14), FilledButton.icon(onPressed: () async { await Permission.notification.request(); }, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Allow Notifications')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: openAppSettings, icon: const Icon(Icons.settings), label: const Text('Open Android Settings'))])), tile('Download Location', downloadDirectory == null ? 'Choose where received files are saved' : downloadDirectory!, Icons.folder_outlined, () => detail('Download Location', 'Received files', Icons.folder_outlined, [Text(downloadDirectory == null ? 'Default: Palia Share app storage' : downloadDirectory!), const SizedBox(height: 14), FilledButton.icon(onPressed: chooseDirectory, icon: const Icon(Icons.folder_open), label: const Text('Choose Folder'))])), tile('Transfer Settings', 'Speed and connection options', Icons.bolt_outlined, () => detail('Transfer Settings', 'Nearby local transfer', Icons.bolt_outlined, [const ListTile(title: Text('Discovery'), subtitle: Text('Automatic nearby device discovery')), const ListTile(title: Text('Connection'), subtitle: Text('Direct local Wi-Fi transfer')), const ListTile(title: Text('Security'), subtitle: Text('Receiver must accept each transfer'))])), tile('Privacy & Security', 'Permissions and data control', Icons.shield_outlined, () => detail('Privacy & Security', 'Local file transfer', Icons.shield_outlined, const [Text('Files are transferred directly between nearby devices. Palia Share does not upload transfer files to PaliaAPK HUB.'), SizedBox(height: 12), Text('Only permissions required by the Android features are requested.')])), tile('Theme', 'Light, Dark or System', Icons.palette_outlined, () => detail('Theme', 'Appearance', Icons.palette_outlined, [RadioListTile(value: ThemeMode.light, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('Light')), RadioListTile(value: ThemeMode.system, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('System')), RadioListTile(value: ThemeMode.dark, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('Dark'))])), tile('Language', 'Choose your language', Icons.language_outlined, () => detail('Language', 'App language', Icons.language_outlined, [RadioListTile(value: 'English', groupValue: appLanguage, onChanged: (v) { if (v != null) { widget.onLanguageChanged(v); Navigator.pop(context); } }, title: const Text('English')), RadioListTile(value: 'Hindi', groupValue: appLanguage, onChanged: (v) { if (v != null) { widget.onLanguageChanged(v); Navigator.pop(context); } }, title: const Text('Hindi'))])), const SizedBox(height: 12), InkWell(onTap: checking ? null : updates, borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFEFFFFA), borderRadius: BorderRadius.circular(24)), child: Row(children: [const BrandIcon(size: 54), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), Text('v$currentVersion • $updateStatus', style: const TextStyle(color: Colors.black54))])), FilledButton(onPressed: checking ? null : updates, child: Text(checking ? 'Checking' : 'Check'))]))), const SizedBox(height: 12), InkWell(onTap: () => openHub(context), borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(24)), child: const Row(children: [Icon(Icons.rocket_launch_outlined, color: Color(0xFF1677C8), size: 32), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PaliaAPK HUB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), SizedBox(height: 4), Text('Tap to open PaliaAPK HUB', style: TextStyle(color: Colors.black54))])), Icon(Icons.open_in_new, color: Color(0xFF1677C8))]))), const SizedBox(height: 18), ListTile(onTap: () => detail('About Palia Share', 'App information', Icons.info_outline, const [BrandIcon(size: 72), Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('Fast. Simple. Secure.'), SizedBox(height: 8), Text('Developer by Shanpalia'), SizedBox(height: 8), Text('Version 1.0.0')]), leading: const Icon(Icons.info_outline, color: mint), title: const Text('About Palia Share'), subtitle: const Text('Fast. Simple. Secure. • Developer by Shanpalia'), trailing: const Icon(Icons.chevron_right))]);
  Widget tile(String title, String subtitle, IconData icon, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.black12)), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.black54))])), const Icon(Icons.chevron_right, color: Colors.black54)]))));
}

class DetailPage extends StatelessWidget {
  final String title, subtitle; final IconData icon; final List<Widget> children;
  const DetailPage({super.key, required this.title, required this.subtitle, required this.icon, required this.children});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(20), children: [Row(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: mint, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: Colors.black54))]))]), const SizedBox(height: 22), ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: c))))]));
}
