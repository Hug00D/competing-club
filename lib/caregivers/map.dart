import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memory/services/safe_zone_setting_page.dart';

class NavHomePage extends StatefulWidget {
  final String careReceiverUid;

  const NavHomePage({super.key, required this.careReceiverUid});

  @override
  State<NavHomePage> createState() => _NavHomePageState();
}

class _NavHomePageState extends State<NavHomePage> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _careReceiverPosition;
  LatLng? _safeZoneCenter;
  double _safeZoneRadius = 300;

  @override
  void initState() {
    super.initState();
    debugPrint('🧭 careReceiverUid: ${widget.careReceiverUid}');
    _init();
  }

  Future<void> _init() async {
    await _initCurrentPosition();
    await _loadCareReceiverLocation();
    await _loadSafeZone();
  }

  Future<void> _initCurrentPosition() async {
    debugPrint('📍 開始取得目前位置');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ 定位服務未啟用');
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ 使用者拒絕定位權限');
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition();
    debugPrint('✅ 拿到目前位置: ${pos.latitude}, ${pos.longitude}');
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });

    _tryMoveToCareReceiver();
  }

  Future<void> _loadCareReceiverLocation() async {
    debugPrint('🚀 開始載入被照顧者位置');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.careReceiverUid)
          .get();

      final data = doc.data();
      debugPrint('📍 Firebase 拿到資料: $data');

      if (data != null && data['location'] != null) {
        final lat = data['location']['lat'];
        final lng = data['location']['lng'];
        setState(() {
          _careReceiverPosition = LatLng(lat, lng);
        });

        _tryMoveToCareReceiver();
      }
    } catch (e, stack) {
      debugPrint('🔥 載入被照顧者位置錯誤: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _loadSafeZone() async {
    debugPrint('🟢 載入 safeZone 資料...');
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.careReceiverUid);
      final doc = await docRef.get();
      final data = doc.data();

      if (data != null && data['safeZone'] != null) {
        final zone = data['safeZone'];
        setState(() {
          _safeZoneCenter = LatLng(zone['lat'], zone['lng']);
          _safeZoneRadius = (zone['radius'] ?? 300).toDouble();
        });
      } else {
        // ⛳ 自動補上預設值
        const defaultLat = 24.1777546;
        const defaultLng = 120.6429611;
        const defaultRadius = 300.0;

        await docRef.update({
          'safeZone': {
            'lat': defaultLat,
            'lng': defaultLng,
            'radius': defaultRadius,
          }
        });

        setState(() {
          _safeZoneCenter = const LatLng(defaultLat, defaultLng);
          _safeZoneRadius = defaultRadius;
        });

        debugPrint('🟢 SafeZone 不存在，自動補上預設值');
      }
    } catch (e) {
      debugPrint('❌ 載入 safeZone 失敗: $e');
    }
  }


  void _tryMoveToCareReceiver() {
    if (_mapController != null && _careReceiverPosition != null) {
      debugPrint('📌 移動鏡頭到被照顧者位置');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_careReceiverPosition!, 16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "被照顧者位置",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定安全範圍',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SafeZoneSettingPage(
                      careReceiverUid: widget.careReceiverUid,
                    ),
                  ),
                );

                if (result == 'updated') {
                  // 使用者有儲存，重新載入 safeZone
                  await _loadCareReceiverLocation(); // 如果你將 safeZone 存在 user 裡，可寫成 _loadSafeZone()
                  _tryMoveToCareReceiver(); // 更新地圖鏡頭
                  setState(() {}); // 重新 render
                }
              }
          )
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition!,
          zoom: 16,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          _tryMoveToCareReceiver();
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: {
          Marker(
            markerId: const MarkerId("current"),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: "我的位置"),
          ),
          if (_careReceiverPosition != null)
            Marker(
              markerId: const MarkerId("careReceiver"),
              position: _careReceiverPosition!,
              infoWindow: const InfoWindow(title: "被照顧者"),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
        },
        circles: _safeZoneCenter == null
            ? {}
            : {
          Circle(
            circleId: const CircleId("safeZone"),
            center: _safeZoneCenter!,
            radius: _safeZoneRadius,
            fillColor: Colors.green.withAlpha(80),
            strokeColor: Colors.green,
            strokeWidth: 2,
          ),
        },
      ),
    );
  }
}
