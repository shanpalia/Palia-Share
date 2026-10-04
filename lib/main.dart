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

void main() => runApp(const PaliaShareApp());

class PaliaShareApp extends StatelessWidget {
  const PaliaShareApp({super.key});

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
      home: const SplashPage(),
    );
  }
}

class BrandIcon extends StatelessWidget {
  final double size;
  const BrandIcon({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset('assets/palia_share_logo.svg'),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PermissionPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            BrandIcon(size: 110),
            SizedBox(height: 18),
            Text('Palia Share', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
            SizedBox(height: 22),
            Text('Developer by Shanpalia', style: TextStyle(color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
  }

  Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    if (mounted) setState(() => loading = false);
  }

  void continueToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandIcon(size: 82),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Palia Share',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Android permissions are requested only when Palia Share needs them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 28),
              if (loading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: continueToHome,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Continue'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  final List<String> history = [];

  void addHistory(String value) {
    setState(() => history.insert(0, value));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onHistory: addHistory),
      TransfersPage(items: history),
      const DevicesPage(),
      HistoryPage(items: history),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[selected]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
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

  Future<void> selectFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendPage(files: result.files, onDone: onHistory),
      ),
    );
  }

  void openReceive(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceivePage(onDone: onHistory)),
    );
  }

  Future<void> openHub() async {
    final uri = Uri.parse(hubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Row(
          children: [
            BrandIcon(size: 52),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Palia Share', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  Text('Fast. Simple. Secure.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEFFFFA), Color(0xFFF8FFFC)]),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share files at lightning speed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Transfer photos, videos, apps and documents directly between nearby Android phones.', style: TextStyle(color: Colors.black54, height: 1.4)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: () => selectFiles(context), icon: const Icon(Icons.send_rounded), label: const Text('Send Files'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => openReceive(context), icon: const Icon(Icons.download_rounded), label: const Text('Receive'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Quick Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            quick(context, Icons.photo_library_outlined, 'Photos'),
            quick(context, Icons.videocam_outlined, 'Videos'),
            quick(context, Icons.android, 'Apps'),
            quick(context, Icons.folder_outlined, 'Files'),
          ],
        ),
        const SizedBox(height: 24),
        infoCard(Icons.wifi_tethering, 'Ready to connect', 'Choose Send or Receive to start.'),
        const SizedBox(height: 14),
        InkWell(
          onTap: openHub,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF3FBF8), borderRadius: BorderRadius.circular(22)),
            child: const Row(
              children: [
                Icon(Icons.rocket_launch_outlined, color: mint, size: 30),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('More Apps & Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 4), Text('Discover apps, games and updates on PaliaAPK HUB.', style: TextStyle(color: Colors.black54))])),
                Icon(Icons.arrow_forward_ios, size: 16, color: mint),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget quick(BuildContext context, IconData icon, String label) {
    return Expanded(
      child: InkWell(
        onTap: () => selectFiles(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1FBF8), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: mint.withValues(alpha: .18))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFFE8FBF5), child: Icon(icon, color: mint)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
        ],
      ),
    );
  }
}

class SendPage extends StatefulWidget {
  final List<PlatformFile> files;
  final ValueChanged<String> onDone;
  const SendPage({super.key, required this.files, required this.onDone});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final ipController = TextEditingController();
  double progress = 0;
  String status = 'Enter the receiver IP shown on their Receive screen.';
  bool busy = false;

  Future<void> sendFiles() async {
    final address = ipController.text.trim();
    if (address.isEmpty) {
      setState(() => status = 'Enter a receiver IP address.');
      return;
    }

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
      if (mounted) setState(() => status = 'Transfer complete');
      widget.onDone('${widget.files.length} file(s) sent');
    } catch (error) {
      if (mounted) setState(() => status = 'Transfer failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Files')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.files.length} file(s) selected', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(controller: ipController, decoration: const InputDecoration(labelText: 'Receiver IP address', hintText: '192.168.1.10', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            Text(status),
            const SizedBox(height: 18),
            LinearProgressIndicator(value: busy ? progress : null, minHeight: 8),
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : sendFiles, icon: const Icon(Icons.send), label: const Padding(padding: EdgeInsets.all(14), child: Text('Start Transfer')))),
          ],
        ),
      ),
    );
  }
}

