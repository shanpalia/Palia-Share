import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const mint = Color(0xFF18B78A);
const hub = 'https://shanpalia.github.io/WebsitePaliaAPK_V.2/';
const updateUrl = '${hub}update.json';
const currentVersion = '1.0.0';

void main() => runApp(const PaliaShare());

class PaliaShare extends StatelessWidget {
  const PaliaShare({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palia Share',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: mint,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      ),
      home: const Home(),
    );
  }
}

class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/palia_share_logo.svg'),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final history = <String>[];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onHistory: _addHistory),
      const Transfers(),
      const Devices(),
      History(items: history),
      const Settings(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfers'),
          const NavigationDestination(icon: Icon(Icons.devices_other), label: 'Devices'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const BrandIcon(size: 25), label: 'Settings'),
        ],
      ),
    );
  }

  void _addHistory(String value) => setState(() => history.insert(0, value));
}

class HomePage extends StatelessWidget {
  final ValueChanged<String> onHistory;
  const HomePage({super.key, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Row(children: [
          const BrandIcon(size: 52),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Palia Share', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
          ])),
        ]),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEFFFFA), Color(0xFFF8FFFC)]),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share files at lightning speed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Transfer photos, videos, apps and documents directly between nearby Android phones.', style: TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => pick(context, onHistory), icon: const Icon(Icons.send_rounded), label: const Text('Send Files'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => receive(context, onHistory), icon: const Icon(Icons.download_rounded), label: const Text('Receive'))),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Quick Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [quick(context, Icons.photo_library_outlined, 'Photos'), quick(context, Icons.videocam_outlined, 'Videos'), quick(context, Icons.android, 'Apps'), quick(context, Icons.folder_outlined, 'Files')]),
        const SizedBox(height: 24),
        _card(
          icon: Icons.wifi_tethering,
          title: 'Ready to connect',
          subtitle: 'Choose Send or Receive to start.',
        ),
        const SizedBox(height: 14),
        _clickCard(context, Icons.rocket_launch_outlined, 'More Apps & Updates', 'Discover apps, games and updates on PaliaAPK HUB.', openHub),
      ],
    );
  }

  Widget quick(BuildContext context, IconData icon, String label) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => pick(context, onHistory),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1FBF8), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _card({required IconData icon, required String title, required String subtitle}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: mint.withValues(alpha: .18))),
        child: Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFFE8FBF5), child: Icon(icon, color: mint)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
        ]),
      );

  Widget _clickCard(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFF3FBF8), borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Icon(icon, color: mint, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
            const Icon(Icons.arrow_forward_ios, size: 16, color: mint),
          ]),
        ),
      );
}

Future<void> pick(BuildContext context, ValueChanged<String> done) async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
  if (result == null || !context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => SendPage(files: result.files, onDone: done)));
}

Future<void> receive(BuildContext context, ValueChanged<String> done) async {
  if (!context.mounted) return;
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => ReceiveSheet(onDone: done));
}

Future<void> openHub() async {
  final uri = Uri.parse(hub);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openAppSettings() async {
  final uri = Uri.parse('app-settings:');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

class SendPage extends StatefulWidget {
  final List<PlatformFile> files;
  final ValueChanged<String> onDone;
  const SendPage({super.key, required this.files, required this.onDone});
  @override
  State<SendPage> createState() => _SendState();
}

class _SendState extends State<SendPage> {
  final ip = TextEditingController();
  double progress = 0;
  String message = 'Enter the receiver IP shown on their Receive screen.';
  bool busy = false;

  Future<void> send() async {
    final address = ip.text.trim();
    if (address.isEmpty) return;
    setState(() => busy = true);
    try {
      for (var i = 0; i < widget.files.length; i++) {
        final selected = widget.files[i];
        if (selected.path == null) continue;
        final file = File(selected.path!);
        final request = http.StreamedRequest('PUT', Uri.parse('http://$address:8765/upload'));
        request.headers['x-file-name'] = Uri.encodeComponent(selected.name);
        request.headers['content-type'] = 'application/octet-stream';
        request.contentLength = await file.length();
        await for (final chunk in file.openRead()) request.sink.add(Uint8List.fromList(chunk));
        await request.sink.close();
        final response = await request.send();
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
        if (mounted) setState(() => progress = (i + 1) / widget.files.length);
      }
      if (mounted) setState(() => message = 'Transfer complete');
      widget.onDone('${widget.files.length} file(s) sent');
    } catch (error) {
      if (mounted) setState(() => message = 'Transfer failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { ip.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Send Files')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.files.length} file(s) selected', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(controller: ip, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Receiver IP address', hintText: '192.168.1.10', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            Text(message),
            const SizedBox(height: 18),
            LinearProgressIndicator(value: busy ? progress : null, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : send, icon: const Icon(Icons.send), label: const Padding(padding: EdgeInsets.all(14), child: Text('Start Transfer')))),
          ]),
        ),
      );
}

class ReceiveSheet extends StatefulWidget {
  final ValueChanged<String> onDone;
  const ReceiveSheet({super.key, required this.onDone});
  @override
  State<ReceiveSheet> createState() => _ReceiveState();
}

class _ReceiveState extends State<ReceiveSheet> {
  HttpServer? server;
  String ip = 'Finding...';
  String message = 'Starting receiver…';

  @override
  void initState() { super.initState(); start(); }

