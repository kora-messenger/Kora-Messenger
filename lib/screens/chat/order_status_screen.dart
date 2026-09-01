import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

class OrderStatusScreen extends StatefulWidget {
  final String? orderId;
  final String? trackingUrl;

  const OrderStatusScreen({super.key, this.orderId, this.trackingUrl});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  int _currentStep = 2; // Ordered, Shipped, Out for delivery, Delivered
  final _steps = ['Order placed', 'Confirmed', 'Shipped', 'Out for delivery', 'Delivered'];
  final _stepIcons = [Icons.receipt_long, Icons.check_circle, Icons.local_shipping, Icons.delivery_dining, Icons.home];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: KoraColors.backgroundFor(b),
      appBar: AppBar(backgroundColor: KoraColors.backgroundFor(b),
        title: Text('Order status', style: TextStyle(color: KoraColors.textPrimaryFor(b))),
        iconTheme: IconThemeData(color: KoraColors.textPrimaryFor(b))),
      body: ListView(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
            borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order #${widget.orderId ?? 'KORA-2026-001'}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Estimated delivery: Sep 2, 2026',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
          ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: KoraColors.textPrimaryFor(b)))),
        const SizedBox(height: 8),
        ..._steps.asMap().entries.map((e) {
          final isDone = e.key <= _currentStep;
          final isCurrent = e.key == _currentStep;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Column(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isDone ? KoraColors.purple : KoraColors.cardFor(b),
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: KoraColors.purple, width: 3) : null),
                  child: Icon(_stepIcons[e.key], size: 18,
                    color: isDone ? Colors.white : KoraColors.textMutedFor(b))),
                if (e.key < _steps.length - 1)
                  Container(width: 2, height: 24, color: isDone ? KoraColors.purple : KoraColors.borderFor(b)),
              ]),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? KoraColors.textPrimaryFor(b) : KoraColors.textMutedFor(b))),
                if (isDone) Text(_getTime(e.key), style: TextStyle(fontSize: 12, color: KoraColors.textMutedFor(b))),
              ]),
            ]));
        }),
        const SizedBox(height: 24),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order tracking coming soon"), behavior: SnackBarBehavior.floating)); },
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text('Track on map', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: KoraColors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
            ),
          ])),
      ]),
    );
  }

  String _getTime(int step) {
    final times = ['Aug 29, 10:00 AM', 'Aug 29, 10:05 AM', 'Aug 30, 8:00 AM', '', ''];
    return times[step];
  }
}
