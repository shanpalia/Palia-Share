import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const mint = Color(0xFF18B78A);
const hubUrl = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = '${hubUrl}update.json';
const currentVersion = '1.0.0';

String? downloadDirectory;
ThemeMode appThemeMode = ThemeMode.light;
String appLanguage = 'English';

void main() => runApp(const PaliaShareApp());

class PaliaShareApp extends StatefulWidget {
  const PaliaShareApp({super.key});
  @override
  State<PaliaShareApp> createState() => _PaliaShareAppState();
}

class _PaliaShareAppState extends State<PaliaShareApp> {
  void setTheme(ThemeMode mode) => setState(() => appThemeMode = mode);
  void setLanguage(String language) => setState(() => appLanguage = language);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palia Share',
      themeMode: appThemeMode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: mint, scaffoldBackgroundColor: Colors.white),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: mint, brightness: Brightness.dark),
      home: SplashPage(onThemeChanged: setTheme, onLanguageChanged: setLanguage),
    );
  }
}

class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: SvgPicture.asset('assets/palia_share_logo.svg'));
}

Future<void> openHub(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(hubUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open PaliaAPK HUB')));
}

Future<void> requestAllPermissions() async {
  if (!Platform.isAndroid) return;
  final permissions = <Permission>[Permission.notification, Permission.photos, Permission.videos];
  if (await Permission.storage.isGranted || await Permission.storage.isPermanentlyDenied) {
    // Nothing else is required on modern Android.
  } else if (Platform.version.contains('Android') == false) {
    permissions.add(Permission.storage);
  }
  for (final permission in permissions) {
    try { await permission.request(); } catch (_) {}
  }
}

class SplashPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  const SplashPage({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () async {
      await requestAllPermissions();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeShell(onThemeChanged: widget.onThemeChanged, onLanguageChanged: widget.onLanguageChanged)));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
      BrandIcon(size: 110), SizedBox(height: 18),
      Text('Palia Share', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
      SizedBox(height: 6), Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
      SizedBox(height: 22), Text('Developer by Shanpalia', style: TextStyle(color: Colors.black45)),
      SizedBox(height: 28), CircularProgressIndicator(),
    ])),
  );
}

class HomeShell extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  const HomeShell({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  final history = <String>[];
  void addHistory(String value) => setState(() => history.insert(0, value));

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onHistory: addHistory),
      TransfersPage(items: history),
      const DevicesPage(),
      HistoryPage(items: history),
      SettingsPage(onThemeChanged: widget.onThemeChanged, onLanguageChanged: widget.onLanguageChanged),
    ];
    return Scaffold(
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfers'),
          NavigationDestination(icon: Icon(Icons.devices_other), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final ValueChanged<String> onHistory;
  const HomePage({super.key, required this.onHistory});

  Future<void> pick(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SendPage(files: result.files, onDone: onHistory)));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
    const Row(children: [BrandIcon(size: 52), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Palia Share', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54))]))]),
    const SizedBox(height: 22),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEFFFFA), Color(0xFFF8FFFC)]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Share files at lightning speed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), const Text('Transfer photos, videos, apps and documents directly between nearby Android phones.', style: TextStyle(color: Colors.black54, height: 1.4)),
      const SizedBox(height: 18), Row(children: [Expanded(child: FilledButton.icon(onPressed: () => pick(context), icon: const Icon(Icons.send_rounded), label: const Text('Send Files'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceivePage(onDone: onHistory))), icon: const Icon(Icons.download_rounded), label: const Text('Receive')))]),
    ])),
    const SizedBox(height: 24), const Text('Quick Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
    Row(children: [_quick(context, Icons.photo_library_outlined, 'Photos'), _quick(context, Icons.videocam_outlined, 'Videos'), _quick(context, Icons.android, 'Apps'), _quick(context, Icons.folder_outlined, 'Files')]),
    const SizedBox(height: 24),
    _card(Icons.wifi_tethering, 'Ready to connect', 'Choose Send or Receive to start.'),
    const SizedBox(height: 14),
    InkWell(onTap: () => openHub(context), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF3FBF8), borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.rocket_launch_outlined, color: mint, size: 30), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('More Apps & Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 4), Text('Open PaliaAPK HUB', style: TextStyle(color: Colors.black54))])), Icon(Icons.arrow_forward_ios, size: 16, color: mint)]))),
  ]);

  Widget _quick(BuildContext context, IconData icon, String label) => Expanded(child: InkWell(onTap: () => pick(context), borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1FBF8), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 12))]))));
  Widget _card(IconData icon, String title, String subtitle) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: mint.withValues(alpha: .18))), child: Row(children: [CircleAvatar(backgroundColor: const Color(0xFFE8FBF5), child: Icon(icon, color: mint)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.black54))]))]));
}

