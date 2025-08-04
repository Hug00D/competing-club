import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(home: NavHomePage()));
}

class NavHomePage extends StatefulWidget {
  @override
  State<NavHomePage> createState() => _NavHomePageState();
}

class _NavHomePageState extends State<NavHomePage> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  LatLng? _homePosition;
  String? _homeAddress;
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _steps = [];
  int _currentStepIdx = 0;
  FlutterTts tts = FlutterTts();
  StreamSubscription<Position>? _positionStream;
  String _navTip = "尚未開始導航";
  bool _firstUse = false;
  String googleMapsApiKey = "AIzaSyDipCLkhTxIZ2GVPSAoERZe_9SSXqNUzKA";

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _initPosition();
    await _checkFirstUseAndShowGuide();
    await _loadHomeAddress();
  }

  Future<void> _initPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });
  }

  Future<void> _checkFirstUseAndShowGuide() async {
    final prefs = await SharedPreferences.getInstance();
    _firstUse = prefs.getBool("first_use") ?? true;
    if (_firstUse) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showWelcomeDialog();
      });
    }
  }

  Future<void> _showWelcomeDialog() async {
    await tts.speak("歡迎使用回家地圖，請跟著指示設定您的住家位置。您可以輸入住家地址，或直接將目前位置設為住家。");
    String? address;
    TextEditingController ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("歡迎使用回家地圖"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("本 App 會協助您導航回家。\n請先設定住家位置："),
              SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: "請輸入住家地址",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),
              Text("或直接點下方按鈕設目前位置為住家"),
            ],
          ),
          actions: [
            TextButton(
              child: Text("設目前位置為住家"),
              onPressed: () async {
                await _selectHomePosition();
                final prefs = await SharedPreferences.getInstance();
                prefs.setBool("first_use", false);
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("以地址設定"),
              onPressed: () async {
                address = ctrl.text.trim();
                if (address != null && address!.isNotEmpty) {
                  await _saveHomeAddress(address!);
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setBool("first_use", false);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadHomeAddress() async {
    final prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('home_address');
    if (address != null) {
      setState(() => _homeAddress = address);
      await _getHomeLatLng(address);
    }
  }

  Future<void> _saveHomeAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_address', address);
    setState(() => _homeAddress = address);
    await _getHomeLatLng(address);
    await tts.speak("住家地址已設定完成，您可以按下導航回家。");
  }

  Future<void> _selectHomePosition() async {
    if (_currentPosition == null) return;
    setState(() {
      _homePosition = _currentPosition;
      _homeAddress = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('home_address');
    await tts.speak("已將目前位置設定為住家。您可以按下導航回家。");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已設定目前為住家位置")));
  }

  Future<void> _getHomeLatLng(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _homePosition = LatLng(locations[0].latitude, locations[0].longitude);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('地址轉換座標失敗，請確認輸入正確地址')),
      );
      await tts.speak("地址設定失敗，請再檢查地址是否正確。");
    }
  }

  Future<void> _startNavigation() async {
    if (_currentPosition == null || _homePosition == null) return;
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${_homePosition!.latitude},${_homePosition!.longitude}&mode=walking&language=zh-TW&key=$googleMapsApiKey';
    final res = await http.get(Uri.parse(url));
    final data = json.decode(res.body);
    print(data);  // 看回傳內容

    if (data['routes'] == null || data['routes'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('找不到路線')));
      await tts.speak("找不到路線，請確認地址設定。");
      return;
    }

    final steps = data['routes'][0]['legs'][0]['steps'] as List;
    List<LatLng> polylinePoints = [];
    List<Map<String, dynamic>> parsedSteps = [];
    for (var step in steps) {
      var start = step['start_location'];
      var end = step['end_location'];
      polylinePoints.add(LatLng(start['lat'], start['lng']));
      polylinePoints.add(LatLng(end['lat'], end['lng']));
      parsedSteps.add({
        'lat': end['lat'],
        'lng': end['lng'],
        'html_instructions': step['html_instructions'],
        'distance': step['distance']['text'],
        'instruction': _parseHtml(step['html_instructions']),
      });
    }
    setState(() {
      _routePoints = polylinePoints;
      _steps = parsedSteps;
      _currentStepIdx = 0;
    });
    _navTip = _steps[0]['instruction'] + "，" + _steps[0]['distance'];
    await tts.speak(_navTip);

    // 開始持續追蹤定位，自動導航提示
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(_handlePositionUpdate);
  }

  void _handlePositionUpdate(Position pos) async {
    if (_steps.isEmpty) return;
    final target = LatLng(_steps[_currentStepIdx]['lat'], _steps[_currentStepIdx]['lng']);
    final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, target.latitude, target.longitude);

    if (distance < 25 && _currentStepIdx < _steps.length - 1) {
      _currentStepIdx++;
      _navTip = _steps[_currentStepIdx]['instruction'] + "，" + _steps[_currentStepIdx]['distance'];
      setState(() {});
      await tts.speak(_navTip);
    } else if (_currentStepIdx == _steps.length - 1 && distance < 15) {
      _navTip = "已抵達住家！";
      setState(() {});
      await tts.speak(_navTip);
      _positionStream?.cancel();
    }
  }

  String _parseHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("回家地圖", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: _showWelcomeDialog,
            tooltip: '重新設定住家',
          ),
        ],
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 16,
            ),
            onMapCreated: (controller) => mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              Marker(
                markerId: MarkerId("current"),
                position: _currentPosition!,
                infoWindow: InfoWindow(title: "我的位置"),
              ),
              if (_homePosition != null)
                Marker(
                  markerId: MarkerId("home"),
                  position: _homePosition!,
                  infoWindow: InfoWindow(title: "住家"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                ),
            },
            polylines: _routePoints.isNotEmpty
                ? {
              Polyline(
                polylineId: PolylineId("route"),
                color: Colors.blue,
                width: 8,
                points: _routePoints,
              )
            }
                : {},
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withOpacity(0.9),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation, color: Colors.blue, size: 36),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _navTip,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (_homePosition == null)
          ? null
          : FloatingActionButton.extended(
        label: Text("導航回家", style: TextStyle(fontSize: 20)),
        icon: Icon(Icons.directions_walk),
        onPressed: _startNavigation,
      ),
    );
  }
}