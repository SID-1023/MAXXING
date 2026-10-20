import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DistractionBlockerScreen extends StatefulWidget {
  const DistractionBlockerScreen({super.key});

  @override
  State<DistractionBlockerScreen> createState() =>
      _DistractionBlockerScreenState();
}

class _DistractionBlockerScreenState extends State<DistractionBlockerScreen> {
  static const Color background = Color(0xFF09090F);
  static const Color surface = Color(0xFF15141D);
  static const Color purple = Color(0xFFB69CFF);

  static const String _websitesKey = 'maxxing_blocked_websites';
  static const String _enabledKey = 'maxxing_blocker_enabled';
  static const String _selectedAppsKey = 'maxxing_selected_apps';

  static const MethodChannel _channel = MethodChannel('maxxing/app_blocker');

  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _appSearchController = TextEditingController();

  List<String> _websites = [];
  List<Map<String, String>> _apps = [];
  Set<String> _selectedApps = {};

  bool _rulesEnabled = false;
  bool _loading = true;
  bool _loadingApps = false;
  String? _appError;

  String get _appSearch => _appSearchController.text.trim().toLowerCase();

  List<Map<String, String>> get _filteredApps {
    if (_appSearch.isEmpty) return _apps;

    return _apps.where((app) {
      final name = (app['name'] ?? '').toLowerCase();
      final packageName = (app['packageName'] ?? '').toLowerCase();

      return name.contains(_appSearch) || packageName.contains(_appSearch);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _websites = prefs.getStringList(_websitesKey) ?? [];
        _rulesEnabled = prefs.getBool(_enabledKey) ?? false;
        _selectedApps = (prefs.getStringList(_selectedAppsKey) ?? []).toSet();
        _loading = false;
      });

      await _loadApps();
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Could not load saved settings.');
    }
  }

  Future<void> _loadApps() async {
    if (_loadingApps) return;

    setState(() {
      _loadingApps = true;
      _appError = null;
    });

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getLaunchableApps',
      );

      final loadedApps = (result ?? [])
          .whereType<Map>()
          .map((item) {
            return <String, String>{
              'name': item['name']?.toString() ?? 'Unknown app',
              'packageName': item['packageName']?.toString() ?? '',
            };
          })
          .where((app) => app['packageName']!.isNotEmpty)
          .toList();

      loadedApps.sort(
        (a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _apps = loadedApps;
        _loadingApps = false;
      });

      if (loadedApps.isEmpty) {
        _showMessage(
          'No launchable apps found. Check Android app discovery settings.',
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingApps = false;
        _appError = '${e.code}: ${e.message ?? 'Unable to load apps.'}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingApps = false;
        _appError = 'Could not load installed apps: $e';
      });
    }
  }

  Future<void> _saveWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_websitesKey, _websites);
  }

  Future<void> _saveSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedAppsKey, _selectedApps.toList()..sort());
  }

  Future<void> _toggleApp(String packageName, bool selected) async {
    setState(() {
      if (selected) {
        _selectedApps.add(packageName);
      } else {
        _selectedApps.remove(packageName);
      }
    });

    try {
      await _saveSelectedApps();
    } catch (_) {
      _showMessage('Could not save app selection.');
    }
  }

  Future<void> _addWebsite() async {
    final raw = _websiteController.text.trim().toLowerCase();

    if (raw.isEmpty) return;

    var domain = raw
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')[0]
        .split('?')[0]
        .split('#')[0]
        .trim();

    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }

    final validDomain = RegExp(
      r'^(?=.{1,253}$)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
      r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
    ).hasMatch(domain);

    if (!validDomain) {
      _showMessage('Enter a valid domain, e.g. instagram.com');
      return;
    }

    if (_websites.contains(domain)) {
      _showMessage('That website is already on your list.');
      return;
    }

    setState(() {
      _websites.insert(0, domain);
      _websiteController.clear();
    });

    await _saveWebsites();

    if (mounted) _showMessage('Website added to your list.');
  }

  Future<void> _removeWebsite(String domain) async {
    setState(() => _websites.remove(domain));
    await _saveWebsites();
  }

  Future<void> _setRulesEnabled(bool value) async {
    setState(() => _rulesEnabled = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);

    if (mounted) {
      _showMessage(
        value
            ? 'List enabled. Actual blocking is not connected yet.'
            : 'List disabled.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _websiteController.dispose();
    _appSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Distraction Blocker',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 22),
                  _sectionTitle('WEBSITE BLOCK LIST'),
                  const SizedBox(height: 12),
                  _buildWebsiteInput(),
                  const SizedBox(height: 12),
                  _buildSuggestions(),
                  const SizedBox(height: 16),
                  if (_websites.isEmpty)
                    _buildEmptyState()
                  else
                    ..._websites.map(_buildWebsiteTile),
                  const SizedBox(height: 22),
                  _sectionTitle('APP BLOCKING'),
                  const SizedBox(height: 12),
                  _buildAppSelector(),
                  const SizedBox(height: 20),
                  const Text(
                    'Your selections are saved on this device. '
                    'App restrictions and website filtering are not '
                    'enforced yet and require additional Android integration.',
                    style: TextStyle(
                      color: Colors.white54,
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF29203D), Color(0xFF171520)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_moon_outlined, color: purple, size: 34),
          const SizedBox(height: 16),
          const Text(
            'Protect your focus.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Build a distraction-free environment '
            'for your next deep-work session.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.toggle_on, color: purple, size: 30),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Block list',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Saved rules only — filtering not connected',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _rulesEnabled,
                  activeThumbColor: purple,
                  onChanged: _setRulesEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildWebsiteInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _websiteController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addWebsite(),
            decoration: InputDecoration(
              hintText: 'e.g. instagram.com',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          width: 52,
          child: FilledButton(
            onPressed: _addWebsite,
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: background,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(Icons.add, size: 25),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    const suggestions = [
      'instagram.com',
      'reddit.com',
      'tiktok.com',
      'facebook.com',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions
          .where((site) => !_websites.contains(site))
          .map(
            (site) => ActionChip(
              label: Text(site),
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              backgroundColor: surface,
              side: BorderSide.none,
              onPressed: () async {
                _websiteController.text = site;
                await _addWebsite();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.public, color: purple, size: 32),
          SizedBox(height: 10),
          Text(
            'Your list is empty',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 5),
          Text(
            'Add a website you want to avoid.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteTile(String domain) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.language, color: purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              domain,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove website',
            onPressed: () => _removeWebsite(domain),
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phonelink_lock, color: purple, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose distracting apps',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedApps.length} app(s) selected',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh installed apps',
                onPressed: _loadingApps ? null : _loadApps,
                icon: const Icon(Icons.refresh, color: purple),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _appSearchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search installed apps',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _appSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _appSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingApps)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: purple)),
            )
          else if (_appError != null)
            _buildAppError()
          else if (_apps.isEmpty)
            _buildNoApps()
          else if (_filteredApps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: Text(
                  'No apps match your search.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredApps.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final app = _filteredApps[index];
                  final name = app['name']!;
                  final packageName = app['packageName']!;
                  final selected = _selectedApps.contains(packageName);

                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      _toggleApp(packageName, value ?? false);
                    },
                    activeColor: purple,
                    checkColor: background,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      packageName,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.android, color: purple, size: 23),
                    ),
                  );
                },
              ),
            ),
          if (!_loadingApps && _apps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Showing ${_filteredApps.length} of ${_apps.length} apps',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Could not load installed apps',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _appError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadApps,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(foregroundColor: purple),
          ),
        ],
      ),
    );
  }

  Widget _buildNoApps() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.phone_android, color: Colors.white38, size: 34),
          const SizedBox(height: 10),
          const Text(
            'No launchable apps found',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check the Android integration and app visibility configuration, '
            'then refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadApps,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh installed apps'),
            style: OutlinedButton.styleFrom(foregroundColor: purple),
          ),
        ],
      ),
    );
  }
}
