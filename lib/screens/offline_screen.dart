import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../components/modern_buttons.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isRetrying = false;

  Future<void> _retryConnection() async {
    setState(() => _isRetrying = true);
    
    try {
      await Future.delayed(const Duration(seconds: 1));
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/age-gate');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Still no internet connection. Please check your network settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to check connection. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Offline Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ).animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .then(delay: 200.ms)
                .shake(hz: 2, curve: Curves.easeInOut),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'No Internet Connection',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Please check your internet connection and try again. Make sure you\'re connected to Wi-Fi or mobile data.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 48),
              
              // Retry Button
              ModernButton(
                text: 'Retry Connection',
                onPressed: _isRetrying ? null : _retryConnection,
                isLoading: _isRetrying,
                isExpanded: true,
                icon: Icons.refresh,
              ).animate()
                .fadeIn(delay: 700.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 24),
              
              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connection Tips',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildTips(theme),
                  ],
                ),
              ).animate()
                .fadeIn(delay: 900.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTips(ThemeData theme) {
    final tips = [
      'Check if Wi-Fi is enabled',
      'Try switching between Wi-Fi and mobile data',
      'Move closer to your Wi-Fi router',
      'Restart your device if the problem persists',
    ];

    return tips.map((tip) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    )).toList();
  }
}