import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/revenue_cat_service.dart';

/// Customer Center for managing subscriptions
/// Provides users with a native UI to view and manage their subscription
class CustomerCenterScreen extends StatefulWidget {
  const CustomerCenterScreen({super.key});

  @override
  State<CustomerCenterScreen> createState() => _CustomerCenterScreenState();
}

class _CustomerCenterScreenState extends State<CustomerCenterScreen> {
  bool _isLoading = true;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    setState(() => _isLoading = true);
    try {
      final customerInfo = await RevenueCatService().getCustomerInfo();
      if (mounted) {
        setState(() {
          _customerInfo = customerInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load subscription info: $e');
      }
    }
  }

  /// Present RevenueCat's native Customer Center
  Future<void> _presentCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Reload customer info after dismissing customer center
      await _loadCustomerInfo();
    } catch (e) {
      if (mounted) {
        _showError('Failed to open Customer Center: $e');
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      final customerInfo = await RevenueCatService().restorePurchases();
      setState(() {
        _customerInfo = customerInfo;
        _isLoading = false;
      });

      if (mounted) {
        if (customerInfo != null && customerInfo.entitlements.active.isNotEmpty) {
          _showSuccess('Purchases restored successfully!');
        } else {
          _showError('No purchases to restore');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to restore purchases: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomerInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubscriptionStatus(),
                  const SizedBox(height: 24),
                  _buildManagementOptions(),
                  const SizedBox(height: 24),
                  _buildEntitlementsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionStatus() {
    final hasActiveSubscription =
        _customerInfo?.entitlements.active.isNotEmpty ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasActiveSubscription
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: hasActiveSubscription ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActiveSubscription
                            ? 'Cue Pro Active'
                            : 'Free Plan',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActiveSubscription
                            ? 'You have access to all premium features'
                            : 'Upgrade to unlock premium features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasActiveSubscription) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildSubscriptionDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails() {
    if (_customerInfo?.entitlements.active.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    final entitlement = _customerInfo!.entitlements.active.values.first;
    final expirationDate = entitlement.expirationDate;
    final willRenew = entitlement.willRenew;
    final periodType = entitlement.periodType;

    return Column(
      children: [
        _buildDetailRow(
          label: 'Status',
          value: willRenew ? 'Active' : 'Expiring Soon',
          valueColor: willRenew ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 8),
        if (expirationDate != null)
          _buildDetailRow(
            label: willRenew ? 'Renews on' : 'Expires on',
            value: _formatDate(expirationDate),
          ),
        const SizedBox(height: 8),
        _buildDetailRow(
          label: 'Plan Type',
          value: _getPeriodTypeLabel(periodType),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _getPeriodTypeLabel(PeriodType periodType) {
    switch (periodType) {
      case PeriodType.normal:
        return 'Regular';
      case PeriodType.intro:
        return 'Intro Offer';
      case PeriodType.trial:
        return 'Free Trial';
      default:
        return 'Active';
    }
  }

  Widget _buildManagementOptions() {
    final hasActiveSubscription =
        _customerInfo?.entitlements.active.isNotEmpty ?? false;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Manage Subscription'),
            subtitle: const Text('View details, cancel, or change plan'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _presentCustomerCenter,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Purchases'),
            subtitle: const Text('Recover purchases from another device'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _restorePurchases,
          ),
          if (!hasActiveSubscription) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.star, color: Theme.of(context).primaryColor),
              title: const Text('Upgrade to Cue Pro'),
              subtitle: const Text('Unlock all premium features'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, '/paywall');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntitlementsSection() {
    final entitlements = _customerInfo?.entitlements.all ?? {};

    if (entitlements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Entitlements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: entitlements.entries.map((entry) {
              final entitlement = entry.value;
              return ListTile(
                leading: Icon(
                  entitlement.isActive
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: entitlement.isActive ? Colors.green : Colors.grey,
                ),
                title: Text(entry.key),
                subtitle: Text(
                  entitlement.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: entitlement.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                trailing: entitlement.isActive
                    ? Text(
                        entitlement.willRenew ? 'Renews' : 'Expires',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Widget for embedding Customer Center button in other screens
class CustomerCenterButton extends StatelessWidget {
  const CustomerCenterButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.manage_accounts),
      tooltip: 'Manage Subscription',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerCenterScreen(),
          ),
        );
      },
    );
  }
}
