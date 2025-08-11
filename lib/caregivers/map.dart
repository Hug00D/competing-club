import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memory/services/safe_zone_setting_page.dart';
import 'dart:math' as math;

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

  void _applySafeZoneFromResult(Map r) async {
    final centerMap = r['center'] as Map;
    final LatLng newCenter = LatLng(
      (centerMap['lat'] as num).toDouble(),
      (centerMap['lng'] as num).toDouble(),
    );
    final double newRadius = (r['radius'] as num).toDouble();

    setState(() {
      _safeZoneCenter = newCenter;
      _safeZoneRadius = newRadius;
    });

    // 把鏡頭移到新的安全區中心（initialCameraPosition 不會自動改）
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newCenter, 16),
    );
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
    final bool hasSafeZone = _safeZoneCenter != null && _safeZoneRadius > 0;
    final bool isInside = hasSafeZone && _careReceiverPosition != null
        ? _distanceMeters(_careReceiverPosition!, _safeZoneCenter!) <= _safeZoneRadius
        : false;

    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA), // 柔綠背景
      appBar: AppBar(
        title: const Text(
          "被照顧者位置",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF28965A), // 深綠
        foregroundColor: Colors.white,
        elevation: 2,
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

              if (!mounted) return;

              if (result is Map && result['updated'] == true) {
                _applySafeZoneFromResult(result);   // ✅ 直接用回傳數值更新+移動相機
              } else if (result == 'updated') {
                // 備案：如果設定頁只回傳字串，就重新讀一次 Firestore
                await _loadSafeZone();
                if (!mounted) return;
                setState(() {});
                if (_safeZoneCenter != null) {
                  await _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_safeZoneCenter!, 16),
                  );
                }
              }
            },

          )
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            key: ValueKey('${_safeZoneCenter?.latitude},${_safeZoneCenter?.longitude},$_safeZoneRadius'),
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
              // 我的位置（藍）
              Marker(
                markerId: const MarkerId("current"),
                position: _currentPosition!,
                infoWindow: const InfoWindow(title: "我的位置"),
              ),
              // 被照顧者（主綠）
              if (_careReceiverPosition != null)
                Marker(
                  markerId: const MarkerId("careReceiver"),
                  position: _careReceiverPosition!,
                  infoWindow: const InfoWindow(title: "被照顧者"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
            },
            circles: !hasSafeZone
                ? {}
                : {
              Circle(
                circleId: const CircleId("safeZone"),
                center: _safeZoneCenter!,
                radius: _safeZoneRadius,
                fillColor: const Color(0xFF2CEAA3).withAlpha(48), // 柔綠填充
                strokeColor: const Color(0xFF28965A),            // 深綠外框
                strokeWidth: 2,
              ),
            },
          ),

          // 右上：資訊小卡（半徑）
          if (hasSafeZone)
            Positioned(
              top: 12,
              right: 12,
              child: _infoChip(
                icon: Icons.radar,
                text: '半徑 ${_safeZoneRadius.toStringAsFixed(0)} m',
              ),
            ),

          // 左上：狀態小卡（是否在安全範圍內）
          if (hasSafeZone && _careReceiverPosition != null)
            Positioned(
              top: 12,
              left: 12,
              child: _infoChip(
                icon: isInside ? Icons.check_circle : Icons.error_outline,
                text: isInside ? '範圍內' : '已超出',
                color: isInside ? const Color(0xFF28965A) : const Color(0xFFFF6670),
              ),
            ),
        ],
      ),
    );
  }

// 小工具：統一資訊貼片樣式（白底+冷綠邊框）
  Widget _infoChip({required IconData icon, required String text, Color color = const Color(0xFF28965A)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

// 距離（公尺）：若你在別處已實作可沿用
  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }
}
