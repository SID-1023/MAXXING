import 'dart:async';
import 'dart:typed_data';
import 'package:device_apps_ng/device_apps_ng.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DistractionBlockerScreen extends StatefulWidget {
  const DistractionBlockerScreen({super.key});

  @override
  State<DistractionBlockerScreen> createState() =>
      _DistractionBlockerScreenState();
}

class _DistractionBlockerScreenState extends State<DistractionBlockerScreen> {
  // MAXXING theme
  static const Color background = Color(0xFF17132B);
  static const Color surface = Color(0xFF241D42);
  static const Color cream = Color(0xFFF6EFE3);
  static const Color coral = Color(0xFFFF8A65);
  static const Color yellow = Color(0xFFFFD66B);
  static const Color mint = Color(0xFF7ED9B0);
  static const Color muted = Color(0xFFB9B1D0);

  // Preserve existing preference keys.
  static const String _websitesKey = 'maxxing_blocked_websites';
  static const String _enabledKey = 'maxxing_blocker_enabled';
  static const String _selectedAppsKey = 'maxxing_selected_apps';

  // Packages that must never be blockable (this app + critical system apps).
  static const Set<String> _hiddenPackages = {
    'com.example.maxxing',
    'com.android.systemui',
    'com.android.settings',
    'com.android.phone',
  };

  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _appSearchController = TextEditingController();

  Timer? _searchDebounce;

  List<String> _websites = [];

  // Changed to dynamic to hold Uint8List icons
  List<Map<String, dynamic>> _apps = [];
  Set<String> _selectedApps = {};

  bool _rulesEnabled = false;
  bool _settingsLoaded = false;
  bool _loadingApps = false;

  String? _appError;

  String get _appSearch => _appSearchController.text.trim().toLowerCase();

