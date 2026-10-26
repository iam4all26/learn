import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../utils/kaida_alert.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/kaida_empty_state.dart';

const Color _yellow = Color(0xFFFFC21A);
const Color _deep = Color(0xFF3A22C4);
const Color _purple = Color(0xFF6B47F5);

/// Daily reward streak (app only). All amounts come from the server (Admin > Daily Rewards).
class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({Key? key}) : super(key: key);
  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen> {
  bool _loading = true;
  bool _failed = false;
  bool _claiming = false;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final r = await http.post(Uri.parse(ApiConfig.dailyRewardStatus));
      final j = json.decode(r.body);
      if (j['status'] == 'success') {
        _d = Map<String, dynamic>.from(j['data']);
      } else {
        _failed = true;
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final r = await http.post(Uri.parse(ApiConfig.dailyRewardClaim));
      final j = json.decode(r.body);
      if (!mounted) return;
      if (j['status'] == 'success') {
        _d = Map<String, dynamic>.from(j['data']);
        final amt = _num(j['amount']);
        setState(() {});
        KaidaAlert.showSuccess(context, title: 'Reward claimed', message: '+${_fmt(amt)} Kaida Points were added to your wallet.', onOk: null);
      } else {
        KaidaAlert.showError(context, message: (j['message'] ?? '').toString(), title: 'Not available');
        _load();
      }
    } catch (e) {
      if (mounted) KaidaAlert.showError(context, error: e, onRetry: _claim);
    }
    if (mounted) setState(() => _claiming = false);
  }

  double _num(dynamic v) => double.tryParse('$v') ?? 0;
  String _fmt(double v) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB);
    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const KaidaSkeletonList(count: 4, padding: EdgeInsets.fromLTRB(16, 90, 16, 20))
          : _failed
              ? Column(children: [_hero(dark), Expanded(child: KaidaErrorState(onRetry: _load))])
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_hero(dark), _body(dark)],
                  ),
                ),
    );
  }

  Widget _hero(bool dark) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, top + 12, 18, 54),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [_deep, _purple], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(
        children: [
          Positioned(
            right: 0, bottom: 0,
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.inventory_2_rounded, size: 110, color: Colors.white.withOpacity(0.14)),
              Container(
                width: 58, height: 58,
                decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle),
                child: const Center(child: Text('K', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
              ),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 26, height: 26, decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle), child: const Icon(Icons.star_rounded, color: Colors.white, size: 17)),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Kaida Points', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        Text(_fmt(_num(_d['balance'])), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      ]),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              RichText(text: const TextSpan(children: [
                TextSpan(text: 'Daily ', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                TextSpan(text: 'Reward', style: TextStyle(color: _yellow, fontSize: 34, fontWeight: FontWeight.w900)),
              ])),
              const SizedBox(height: 4),
              const Text('Earn Kaida Points every day', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const SizedBox(
                width: 240,
                child: Text('Log in every day to earn Kaida Points and keep your streak going to win a bigger bonus.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(bool dark, Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
        padding: padding,
        decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.2 : 0.06), blurRadius: 14, offset: const Offset(0, 5))]),
        child: child,
      );

  Widget _body(bool dark) {
    final enabled = _d['enabled'] == true;
    final claimed = _d['claimed_today'] == true;
    final poolEmpty = _d['pool_empty'] == true;
    final streak = (_d['streak'] ?? 0) as int;
    final todayDay = (_d['today_day'] ?? 1) as int;
    final todayAmt = _num(_d['today_amount']);
    final days = (_d['days'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final toBonus = (_d['days_to_bonus'] ?? 0) as int;
    final ink = dark ? Colors.white : const Color(0xFF16123A);
    final doneCount = days.where((d) => d['state'] == 'claimed' || (d['state'] == 'today' && claimed)).length;

    return Transform.translate(
      offset: const Offset(0, -34),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _card(
              dark,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Weekly Streak', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink)),
                          const SizedBox(height: 2),
                          Text('Claim all 7 days to win the weekly bonus!', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(16)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 18),
                          const SizedBox(width: 4),
                          Text('$doneCount / 7 days', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E1E2D))),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(children: [for (final d in days) Expanded(child: _dayTile(d, claimed, dark))]),
                  const SizedBox(height: 12),
                  _progressBar(days, claimed),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _todayCard(dark, enabled, claimed, poolEmpty, todayAmt, todayDay),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _statCard(dark, Icons.workspace_premium_rounded, _purple, 'Current Streak', '$streak ${streak == 1 ? 'Day' : 'Days'}', streak > 0 ? 'Keep it going!' : 'Claim today to start')),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    dark, Icons.star_rounded, _yellow, 'Next Milestone',
                    toBonus <= 0 ? 'Today!' : '$toBonus ${toBonus == 1 ? 'Day' : 'Days'} Left',
                    'You get +${_fmt(_num(_d['bonus_amount']))} Points',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Missing a day resets your streak to Day 1. Rewards are for app users only.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _dayTile(Map<String, dynamic> d, bool claimedToday, bool dark) {
    final state = d['state'] as String;
    final isToday = state == 'today';
    final done = state == 'claimed' || (isToday && claimedToday);
    final amt = _num(d['amount']);
    final bgc = isToday ? _deep : (done ? const Color(0xFFFFF4D6) : (dark ? Colors.white10 : const Color(0xFFF1EFFB)));
    final fg = isToday ? Colors.white : (dark ? Colors.white70 : const Color(0xFF3B3B4F));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(14), boxShadow: isToday ? [BoxShadow(color: _deep.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : null),
      child: Column(
        children: [
          done
              ? Container(width: 26, height: 26, decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 17))
              : Icon(d['day'] == 7 ? Icons.emoji_events_rounded : Icons.card_giftcard_rounded, size: 24, color: isToday ? _yellow : Colors.grey.shade400),
          const SizedBox(height: 5),
          Text('Day ${d['day']}', style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
          FittedBox(fit: BoxFit.scaleDown, child: Text('+${_fmt(amt)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: isToday ? Colors.white : const Color(0xFF6B47F5)))),
        ],
      ),
    );
  }

  Widget _progressBar(List<Map<String, dynamic>> days, bool claimedToday) {
    return Row(
      children: [
        for (int i = 0; i < days.length; i++) ...[
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (days[i]['state'] == 'claimed' || (days[i]['state'] == 'today' && claimedToday)) ? _yellow : Colors.grey.shade300,
            ),
          ),
          if (i < days.length - 1)
            Expanded(child: Container(height: 4, color: days[i]['state'] == 'claimed' ? _yellow : Colors.grey.shade300)),
        ],
      ],
    );
  }

  Widget _todayCard(bool dark, bool enabled, bool claimed, bool poolEmpty, double amt, int day) {
    final ink = dark ? Colors.white : const Color(0xFF16123A);
    final canClaim = enabled && !claimed && !poolEmpty && amt > 0;
    String sub = 'You can claim it now!';
    if (!enabled) sub = 'Daily rewards are paused for now.';
    else if (claimed) sub = 'Claimed. Come back tomorrow!';
    else if (poolEmpty) sub = 'Today\'s rewards are finished. Try again tomorrow.';
    return _card(
      dark,
      Column(
        children: [
          Row(
            children: [
              Container(
                width: 92, height: 92,
                decoration: BoxDecoration(color: _yellow.withOpacity(0.18), shape: BoxShape.circle),
                child: Center(child: Container(width: 66, height: 66, decoration: const BoxDecoration(color: _yellow, shape: BoxShape.circle), child: const Center(child: Text('K', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900))))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today\'s Reward (Day $day)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(text: TextSpan(children: [
                      TextSpan(text: '+${_fmt(amt)} ', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: dark ? Colors.white : _deep)),
                      const TextSpan(text: 'Kaida Points', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _purple)),
                    ])),
                  ),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: canClaim && !_claiming ? _claim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellow,
                disabledBackgroundColor: dark ? Colors.white12 : const Color(0xFFE6E2F5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              ),
              child: _claiming
                  ? const KaidaButtonLoader(label: 'Claiming...', color: Color(0xFF1E1E2D))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(claimed ? Icons.check_circle_rounded : Icons.card_giftcard_rounded, color: canClaim ? const Color(0xFF1E1E2D) : Colors.grey.shade500),
                      const SizedBox(width: 10),
                      Text(claimed ? 'Reward claimed' : 'Claim Reward (+${_fmt(amt)} Points)', style: TextStyle(color: canClaim ? const Color(0xFF1E1E2D) : Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w900)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(bool dark, IconData icon, Color color, String label, String value, String sub) {
    final ink = dark ? Colors.white : const Color(0xFF16123A);
    return _card(
      dark,
      Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : _deep))),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            ]),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}