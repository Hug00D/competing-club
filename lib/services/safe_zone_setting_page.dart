import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafeZoneSettingPage extends StatefulWidget {
  final String careReceiverUid;

  const SafeZoneSettingPage({super.key, required this.careReceiverUid});

  @override
  State<SafeZoneSettingPage> createState() => _SafeZoneSettingPageState();
}

class _SafeZoneSettingPageState extends State<SafeZoneSettingPage> {
  GoogleMapController? _mapController;
  LatLng? _safeZoneCenter;
  double _safeZoneRadius = 300;
  bool _isLoading = true;

  // 半徑輸入框
  final TextEditingController _radiusController = TextEditingController();
  static const double _minRadius = 20;    // 可自行調整
  static const double _maxRadius = 3000;  // 可自行調整

  @override
  void initState() {
    super.initState();
    _loadSafeZoneFromFirestore();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSafeZoneFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.careReceiverUid)
          .get();

      final data = doc.data();
      if (data != null && data['safeZone'] != null) {
        final zone = data['safeZone'];
        if (mounted) {
          setState(() {
            _safeZoneCenter = LatLng(
              (zone['lat'] as num).toDouble(),
              (zone['lng'] as num).toDouble(),
            );
            _safeZoneRadius = (zone['radius'] as num?)?.toDouble() ?? 300.0;
            _radiusController.text = _safeZoneRadius.toStringAsFixed(0);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _safeZoneCenter = const LatLng(24.1777546, 120.6429611); // 台中（預設）
            _radiusController.text = _safeZoneRadius.toStringAsFixed(0);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 載入 safeZone 錯誤: $e');
      if (mounted) {
        setState(() {
          _safeZoneCenter = const LatLng(24.1777546, 120.6429611);
          _radiusController.text = _safeZoneRadius.toStringAsFixed(0);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSafeZone() async {
    if (_safeZoneCenter == null) return;

    // 用 set + merge 更安全（文件不存在也能寫）
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.careReceiverUid)
        .set({
      'safeZone': {
        'lat': _safeZoneCenter!.latitude,
        'lng': _safeZoneCenter!.longitude,
        'radius': _safeZoneRadius,
      }
    }, SetOptions(merge: true));

    if (!mounted) return;

    // 可選：成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已儲存安全範圍：${_safeZoneRadius.toStringAsFixed(0)} m')),
    );

    // 把最新 center/radius 帶回上一頁，方便即時更新
    Navigator.pop(context, {
      'updated': true,
      'center': {
        'lat': _safeZoneCenter!.latitude,
        'lng': _safeZoneCenter!.longitude,
      },
      'radius': _safeZoneRadius,
    });
  }

  // Haversine 公式：計算兩點距離（公尺）
  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double R = 6371000; // 地球半徑（公尺）
    final double lat1 = p1.latitude * (math.pi / 180);
    final double lat2 = p2.latitude * (math.pi / 180);
    final double dLat = (p2.latitude - p1.latitude) * (math.pi / 180);
    final double dLng = (p2.longitude - p1.longitude) * (math.pi / 180);

    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
            (math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // 設定半徑（含限制、同步輸入框）
  void _setRadius(double value, {bool syncText = true}) {
    final r = value.clamp(_minRadius, _maxRadius).toDouble();
    setState(() {
      _safeZoneRadius = r;
      if (syncText) {
        _radiusController.text = r.toStringAsFixed(0);
      }
    });
  }

  // 輸入框提交時套用
  void _applyRadiusFromInput() {
    final v = _radiusController.text.trim();
    final parsed = double.tryParse(v);
    if (parsed == null) {
      _radiusController.text = _safeZoneRadius.toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效的半徑數值')),
      );
      return;
    }
    _setRadius(parsed, syncText: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA),
      appBar: AppBar(
        title: const Text('設定安全範圍'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // 右上角快速完成（可選）
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '儲存並返回',
            onPressed: _saveSafeZone,
          ),
        ],
      ),
      body: _isLoading || _safeZoneCenter == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 地圖：點擊地圖邊界即可改變半徑；拖曳 Marker 可移動中心
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _safeZoneCenter!,
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (LatLng tappedPoint) {
                if (_safeZoneCenter != null) {
                  final newRadius =
                  _calculateDistanceMeters(_safeZoneCenter!, tappedPoint);
                  _setRadius(newRadius); // 同步輸入框
                }
              },
              markers: {
                Marker(
                  markerId: const MarkerId("safeZoneCenter"),
                  position: _safeZoneCenter!,
                  draggable: true,
                  onDragEnd: (newPos) {
                    setState(() => _safeZoneCenter = newPos);
                    // 拖曳完成後移動畫面，體驗更直覺
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(newPos),
                    );
                  },
                  infoWindow: const InfoWindow(title: '安全區中心'),
                )
              },
              circles: {
                Circle(
                  circleId: const CircleId('safeZone'),
                  center: _safeZoneCenter!,
                  radius: _safeZoneRadius,
                  fillColor: Colors.green.withAlpha(80),
                  strokeColor: Colors.green,
                  strokeWidth: 2,
                )
              },
            ),
          ),

          // 控制區：顯示目前半徑 + 可輸入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '安全範圍半徑：${_safeZoneRadius.toInt()} 公尺',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _radiusController,
                        style: const TextStyle(color: Colors.black),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: false,
                        ),
                        decoration: InputDecoration(
                          labelText: '輸入半徑（$_minRadius ~ $_maxRadius 公尺）',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.radar),
                        ),
                        onSubmitted: (_) => _applyRadiusFromInput(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _applyRadiusFromInput,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('套用'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _saveSafeZone,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存並返回'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
