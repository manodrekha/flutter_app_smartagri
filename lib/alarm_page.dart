import 'package:flutter/material.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  final List<Map<String, dynamic>> _alarms = [];

  final TextEditingController _titleController = TextEditingController();
  TimeOfDay? _selectedTime;

  // Pick a time for the alarm
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Add a new alarm entry
  void _addAlarm() {
    if (_titleController.text.isNotEmpty && _selectedTime != null) {
      setState(() {
        _alarms.add({
          'title': _titleController.text,
          'time': _selectedTime,
          'enabled': true,
        });
      });
      _titleController.clear();
      _selectedTime = null;
      Navigator.pop(context);
    }
  }

  // Delete an alarm
  void _deleteAlarm(int index) {
    setState(() {
      _alarms.removeAt(index);
    });
  }

  // Toggle alarm state
  void _toggleAlarm(int index) {
    setState(() {
      _alarms[index]['enabled'] = !_alarms[index]['enabled'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alarms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D3A5C),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAlarmDialog,
        backgroundColor: const Color(0xFF0D3A5C),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: _alarms.isEmpty
            ? const Center(
                child: Text(
                  'No alarms set yet',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alarms.length,
                itemBuilder: (context, index) {
                  final alarm = _alarms[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        alarm['enabled']
                            ? Icons.alarm_on
                            : Icons.alarm_off,
                        color: alarm['enabled']
                            ? Colors.green
                            : Colors.grey,
                        size: 30,
                      ),
                      title: Text(
                        alarm['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${alarm['time'].hour.toString().padLeft(2, '0')}:${alarm['time'].minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: alarm['enabled'],
                            onChanged: (_) => _toggleAlarm(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAlarm(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // --- Dialog to add alarm ---
  void _showAddAlarmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Alarm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Alarm Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTime == null
                        ? 'No time selected'
                        : 'Time: ${_selectedTime!.format(context)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.access_time, color: Color(0xFF0D3A5C)),
                  onPressed: _pickTime,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addAlarm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D3A5C),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
