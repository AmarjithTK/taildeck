import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/url_utils.dart';
import '../../../data/models/probe_status.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../common/status_dot.dart';

/// `Test Connection` tile — `docs/UI_SPEC.md` §4.5.
///
/// Deliberately tests the **unsaved** text in the URL field, so a typo is
/// caught before it is committed.
class TestConnectionTile extends ConsumerStatefulWidget {
  const TestConnectionTile({super.key, required this.url});

  final String url;

  @override
  ConsumerState<TestConnectionTile> createState() => _TestConnectionTileState();
}

class _TestConnectionTileState extends ConsumerState<TestConnectionTile> {
  ProbeStatus? _result;
  bool _running = false;

  Future<void> _test() async {
    final parsed = parseServiceUrl(widget.url);
    if (parsed is! UrlParseOk) {
      setState(() {
        _running = false;
        _result = ProbeStatus.offline(
          error: parsed is UrlParseFailure
              ? parsed.message
              : 'Invalid address',
          checkedAt: DateTime.now(),
        );
      });
      return;
    }

    setState(() {
      _running = true;
      _result = null;
    });
    final result = await ref.read(probeServiceProvider).probe(parsed.uri);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    final (ProbeDotState dot, String title, String subtitle) = _running
        ? (
            ProbeDotState.checking,
            'Testing\u2026',
            'Connecting to ${displayHostOf(widget.url)}',
          )
        : result == null
        ? (ProbeDotState.unknown, 'Not tested', 'Tap Test to check reachability')
        : result.isOnline
        ? (
            ProbeDotState.online,
            'Reachable',
            result.needsAuth
                ? 'HTTP ${result.httpStatus} \u2014 the service is up but wants credentials'
                : 'Response time: ${result.latencyMs} ms'
                      '${result.httpStatus != null && result.httpStatus != 200 ? ' \u00B7 HTTP ${result.httpStatus}' : ''}',
          )
        : (
            ProbeDotState.offline,
            'Unreachable',
            result.error ?? 'Unknown error',
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StatusDot(state: dot, size: 9),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: result?.isOffline == true
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _running ? null : _test,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Test', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
