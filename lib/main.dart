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
      ),
      home: const Home(),
    );
  }
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfers'),
          NavigationDestination(icon: Icon(Icons.devices_other), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
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
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: mint.withValues(alpha: .1), borderRadius: BorderRadius.circular(15)),
            child: SvgPicture.asset('assets/palia_share_logo.svg'),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
          ])),
          const Icon(Icons.account_circle_outlined, size: 32),
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
        Row(children: [quick(Icons.photo_library_outlined, 'Photos'), quick(Icons.videocam_outlined, 'Videos'), quick(Icons.android, 'Apps'), quick(Icons.folder_outlined, 'Files')]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: mint.withValues(alpha: .18))),
          child: const Row(children: [
            CircleAvatar(backgroundColor: Color(0xFFE8FBF5), child: Icon(Icons.wifi_tethering, color: mint)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ready to connect', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Choose Send or Receive to start.', style: TextStyle(color: Colors.black54)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: openHub,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF3FBF8), borderRadius: BorderRadius.circular(22)),
            child: const Row(children: [
              Icon(Icons.rocket_launch_outlined, color: mint, size: 30),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('More Apps & Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                Text('Discover apps, games and updates on PaliaAPK HUB.', style: TextStyle(color: Colors.black54)),
              ])),
              Icon(Icons.arrow_forward_ios, size: 16, color: mint),
            ]),
          ),
        ),
      ],
    );
  }

  Widget quick(IconData icon, String label) => Expanded(child: Column(children: [
    Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1FBF8), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)),
    const SizedBox(height: 6),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]));
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
        await for (final chunk in file.openRead()) {
          request.sink.add(Uint8List.fromList(chunk));
        }
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
      const Text('Transfer History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      if (items.isEmpty) const Text('No transfers yet.', style: TextStyle(color: Colors.black54)),
      ...items.map((item) => ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(item))),
    ],
  );
}

class Settings extends StatelessWidget {
  const Settings({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      ListTile(
        leading: const Icon(Icons.notifications_none),
        title: const Text('Notifications'),
        subtitle: const Text('Manage Palia Share notifications in Android Settings'),
        onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Notifications'), content: Text('Enable Palia Share notifications in Android Settings to receive update alerts.'))),
      ),
      ListTile(leading: const Icon(Icons.system_update_alt), title: const Text('Check for Updates'), subtitle: const Text('Open PaliaAPK HUB'), onTap: openHub),
      ListTile(leading: const Icon(Icons.public), title: const Text('PaliaAPK HUB'), subtitle: Text(hub), onTap: openHub),
      const Divider(),
      const ListTile(title: Text('About Palia Share'), subtitle: Text('Fast. Simple. Secure.\nDeveloper by Shanpalia')),
    ],
  );
}
