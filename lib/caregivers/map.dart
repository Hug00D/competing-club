import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavHomePage extends StatefulWidget {
  final String careReceiverUid;

  const NavHomePage({super.key, required this.careReceiverUid});

  @override
  State<NavHomePage> createState() => _NavHomePageState();
}

class _NavHomePageState extends State<NavHomePage> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  LatLng? _careReceiverPosition;

  @override
  void initState() {
    super.initState();
    debugPrint('🧭 careReceiverUid: ${widget.careReceiverUid}');
    _init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _init() async {
    await _initPosition();
    await _loadCareReceiverLocation();
  }

  Future<void> _initPosition() async {
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
  }


  Future<void> _loadCareReceiverLocation() async {
    debugPrint('🚀 開始載入被照顧者位置');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.careReceiverUid)
          .get();

      debugPrint('✅ 是否存在: ${doc.exists}');
      debugPrint('📍 Firebase 拿到位置資料: ${doc.data()}');

      final data = doc.data();
      if (data != null && data['location'] != null) {
        final lat = data['location']['lat'];
        final lng = data['location']['lng'];
        setState(() {
          _careReceiverPosition = LatLng(lat, lng);
        });

        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_careReceiverPosition!, 16),
        );
      }
    } catch (e, stack) {
      debugPrint('🔥 載入被照顧者位置錯誤: $e');
      debugPrint(stack.toString());
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
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition!,
          zoom: 16,
        ),
        onMapCreated: (controller) => mapController = controller,
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
                  BitmapDescriptor.hueBlue),
            ),
        },
      ),
    );
  }
}
