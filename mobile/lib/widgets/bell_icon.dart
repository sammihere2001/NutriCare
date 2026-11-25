import 'package:flutter/material.dart';
import 'package:nutricare/services/notification_service.dart';
import '../theme/colors.dart';

class BellIcon extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const BellIcon({super.key, required this.scaffoldKey});

  @override
  State<BellIcon> createState() => _BellIconState();
}

class _BellIconState extends State<BellIcon> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    print("Unread count loaded: $count"); // Debug print
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  // Call this method when notification panel is closed
  void refreshCount() {
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.textPrimary, size: 24),
          onPressed: () {
            widget.scaffoldKey.currentState?.openEndDrawer();
            // Refresh count after panel closes
            Future.delayed(const Duration(milliseconds: 500), () {
              _loadUnreadCount();
            });
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