  List<Map<String, dynamic>> get _filteredApps {
    final query = _appSearch;

    if (query.isEmpty) return _apps;

    return _apps.where((app) {
      final name = (app['name'] ?? '').toString().toLowerCase();
      final packageName = (app['packageName'] ?? '').toString().toLowerCase();

      return name.contains(query) || packageName.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _websites = prefs.getStringList(_websitesKey) ?? [];
        _rulesEnabled = prefs.getBool(_enabledKey) ?? false;
        _selectedApps = (prefs.getStringList(_selectedAppsKey) ?? []).toSet();
        _settingsLoaded = true;
      });
    } catch (error) {
      debugPrint('MAXXING: Could not load blocker settings: $error');

      if (!mounted) return;

      setState(() {
        _settingsLoaded = true;
      });

      _showMessage('Could not load saved settings.');
    }

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadApps();
      }
    });
  }

  Future<void> _loadApps() async {
    if (_loadingApps) return;

    setState(() {
      _loadingApps = true;
      _appError = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final List<Application> installedApps =
          await DeviceApps.getInstalledApplications(
            includeAppIcons: true,
            includeSystemApps: true,
            onlyAppsWithLaunchIntent: true,
          );

      final loadedApps = installedApps
          .where((app) => !_hiddenPackages.contains(app.packageName))
          .map((app) {
            return <String, dynamic>{
              'name': app.appName,
              'packageName': app.packageName,
              'icon': app is ApplicationWithIcon ? app.icon : null,
            };
          })
          .toList();

      loadedApps.sort(
        (a, b) => a['name'].toString().toLowerCase().compareTo(
          b['name'].toString().toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _apps = loadedApps;
        _loadingApps = false;
      });

      stopwatch.stop();
      debugPrint(
        'MAXXING: Loaded ${loadedApps.length} apps '
        'in ${stopwatch.elapsedMilliseconds} ms.',
      );

      if (loadedApps.isEmpty) {
        _showMessage('No apps with a launcher icon were returned.');
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingApps = false;
        _appError = 'Could not load installed apps: $error';
      });

      debugPrint('MAXXING app loading failed: $error');
    }
  }

  Future<void> _saveWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_websitesKey, _websites);
  }

  Future<void> _saveSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _selectedApps.toList()..sort();
    await prefs.setStringList(_selectedAppsKey, saved);
  }

  Future<void> _toggleApp(String packageName, bool selected) async {
    final previousSelection = Set<String>.from(_selectedApps);

    setState(() {
      if (selected) {
        _selectedApps.add(packageName);
      } else {
        _selectedApps.remove(packageName);
      }
    });

    try {
      await _saveSelectedApps();
    } catch (error) {
      debugPrint('MAXXING: Could not save app selection: $error');

      if (!mounted) return;

      setState(() {
        _selectedApps = previousSelection;
      });

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
      _showMessage('Enter a valid domain, such as instagram.com.');
      return;
    }

    if (_websites.contains(domain)) {
      _showMessage('That website is already on your list.');
      return;
    }

    final previousWebsites = List<String>.from(_websites);

    setState(() {
      _websites = [domain, ..._websites];
      _websiteController.clear();
    });

    try {
      await _saveWebsites();

      if (mounted) {
        _showMessage('Website added to your list.');
      }
    } catch (error) {
      debugPrint('MAXXING: Could not save website: $error');

      if (!mounted) return;

      setState(() {
        _websites = previousWebsites;
      });

      _showMessage('Could not save the website.');
    }
  }

  Future<void> _removeWebsite(String domain) async {
    final previousWebsites = List<String>.from(_websites);

    setState(() {
      _websites = _websites.where((site) => site != domain).toList();
    });

    try {
      await _saveWebsites();
    } catch (error) {
      debugPrint('MAXXING: Could not remove website: $error');

      if (!mounted) return;

      setState(() {
        _websites = previousWebsites;
      });

      _showMessage('Could not update the website list.');
    }
  }

  Future<void> _setRulesEnabled(bool value) async {
    final previousValue = _rulesEnabled;

    setState(() {
      _rulesEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);

      if (!mounted) return;

      _showMessage(
        value
            ? 'Block-list setting saved. Verify Android enforcement.'
            : 'Block-list setting disabled.',
      );
    } catch (error) {
      debugPrint('MAXXING: Could not save blocker setting: $error');

      if (!mounted) return;

      setState(() {
        _rulesEnabled = previousValue;
      });

      _showMessage('Could not save the blocker setting.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
        foregroundColor: cream,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.shield_moon_rounded,
                color: yellow,
                size: 24,
              ),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAXXING',
                  style: TextStyle(
                    color: cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'DISTRACTION BLOCKER',
                  style: TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildDistractionBlockerScene(),
            const SizedBox(height: 20),
            _buildOverviewStats(),
            const SizedBox(height: 16),
            _buildProtectionCard(),
            const SizedBox(height: 27),
            _buildSectionHeading(
              'WEBSITE SHIELD',
              'Choose websites to avoid',
              Icons.language_rounded,
              coral,
            ),
            const SizedBox(height: 14),
            _buildWebsiteInput(),
            const SizedBox(height: 12),
            _buildSuggestions(),
            const SizedBox(height: 14),
            if (_websites.isEmpty)
              _buildEmptyWebsites()
            else
              ..._websites.map(_buildWebsiteTile),
            const SizedBox(height: 27),
            _buildSectionHeading(
              'APP SHIELD',
              'Choose apps that distract you',
              Icons.phonelink_lock_rounded,
              mint,
            ),
            const SizedBox(height: 14),
            _buildAppSelector(),
            const SizedBox(height: 20),
            _buildFooterNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildDistractionBlockerScene() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.asset(
          'assets/images/distraction_blocker_scene.png',
          width: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(
              color: Color(0xFF17132B),
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFFFFD66B),
                  size: 32,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAKE BACK YOUR TIME',
          style: TextStyle(
            color: yellow,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Block distractions.',
          style: TextStyle(
            color: cream,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Build a quieter digital space and make room for what matters.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildOverviewStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.apps_rounded,
            value: '${_selectedApps.length}',
            label: 'SELECTED APPS',
            accent: mint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.language_rounded,
            value: '${_websites.length}',
            label: 'WEBSITES',
            accent: coral,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionCard() {
    final active = _rulesEnabled;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: active
              ? const [Color(0xFF30453F), surface]
              : const [Color(0xFF393057), surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: (active ? mint : yellow).withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  color: (active ? mint : yellow).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  active ? Icons.shield_rounded : Icons.shield_outlined,
                  color: active ? mint : yellow,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Block-list is ON' : 'Block-list is OFF',
                      style: const TextStyle(
                        color: cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      active
                          ? 'Your saved setting is enabled.'
                          : 'Choose your rules before focusing.',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: active,
                activeTrackColor: mint,
                onChanged: _setRulesEnabled,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withValues(alpha: 0.09), height: 1),
          const SizedBox(height: 13),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: yellow, size: 17),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This switch saves your block-list setting. '
                  'Actual Android enforcement must be configured and verified.',
                  style: TextStyle(color: muted, fontSize: 10, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebsiteInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _websiteController,
            style: const TextStyle(color: cream, fontSize: 13),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addWebsite(),
            decoration: InputDecoration(
              hintText: 'Enter a website domain...',
              hintStyle: const TextStyle(color: muted, fontSize: 12),
              prefixIcon: const Icon(
                Icons.language_rounded,
                color: coral,
                size: 20,
              ),
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: coral, width: 1.3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 52,
          height: 52,
          child: FilledButton(
            onPressed: _addWebsite,
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: background,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Icon(Icons.add_rounded, size: 27),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    const suggestions = [
      'instagram.com',
      'youtube.com',
      'reddit.com',
      'tiktok.com',
      'facebook.com',
    ];

    final availableSuggestions = suggestions
        .where((site) => !_websites.contains(site))
        .toList();

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: availableSuggestions.map((site) {
        return ActionChip(
          avatar: const Icon(Icons.add_rounded, color: coral, size: 15),
          label: Text(site),
          labelStyle: const TextStyle(
            color: cream,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: surface,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onPressed: () async {
            _websiteController.text = site;
            await _addWebsite();
          },
        );
      }).toList(),
    );
  }

  Widget _buildEmptyWebsites() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 23),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        children: [
          Icon(Icons.travel_explore_rounded, color: coral, size: 34),
          SizedBox(height: 10),
          Text(
            'Your website shield is empty',
            style: TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add distracting websites above to build your personal list.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteTile(String domain) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: coral.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.language_rounded, color: coral, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'On your website list',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove website',
            onPressed: () => _removeWebsite(domain),
            style: IconButton.styleFrom(
              backgroundColor: coral.withValues(alpha: 0.09),
            ),
            icon: const Icon(Icons.close_rounded, color: coral, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSelector() {
    final filteredApps = _filteredApps;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: mint.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedApps.length} apps selected',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh installed apps',
                onPressed: _loadingApps ? null : _loadApps,
                icon: const Icon(Icons.refresh_rounded, color: mint),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Choose the apps you want to stay away from.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _appSearchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: cream, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search installed apps...',
              hintStyle: const TextStyle(color: muted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: mint),
              suffixIcon: _appSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _appSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, color: muted),
                    ),
              filled: true,
              fillColor: background,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: mint, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (!_settingsLoaded || _loadingApps)
            _buildAppLoadingState()
          else if (_appError != null)
            _buildAppError()
          else if (_apps.isEmpty)
            _buildNoApps()
          else if (filteredApps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No apps match your search.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 320,
              child: ListView.builder(
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];

                  return _buildAppTile(
                    app: app,
                    selected: _selectedApps.contains(app['packageName']),
                    showDivider: index < filteredApps.length - 1,
                  );
                },
              ),
            ),

          if (_settingsLoaded &&
              !_loadingApps &&
              _appError == null &&
              _apps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.apps_rounded, color: muted, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing ${filteredApps.length} of ${_apps.length} apps',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppLoadingState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: mint),
          ),
          SizedBox(height: 12),
          Text(
            'Loading your apps...',
            style: TextStyle(
              color: cream,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'You can keep using the rest of the screen.',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile({
    required Map<String, dynamic> app,
    required bool selected,
    required bool showDivider,
  }) {
    final String name = app['name'] ?? 'Unknown app';
    final String packageName = app['packageName'] ?? '';
    final Uint8List? iconBytes = app['icon'];

    return Column(
      children: [
        InkWell(
          onTap: packageName.isEmpty
              ? null
              : () => _toggleApp(packageName, !selected),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 41,
                  height: 41,
                  decoration: BoxDecoration(
                    color: selected ? mint.withValues(alpha: 0.14) : background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: iconBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.memory(
                            iconBytes,
                            width: 41,
                            height: 41,
                            fit: BoxFit.cover,
                            cacheWidth: 100,
                            cacheHeight: 100,
                            gaplessPlayback: true,
                          ),
                        )
                      : Icon(
                          Icons.android_rounded,
                          color: selected ? mint : muted,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: selected ? mint : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected ? mint : muted.withValues(alpha: 0.45),
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: background,
                          size: 19,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }

  Widget _buildAppError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 17),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: coral, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Could not load installed apps',
            textAlign: TextAlign.center,
            style: TextStyle(color: cream, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _appError ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed: _loadApps,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: mint,
              side: const BorderSide(color: mint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoApps() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(Icons.phone_android_rounded, color: muted, size: 35),
          const SizedBox(height: 10),
          const Text(
            'No apps found',
            textAlign: TextAlign.center,
            style: TextStyle(color: cream, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check the Android app visibility configuration and refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5, fontSize: 11),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadApps,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh installed apps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: mint,
              side: const BorderSide(color: mint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: yellow, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your selections are saved on this device. Actual app and '
              'website enforcement depends on the Android blocking service '
              'and its configuration.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
