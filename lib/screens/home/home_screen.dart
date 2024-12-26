import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location location = Location();
  LocationData? _currentLocation;
  TextEditingController _destinationController = TextEditingController();
  LatLng? _destinationLatLng;
  bool _isFetchingRoute = false;

  // Add this line to declare _placeSuggestions
  List<String> _placeSuggestions = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData locationData = await location.getLocation();
    setState(() {
      _currentLocation = locationData;
    });
  }

  Future<List<String>> _getPlaceSuggestions(String query) async {
    final Uri url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> places = json.decode(response.body);
      return places.map((place) => place["display_name"] as String).toList();
    } else {
      return [];
    }
  }

  Future<LatLng?> _getCoordinatesFromPlace(String placeName) async {
    final Uri url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$placeName&format=json&addressdetails=1");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> places = json.decode(response.body);
      if (places.isNotEmpty) {
        final double lat = double.parse(places[0]["lat"]);
        final double lon = double.parse(places[0]["lon"]);
        return LatLng(lat, lon);
      }
    }

    return null;
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destinationLatLng == null) return;

    setState(() {
      _isFetchingRoute = true;
    });

    // Open a URL for routing
    final Uri url = Uri.parse(
        "https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${_currentLocation!.latitude},${_currentLocation!.longitude};${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open routing service.")),
      );
    }

    setState(() {
      _isFetchingRoute = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Traffic Route Finder"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => AppSettings.openAppSettings(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentLocation != null)
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                      if (_destinationLatLng != null)
                        Marker(
                          point: _destinationLatLng!,
                          child: const Icon(Icons.flag, color: Colors.blue, size: 40),
                        ),
                    ],
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: "Enter destination",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) async {
                    final suggestions = await _getPlaceSuggestions(query);
                    setState(() {
                      _placeSuggestions = suggestions;
                    });
                  },
                ),
                const SizedBox(height: 8.0),
                if (_placeSuggestions.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _placeSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _placeSuggestions[index];
                        return ListTile(
                          title: Text(suggestion),
                          onTap: () async {
                            final LatLng? coordinates = await _getCoordinatesFromPlace(suggestion);
                            if (coordinates != null) {
                              setState(() {
                                _destinationController.text = suggestion;
                                _destinationLatLng = coordinates;
                                _placeSuggestions.clear();
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Unable to fetch coordinates for the selected location."),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_destinationLatLng != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isFetchingRoute ? null : _fetchRoute,
                child: Text(_isFetchingRoute ? "Fetching Route..." : "Show Route"),
              ),
            ),
        ],
      ),
    );
  }
}