  Future<void> start() async {
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 8765);
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final network in interfaces) {
        for (final address in network.addresses) {
          if (!address.address.startsWith('127.')) ip = address.address;
        }
      }
      if (mounted) setState(() => message = 'Ready — enter this IP on the sender.');
      await for (final request in server!) {
        if (request.method == 'PUT' && request.uri.path == '/upload') {
          final name = Uri.decodeComponent(request.headers.value('x-file-name') ?? 'received.bin');
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$name');
          final sink = file.openWrite();
          await for (final chunk in request) sink.add(chunk);
          await sink.close();
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          widget.onDone(name);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      }
    } catch (error) {
      if (mounted) setState(() => message = 'Receiver error: $error');
    }
  }

  @override
  void dispose() { server?.close(force: true); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const BrandIcon(size: 58),
          const SizedBox(height: 8),
          const Text('Receive Files', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (ip != 'Finding...') QrImageView(data: 'palia-share://$ip:8765', size: 190),
          const SizedBox(height: 10),
          Text(ip, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Both phones should be on the same local Wi-Fi network.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]),
      );
}

class Transfers extends StatelessWidget {
  const Transfers({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Transfers', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)));
}

class Devices extends StatelessWidget {
  const Devices({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Nearby Devices', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)));
}

class History extends StatelessWidget {
  final List<String> items;
  const History({super.key, required this.items});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(children: [BrandIcon(size: 44), SizedBox(width: 12), Text('Transfer History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 18),
          if (items.isEmpty) const Text('No transfers yet.', style: TextStyle(color: Colors.black54)),
          ...items.map((item) => ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(item))),
        ],
      );
}

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String updateStatus = 'Check the latest Palia Share version.';
  bool checking = false;

  Future<void> checkForUpdates() async {
    setState(() {
      checking = true;
      updateStatus = 'Checking for updates…';
    });
    try {
      final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = '${data['version'] ?? currentVersion}';
      if (_isNewer(latest, currentVersion)) {
        if (!mounted) return;
        setState(() => updateStatus = 'New version $latest is available. Tap to update.');
        if (context.mounted) {
          showDialog(context: context, builder: (_) => AlertDialog(
            title: const Row(children: [BrandIcon(size: 38), SizedBox(width: 10), Text('Update Available')]),
            content: Text('${data['changelog'] is List ? (data['changelog'] as List).join('\n• ') : 'A new version is available.'}\n\nLatest version: $latest'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')), FilledButton(onPressed: () { Navigator.pop(context); openHub(); }, child: const Text('Update Now'))],
          ));
        }
      } else {
        if (mounted) setState(() => updateStatus = 'You are up to date • v$currentVersion');
      }
    } catch (_) {
      if (mounted) setState(() => updateStatus = 'Could not check right now. Tap to open PaliaAPK HUB.');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  bool _isNewer(String remote, String local) {
    List<int> parse(String value) => value.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final a = parse(remote), b = parse(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  void _show(String title, String message) => showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          const BrandIcon(size: 54),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
          ])),
        ]),
        const SizedBox(height: 18),
        const Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const Text('Customize your experience', style: TextStyle(color: Colors.black54, fontSize: 16)),
        const SizedBox(height: 18),
        _setting('My Device', 'Device name, visibility and info', Icons.phone_android_outlined, () => _show('My Device', 'Palia Share\nDevice name and visibility settings can be configured here.')),
        _setting('Notifications', 'Manage app notifications', Icons.notifications_none, openAppSettings),
        _setting('Download Location', 'Choose where to save received files', Icons.folder_outlined, () async {
          final directory = await getApplicationDocumentsDirectory();
          if (mounted) _show('Download Location', 'Palia Share currently saves received files to the app storage.\n\n${directory.path}');
        }),
        _setting('Transfer Settings', 'Speed, quality and connection options', Icons.bolt_outlined, () => _show('Transfer Settings', 'Local Wi-Fi transfer\nPort: 8765\nStreaming mode: enabled\nLarge files are streamed instead of loaded fully into memory.')),
        _setting('Privacy & Security', 'Permissions and data control', Icons.shield_outlined, () => _show('Privacy & Security', 'Palia Share transfers files directly between nearby devices. No transfer file is uploaded to PaliaAPK HUB. Android permissions are requested only when needed.')),
        _setting('Theme', 'Light, Dark or System theme', Icons.palette_outlined, () => _show('Theme', 'Current theme: Light\nTheme selector will be available here.')),
        _setting('Language', 'Choose your language', Icons.language_outlined, () => _show('Language', 'Current language: English')),
        const SizedBox(height: 14),
        InkWell(
          onTap: checking ? null : checkForUpdates,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFEFFFFA), borderRadius: BorderRadius.circular(24)),
            child: Row(children: [
              const BrandIcon(size: 58),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 5),
                Text(updateStatus, style: const TextStyle(color: Colors.black54, height: 1.3)),
              ])),
              FilledButton(onPressed: checking ? null : checkForUpdates, child: Text(checking ? 'Checking' : 'Check Now')),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: openHub,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(24)),
            child: const Row(children: [
              CircleAvatar(backgroundColor: Color(0xFFDDEEFF), child: Icon(Icons.rocket_launch_outlined, color: Color(0xFF1677C8))),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('More Apps & Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                SizedBox(height: 4),
                Text('Discover new apps, games and updates on PaliaAPK HUB.', style: TextStyle(color: Colors.black54)),
              ])),
              Icon(Icons.open_in_new, color: Color(0xFF1677C8)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Text('About', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _show('About Palia Share', 'Palia Share\nFast. Simple. Secure.\nDeveloper by Shanpalia\nVersion $currentVersion'),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black12)),
            child: const Row(children: [BrandIcon(size: 58), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Palia Share', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), SizedBox(height: 4), Text('Fast. Simple. Secure.\nDeveloper by Shanpalia', style: TextStyle(color: Colors.black54, height: 1.35))])), Text('v$currentVersion', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)), Icon(Icons.chevron_right, color: Colors.black45)],),
          ),
        ),
      ],
    );
  }

  Widget _setting(String title, String subtitle, IconData icon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.black12)),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ]),
          ),
        ),
      );
}