class ReceivePage extends StatefulWidget {
  final ValueChanged<String> onDone;
  const ReceivePage({super.key, required this.onDone});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  HttpServer? server;
  String ip = 'Finding...';
  String status = 'Starting receiver…';

  @override
  void initState() {
    super.initState();
    startReceiver();
  }

  Future<void> startReceiver() async {
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 8765);
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final network in interfaces) {
        for (final address in network.addresses) {
          if (!address.address.startsWith('127.')) ip = address.address;
        }
      }
      if (mounted) setState(() => status = 'Ready — enter this IP on the sender.');

      await for (final request in server!) {
        if (request.method == 'PUT' && request.uri.path == '/upload') {
          final rawName = request.headers.value('x-file-name') ?? 'received.bin';
          final name = Uri.decodeComponent(rawName).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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
      if (mounted) setState(() => status = 'Receiver error: $error');
    }
  }

  @override
  void dispose() {
    server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Files')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const BrandIcon(size: 65),
          const SizedBox(height: 10),
          const Text('Receive Files', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(status),
          const SizedBox(height: 18),
          if (ip != 'Finding...') Center(child: QrImageView(data: 'palia-share://$ip:8765', size: 210)),
          const SizedBox(height: 10),
          Center(child: Text(ip, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          const Text('Both phones should be on the same local Wi-Fi network.', textAlign: TextAlign.center),
          const SizedBox(height: 22),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Keep this screen open while receiving. Received files are saved to Palia Share app storage.'))),
        ],
      ),
    );
  }
}