class SendPage extends StatefulWidget {
  final List<PlatformFile> files; final ValueChanged<String> onDone;
  const SendPage({super.key, required this.files, required this.onDone});
  @override State<SendPage> createState() => _SendPageState();
}
class _SendPageState extends State<SendPage> {
  final ip = TextEditingController(); double progress = 0; bool busy = false; String status = 'Enter the receiver IP shown on their Receive screen.';
  Future<void> send() async {
    if (ip.text.trim().isEmpty) { setState(() => status = 'Enter a receiver IP address.'); return; }
    setState(() => busy = true);
    try {
      for (var i = 0; i < widget.files.length; i++) {
        final f = widget.files[i]; if (f.path == null) continue;
        final file = File(f.path!); final request = http.StreamedRequest('PUT', Uri.parse('http://${ip.text.trim()}:8765/upload'));
        request.headers['x-file-name'] = Uri.encodeComponent(f.name); request.headers['content-type'] = 'application/octet-stream'; request.contentLength = await file.length();
        await for (final chunk in file.openRead()) { request.sink.add(Uint8List.fromList(chunk)); }
        await request.sink.close(); final response = await request.send(); if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
        if (mounted) setState(() => progress = (i + 1) / widget.files.length);
      }
      if (mounted) setState(() => status = 'Transfer complete'); widget.onDone('${widget.files.length} file(s) sent');
    } catch (e) { if (mounted) setState(() => status = 'Transfer failed: $e'); } finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { ip.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Send Files')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${widget.files.length} file(s) selected', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 18), TextField(controller: ip, decoration: const InputDecoration(labelText: 'Receiver IP address', hintText: '192.168.1.10', border: OutlineInputBorder())), const SizedBox(height: 14), Text(status), const SizedBox(height: 18), LinearProgressIndicator(value: busy ? progress : null, minHeight: 8), const Spacer(), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : send, icon: const Icon(Icons.send), label: const Padding(padding: EdgeInsets.all(14), child: Text('Start Transfer'))))])));
}

class ReceivePage extends StatefulWidget {
  final ValueChanged<String> onDone; const ReceivePage({super.key, required this.onDone});
  @override State<ReceivePage> createState() => _ReceivePageState();
}
class _ReceivePageState extends State<ReceivePage> {
  HttpServer? server; String ip = 'Finding...'; String status = 'Starting receiver…';
  @override void initState() { super.initState(); start(); }
  Future<void> start() async {
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 8765);
      final nets = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final n in nets) for (final a in n.addresses) { if (!a.address.startsWith('127.')) ip = a.address; }
      if (mounted) setState(() => status = 'Ready — enter this IP on the sender.');
      await for (final request in server!) {
        if (request.method == 'PUT' && request.uri.path == '/upload') {
          final name = Uri.decodeComponent(request.headers.value('x-file-name') ?? 'received.bin').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final dir = downloadDirectory ?? (await getApplicationDocumentsDirectory()).path; await Directory(dir).create(recursive: true);
          final sink = File('$dir/$name').openWrite(); await for (final chunk in request) sink.add(chunk); await sink.close();
          request.response.statusCode = HttpStatus.ok; await request.response.close(); widget.onDone(name);
        } else { request.response.statusCode = HttpStatus.notFound; await request.response.close(); }
      }
    } catch (e) { if (mounted) setState(() => status = 'Receiver error: $e'); }
  }
  @override void dispose() { server?.close(force: true); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Receive Files')), body: ListView(padding: const EdgeInsets.all(24), children: [const BrandIcon(size: 65), const SizedBox(height: 10), const Text('Receive Files', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(status), const SizedBox(height: 18), if (ip != 'Finding...') Center(child: QrImageView(data: 'palia-share://$ip:8765', size: 210)), const SizedBox(height: 10), Center(child: Text(ip, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))), const SizedBox(height: 8), const Text('Both phones should be on the same local Wi-Fi network.', textAlign: TextAlign.center), const SizedBox(height: 22), const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Keep this screen open while receiving.')))]));
}

