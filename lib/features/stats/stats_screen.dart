// c:\Users\User\CODIGOS\Lumi\lumi_app\lib\features\stats\stats_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late SharedPreferences _prefs;
  List<String> _data = [];
  String _selectedValue = '';

  @override
  void initState() {
    super.initState();
    _prefs = await SharedPreferences.getInstance();
    _data = _prefs.getStringList('data') ?? [];
    _selectedValue = _prefs.getString('selectedValue') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Selected Value: $_selectedValue'),
            ElevatedButton(
              onPressed: () {
                _prefs.setString('selectedValue', _selectedValue);
              },
              child: const Text('Save'),
            ),
            Text('Data: $_data'),
            ElevatedButton(
              onPressed: () {
                _prefs.setStringList('data', _data);
              },
              child: const Text('Save Data'),
            ),
          ],
        ),
      ),
    );
  }
}