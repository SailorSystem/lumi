// c:\Users\User\CODIGOS\Lumi\lumi_app\lib\widgets\lumi_char.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LumiChar extends StatefulWidget {
  final double size;

  const LumiChar({super.key, this.size = 150});

  @override
  State<LumiChar> createState() => _LumiCharState();
}

class _LumiCharState extends State<LumiChar> {
  String? _response;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('https://example.com/data.json'),
      );
      setState(() => _response = response.body);
    } catch (e) {
      setState(() => _response = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Image.asset('assets/images/lumi_char.jpg', fit: BoxFit.contain),
    );
  }
}