class TransfersPage extends StatelessWidget {
  final List<String> items;
  const TransfersPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Transfers', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Your current and completed transfers.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        if (items.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No transfers yet. Start a Send or Receive session from Home.')))
        else
          ...items.map((item) => ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(item))),
      ],
    );
  }
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Devices', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Nearby device connection', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        const Card(child: ListTile(leading: Icon(Icons.wifi, color: mint), title: Text('Local Wi-Fi'), subtitle: Text('Connect both phones to the same Wi-Fi, then use Receive to show your device address.'))),
        Card(child: ListTile(onTap: openSettings, leading: const Icon(Icons.settings_outlined), title: const Text('Android connection settings'), subtitle: const Text('Open Android settings to manage network permissions and connections.'))),
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  final List<String> items;
  const HistoryPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('History', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('No transfer history yet.', style: TextStyle(color: Colors.black54))
        else
          ...items.map((item) => Card(child: ListTile(leading: const Icon(Icons.check_circle, color: mint), title: Text(item)))),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String updateStatus = 'Check the latest Palia Share version.';
  bool checking = false;

  Future<void> checkUpdates() async {
    setState(() {
      checking = true;
      updateStatus = 'Checking for updates…';
    });
    try {
      final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = '${data['version'] ?? currentVersion}';
      if (isNewer(latest, currentVersion)) {
        if (!mounted) return;
        setState(() => updateStatus = 'New version $latest is available.');
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(children: [BrandIcon(size: 38), SizedBox(width: 10), Text('Update Available')]),
            content: Text('Palia Share $latest is available.\n\nTap Update Now to open PaliaAPK HUB.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
              FilledButton(onPressed: () { Navigator.pop(dialogContext); openHub(); }, child: const Text('Update Now')),
            ],
          ),
        );
      } else if (mounted) {
        setState(() => updateStatus = 'You are up to date • v$currentVersion');
      }
    } catch (_) {
      if (mounted) setState(() => updateStatus = 'Check failed. Tap to retry.');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  bool isNewer(String remote, String local) {
    final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r != l) return r > l;
    }
    return false;
  }

  Future<void> openHub() async {
    final uri = Uri.parse(hubUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openAndroidSettings() async {
    await openAppSettings();
  }

  void openDetail(String title, String subtitle, IconData icon, List<Widget> children) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(title: title, subtitle: subtitle, icon: icon, children: children)),
    );
  }

  Widget settingTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.black12)),
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: mint)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Row(children: [BrandIcon(size: 50), SizedBox(width: 12), Expanded(child: Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 16),
        const Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const Text('Customize your experience', style: TextStyle(color: Colors.black54, fontSize: 16)),
        const SizedBox(height: 18),
        settingTile('My Device', 'Device name, visibility and info', Icons.phone_android_outlined, () => openDetail('My Device', 'Device information', Icons.phone_android_outlined, const [ListTile(title: Text('Device name'), subtitle: Text('Palia Share')), ListTile(title: Text('Visibility'), subtitle: Text('Visible when Receive screen is open')), ListTile(title: Text('Connection'), subtitle: Text('Local Wi-Fi transfer'))])),
        settingTile('Notifications', 'Manage Palia Share notifications', Icons.notifications_none, () => openDetail('Notifications', 'Android notification permission', Icons.notifications_none, [const Text('Palia Share uses Android system notifications for update alerts when notification permission is allowed.'), const SizedBox(height: 16), FilledButton.icon(onPressed: () => Permission.notification.request(), icon: const Icon(Icons.notifications_active_outlined), label: const Text('Allow Notifications')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: openAndroidSettings, icon: const Icon(Icons.settings), label: const Text('Open Android Settings'))])),
        settingTile('Download Location', 'Where received files are saved', Icons.folder_outlined, () async { final directory = await getApplicationDocumentsDirectory(); if (!context.mounted) return; openDetail('Download Location', 'Received files', Icons.folder_outlined, [const Text('Received files are currently saved inside Palia Share app storage.'), const SizedBox(height: 12), SelectableText(directory.path)]); }),
        settingTile('Transfer Settings', 'Speed, quality and connection options', Icons.bolt_outlined, () => openDetail('Transfer Settings', 'Local transfer', Icons.bolt_outlined, const [ListTile(title: Text('Transfer mode'), subtitle: Text('Streaming / chunked transfer')), ListTile(title: Text('Port'), subtitle: Text('8765')), ListTile(title: Text('Network'), subtitle: Text('Local Wi-Fi'))])),
        settingTile('Privacy & Security', 'Permissions and data control', Icons.shield_outlined, () => openDetail('Privacy & Security', 'Your files stay local', Icons.shield_outlined, const [Text('Palia Share transfers files directly between nearby devices. Transfer files are not uploaded to PaliaAPK HUB.'), SizedBox(height: 14), Text('Permissions are requested only when an Android feature needs them. Notification permission is requested after the splash screen.')])),
        settingTile('Theme', 'Light, Dark or System', Icons.palette_outlined, () => openDetail('Theme', 'Appearance', Icons.palette_outlined, const [ListTile(title: Text('Light'), leading: Icon(Icons.light_mode_outlined, color: mint)), ListTile(title: Text('System'), leading: Icon(Icons.phone_android_outlined)), ListTile(title: Text('Dark'), leading: Icon(Icons.dark_mode_outlined))])),
        settingTile('Language', 'Choose your language', Icons.language_outlined, () => openDetail('Language', 'App language', Icons.language_outlined, const [ListTile(title: Text('English'), trailing: Icon(Icons.check, color: mint)), ListTile(title: Text('Hindi'))])),
        const SizedBox(height: 12),
        InkWell(
          onTap: checking ? null : checkUpdates,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFEFFFFA), borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                const BrandIcon(size: 54),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), Text('v$currentVersion • $updateStatus', style: const TextStyle(color: Colors.black54))])),
                FilledButton(onPressed: checking ? null : checkUpdates, child: Text(checking ? 'Checking' : 'Check')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: openHub,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(24)),
            child: const Row(
              children: [
                Icon(Icons.rocket_launch_outlined, color: Color(0xFF1677C8), size: 32),
                SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PaliaAPK HUB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), SizedBox(height: 4), Text('Tap to open the website. The URL is hidden from the UI.', style: TextStyle(color: Colors.black54))])),
                Icon(Icons.open_in_new, color: Color(0xFF1677C8)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () => openDetail('About Palia Share', 'App information', Icons.info_outline, const [BrandIcon(size: 72), SizedBox(height: 12), Text('Palia Share', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('Fast. Simple. Secure.'), SizedBox(height: 10), Text('Developer by Shanpalia'), SizedBox(height: 8), Text('Version 1.0.0')]),
          borderRadius: BorderRadius.circular(22),
          child: const ListTile(leading: Icon(Icons.info_outline, color: mint), title: Text('About Palia Share'), subtitle: Text('Fast. Simple. Secure. • Developer by Shanpalia'), trailing: Icon(Icons.chevron_right)),
        ),
      ],
    );
  }
}

class DetailPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const DetailPage({super.key, required this.title, required this.subtitle, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFE8F8F3), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: mint, size: 30)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: Colors.black54))])),
            ],
          ),
          const SizedBox(height: 22),
          ...children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: child)))),
        ],
      ),
    );
  }
}
