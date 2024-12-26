import 'package:location/location.dart';

class LocationService {
  Location location = Location();

  Future<LocationData?> getLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return null;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }

    return await location.getLocation();
  }

  Stream<LocationData> getLocationStream() {
    return location.onLocationChanged;
  }

  Future<bool> enableBackgroundMode(bool enable) async {
    return await location.enableBackgroundMode(enable: enable);
  }
}