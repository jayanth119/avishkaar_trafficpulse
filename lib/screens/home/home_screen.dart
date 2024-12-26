import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location location = Location();
  LocationData? _currentLocation;
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  LatLng? _sourceLatLng;
  LatLng? _destinationLatLng;
  bool _isFetchingRoute = false;

  List<String> _sourceSuggestions = [];
  List<String> _destinationSuggestions = [];

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
      _sourceLatLng = LatLng(locationData.latitude!, locationData.longitude!);
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
    if (_sourceLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both source and destination.")),
      );
      return;
    }

    setState(() {
      _isFetchingRoute = true;
    });

    final Uri url = Uri.parse(
        "https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${_sourceLatLng!.latitude},${_sourceLatLng!.longitude};${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}");

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

  Widget _buildSuggestionsList(
      List<String> suggestions, TextEditingController controller, Function(String) onSelected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            title: Text(suggestion),
            onTap: () async {
              final LatLng? coordinates = await _getCoordinatesFromPlace(suggestion);
              if (coordinates != null) {
                setState(() {
                  controller.text = suggestion;
                  onSelected(suggestion);
                  suggestions.clear();
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
    );
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
                  initialCenter: _sourceLatLng ?? const LatLng(0, 0),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      if (_sourceLatLng != null)
                        Marker(
                          point: _sourceLatLng!,
                          child:  const Icon(Icons.location_pin, color: Colors.red, size: 40),
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
            const Center(child: CircularProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _sourceController,
                  decoration: const InputDecoration(
                    labelText: "Enter source location",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) async {
                    final suggestions = await _getPlaceSuggestions(query);
                    setState(() {
                      _sourceSuggestions = suggestions;
                    });
                  },
                ),
                const SizedBox(height: 8.0),
                if (_sourceSuggestions.isNotEmpty)
                  _buildSuggestionsList(
                    _sourceSuggestions,
                    _sourceController,
                    (value) async {
                      _sourceLatLng = await _getCoordinatesFromPlace(value);
                    },
                  ),
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: "Enter destination location",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) async {
                    final suggestions = await _getPlaceSuggestions(query);
                    setState(() {
                      _destinationSuggestions = suggestions;
                    });
                  },
                ),
                const SizedBox(height: 8.0),
                if (_destinationSuggestions.isNotEmpty)
                  _buildSuggestionsList(
                    _destinationSuggestions,
                    _destinationController,
                    (value) async {
                      _destinationLatLng = await _getCoordinatesFromPlace(value);
                    },
                  ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _isFetchingRoute ? null : _fetchRoute,
                  child: Text(_isFetchingRoute ? "Fetching Route..." : "Show Route"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
