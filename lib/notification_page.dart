import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Irrigation Complete',
      'message': 'Field 3 irrigation cycle completed successfully.',
      'time': '10:45 AM',
      'read': false,
    },
    {
      'title': 'Low Soil Moisture',
      'message': 'Soil moisture dropped below 25% in Zone 2.',
      'time': '9:15 AM',
      'read': true,
    },
    {
      'title': 'New Finance Report',
      'message': 'Weekly finance summary is ready to review.',
      'time': 'Yesterday',
      'read': true,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['read'] = true;
      }
    });
  }

  void _deleteNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D3A5C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: _notifications.isEmpty
            ? const Center(
                child: Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return Dismissible(
                    key: ValueKey(notification['title'] + index.toString()),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteNotification(index),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Card(
                      color: notification['read']
                          ? Colors.white.withOpacity(0.85)
                          : Colors.lightBlue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading: Icon(
                          notification['read']
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: const Color(0xFF0D3A5C),
                          size: 30,
                        ),
                        title: Text(
                          notification['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D3A5C),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['message']),
                            const SizedBox(height: 4),
                            Text(
                              notification['time'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          tooltip: 'Mark as read',
                          onPressed: () {
                            setState(() {
                              notification['read'] = true;
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
