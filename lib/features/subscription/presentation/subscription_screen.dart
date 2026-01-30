import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/revenue_cat_service.dart';

/// Example subscription/paywall screen using RevenueCat
/// This demonstrates how to display offerings and handle purchases
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadOfferings();
    await _loadCustomerInfo();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await RevenueCatService().getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load offerings: $e');
      }
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final customerInfo = await RevenueCatService().getCustomerInfo();
      if (mounted) {
        setState(() => _customerInfo = customerInfo);
      }
    } catch (e) {
      debugPrint('Error loading customer info: $e');
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    try {
      final customerInfo = await RevenueCatService().purchasePackage(package);
      setState(() => _isLoading = false);

      if (customerInfo != null && mounted) {
        _showSuccess('Purchase successful!');
        await _loadCustomerInfo();
        // Optionally navigate back or to premium features
        // Navigator.pop(context);
      } else if (mounted) {
        _showError('Purchase was cancelled or failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Purchase failed: $e');
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      final customerInfo = await RevenueCatService().restorePurchases();
      setState(() => _isLoading = false);

      if (mounted) {
        if (customerInfo != null && customerInfo.entitlements.active.isNotEmpty) {
          _showSuccess('Purchases restored successfully!');
          await _loadCustomerInfo();
        } else {
          _showError('No active subscriptions found');
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

  Widget _buildSubscriptionCard(Package package) {
    final product = package.storeProduct;
    final isSubscribed = _customerInfo?.entitlements.active.isNotEmpty ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: InkWell(
        onTap: isSubscribed ? null : () => _purchasePackage(package),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (isSubscribed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.priceString,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (!isSubscribed)
                    ElevatedButton(
                      onPressed: () => _purchasePackage(package),
                      child: const Text('Subscribe'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionInfo() {
    if (_customerInfo == null || _customerInfo!.entitlements.active.isEmpty) {
      return const SizedBox.shrink();
    }

    final entitlement = _customerInfo!.entitlements.active.values.first;
    final expirationDate = entitlement.expirationDate;
    final willRenew = entitlement.willRenew;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Active Subscription',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          if (expirationDate != null) ...[
            const SizedBox(height: 8),
            Text(
              willRenew
                  ? 'Renews on: ${_formatDate(expirationDate)}'
                  : 'Expires on: ${_formatDate(expirationDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
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
        title: const Text('Premium Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offerings?.current == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('No offerings available'),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Please configure your products in the RevenueCat dashboard',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOfferings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildActiveSubscriptionInfo(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _offerings!.current!.availablePackages.length,
                        itemBuilder: (context, index) {
                          final package =
                              _offerings!.current!.availablePackages[index];
                          return _buildSubscriptionCard(package);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: _restorePurchases,
                            child: const Text('Restore Purchases'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