class TransfersPage extends StatelessWidget { final List<String> items; const TransfersPage({super.key, required this.items}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('Transfers', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Current and completed transfers.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18), if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No transfers yet.'))) else ...items.map((x) => ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(x)))]); }

class DevicesPage extends StatelessWidget { const DevicesPage({super.key}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('Devices', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Nearby device connection', style: TextStyle(color: Colors.black54)), const SizedBox(height: 18), const Card(child: ListTile(leading: Icon(Icons.wifi, color: mint), title: Text('Local Wi-Fi'), subtitle: Text('Connect both phones to the same Wi-Fi.'))), Card(child: ListTile(onTap: () => openAppSettings(), leading: const Icon(Icons.settings_outlined), title: const Text('Android connection settings'), subtitle: const Text('Open Android settings.')))]); }

class HistoryPage extends StatelessWidget { final List<String> items; const HistoryPage({super.key, required this.items}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('History', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (items.isEmpty) const Text('No transfer history yet.', style: TextStyle(color: Colors.black54)) else ...items.map((x) => Card(child: ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(x))))]); }

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged; final ValueChanged<String> onLanguageChanged;
  const SettingsPage({super.key, required this.onThemeChanged, required this.onLanguageChanged});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  String updateStatus = 'Check the latest Palia Share version.'; bool checking = false;
  Future<void> updates() async {
    setState(() { checking = true; updateStatus = 'Checking…'; });
    try {
      final r = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 10)); if (r.statusCode != 200) throw Exception();
      final d = jsonDecode(r.body) as Map<String, dynamic>; final latest = '${d['version'] ?? currentVersion}';
      if (newer(latest, currentVersion)) {
        if (!mounted) return; setState(() => updateStatus = 'New version $latest available');
        await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Update Available'), content: Text('Palia Share $latest is available.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')), FilledButton(onPressed: () { Navigator.pop(c); openHub(context); }, child: const Text('Update Now'))]));
      } else if (mounted) setState(() => updateStatus = 'You are up to date • v$currentVersion');
    } catch (_) { if (mounted) setState(() => updateStatus = 'Check failed • tap again'); } finally { if (mounted) setState(() => checking = false); }
  }
  bool newer(String a, String b) { final x = a.split('.').map(int.parse).toList(), y = b.split('.').map(int.parse).toList(); for (var i = 0; i < 3; i++) { final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0; if (p != q) return p > q; } return false; }

  void detail(String title, String subtitle, IconData icon, List<Widget> children) => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(title: title, subtitle: subtitle, icon: icon, children: children)));

  Future<void> chooseDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) { downloadDirectory = path; if (mounted) setState(() {}); }
  }

  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
    const Row(children: [BrandIcon(size: 50), SizedBox(width: 12), Expanded(child: Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)))]),
    const SizedBox(height: 16), const Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)), const Text('Customize your experience', style: TextStyle(color: Colors.black54, fontSize: 16)), const SizedBox(height: 18),
    tile('My Device', 'Device name, visibility and info', Icons.phone_android_outlined, () => detail('My Device', 'Device information', Icons.phone_android_outlined, const [ListTile(title: Text('Device name'), subtitle: Text('Palia Share')), ListTile(title: Text('Visibility'), subtitle: Text('Visible while Receive is open')), ListTile(title: Text('Connection'), subtitle: Text('Local Wi-Fi'))])),
    tile('Notifications', 'Manage Palia Share notifications', Icons.notifications_none, () => detail('Notifications', 'Android notifications', Icons.notifications_none, [const Text('Notification permission is requested after the splash screen.'), const SizedBox(height: 14), FilledButton.icon(onPressed: () async { await Permission.notification.request(); }, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Allow Notifications')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: openAppSettings, icon: const Icon(Icons.settings), label: const Text('Open Android Settings'))])),
    tile('Download Location', downloadDirectory == null ? 'Choose where received files are saved' : downloadDirectory!, Icons.folder_outlined, () => detail('Download Location', 'Received files', Icons.folder_outlined, [Text(downloadDirectory == null ? 'Default: Palia Share app storage' : downloadDirectory!), const SizedBox(height: 14), FilledButton.icon(onPressed: chooseDirectory, icon: const Icon(Icons.folder_open), label: const Text('Choose Folder'))])),
    tile('Transfer Settings', 'Speed and connection options', Icons.bolt_outlined, () => detail('Transfer Settings', 'Local transfer', Icons.bolt_outlined, [SwitchListTile(value: true, onChanged: (_) {}, title: const Text('Streaming transfer')), SwitchListTile(value: true, onChanged: (_) {}, title: const Text('Keep screen awake')), const ListTile(title: Text('Port'), subtitle: Text('8765'))])),
    tile('Privacy & Security', 'Permissions and data control', Icons.shield_outlined, () => detail('Privacy & Security', 'Local file transfer', Icons.shield_outlined, const [Text('Files are transferred directly between nearby devices. Palia Share does not upload transfer files to PaliaAPK HUB.'), SizedBox(height: 12), Text('Only permissions required by the Android features are requested.')])),
    tile('Theme', 'Light, Dark or System', Icons.palette_outlined, () => detail('Theme', 'Appearance', Icons.palette_outlined, [RadioListTile(value: ThemeMode.light, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('Light')), RadioListTile(value: ThemeMode.system, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('System')), RadioListTile(value: ThemeMode.dark, groupValue: appThemeMode, onChanged: (v) { if (v != null) { widget.onThemeChanged(v); Navigator.pop(context); } }, title: const Text('Dark'))])),
    tile('Language', 'Choose your language', Icons.language_outlined, () => detail('Language', 'App language', Icons.language_outlined, [RadioListTile(value: 'English', groupValue: appLanguage, onChanged: (v) { if (v != null) { widget.onLanguageChanged(v); Navigator.pop(context); } }, title: const Text('English')), RadioListTile(value: 'Hindi', groupValue: appLanguage, onChanged: (v) { if (v != null) { widget.onLanguageChanged(v); Navigator.pop(context); } }, title: const Text('Hindi'))])),
    const SizedBox(height: 12),
    InkWell(onTap: checking ? null : updates, borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFEFFFFA), borderRadius: BorderRadius.circular(24)), child: Row(children: [const BrandIcon(size: 54), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), Text('v$currentVersion • $updateStatus', style: const TextStyle(color: Colors.black54))])), FilledButton(onPressed: checking ? null : updates, child: Text(checking ? 'Checking' : 'Check'))]))),
    const SizedBox(height: 12),
    InkWell(onTap: () => openHub(context), borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(24)), child: const Row(children: [Icon(Icons.rocket_launch_outlined, color: Color(0xFF1677C8), size: 32), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PaliaAPK HUB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), SizedBox(height: 4), Text('Tap to open PaliaAPK HUB', style: TextStyle(color: Colors.black54))])), Icon(Icons.open_in_new, color: Color(0xFF1677C8))]))),
    const SizedBox(height: 18),
    ListTile(onTap: () => detail('About Palia Share', 'App information', Icons.info_outline, const [BrandIcon(size: 72), Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('Fast. Simple. Secure.'), SizedBox(height: 8), Text('Developer by Shanpalia'), SizedBox(height: 8), Text('Version 1.0.0')]), leading: const Icon(Icons.info_outline, color: mint), title: const Text('About Palia Share'), subtitle: const Text('Fast. Simple. Secure. • Developer by Shanpalia'), trailing: const Icon(Icons.chevron_right)),
  ]);

  Widget tile(String title, String subtitle, IconData icon, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.black12)), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.black54))])), const Icon(Icons.chevron_right, color: Colors.black54)]))));
}

class DetailPage extends StatelessWidget {
  final String title, subtitle; final IconData icon; final List<Widget> children;
  const DetailPage({super.key, required this.title, required this.subtitle, required this.icon, required this.children});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(20), children: [Row(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: mint, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: Colors.black54))]))]), const SizedBox(height: 22), ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: c))))]));
}
