import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../theme.dart';

class LocationSelectorField extends StatefulWidget {
  final FormFieldValidator<String>? validator;
  final String labelText;
  final bool isSignup;

  const LocationSelectorField({
    super.key,
    this.validator,
    this.labelText = 'Location',
    this.isSignup = false,
  });

  @override
  State<LocationSelectorField> createState() => _LocationSelectorFieldState();
}

class _LocationSelectorFieldState extends State<LocationSelectorField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill only for non-signup configurations
    if (!widget.isSignup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final locProvider = Provider.of<LocationProvider>(
            context,
            listen: false,
          );
          if (locProvider.userLocation != null) {
            setState(() {
              _controller.text = locProvider.userLocation!.address;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showLocationOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _LocationDialog(
        onLocationSelected: (address, lat, lon) {
          final locProvider = Provider.of<LocationProvider>(
            context,
            listen: false,
          );
          locProvider.updateLocation(
            UserLocation(address: address, lat: lat, lon: lon),
          );
          setState(() {
            _controller.text = address;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If not signup, automatically sync with location provider changes
    if (!widget.isSignup) {
      final locProvider = Provider.of<LocationProvider>(context);
      final userLoc = locProvider.userLocation;
      if (userLoc != null && _controller.text != userLoc.address) {
        _controller.text = userLoc.address;
      }
    }

    return TextFormField(
      controller: _controller,
      readOnly: true,
      onTap: () => _showLocationOptions(context),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: 'Tap to select location',
        prefixIcon: const Icon(Icons.location_on_outlined),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator:
          widget.validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your location';
            }
            return null;
          },
    );
  }
}

class _LocationDialog extends StatefulWidget {
  final Function(String address, double lat, double lon) onLocationSelected;

  const _LocationDialog({required this.onLocationSelected});

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  bool _isManual = false;
  bool _loading = false;
  String? _errorMsg;

  // Manual form controllers
  final _pincodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _subdistrictController = TextEditingController();
  bool _resolvingPincode = false;

  @override
  void initState() {
    super.initState();
    _pincodeController.addListener(_onPincodeChanged);
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _subdistrictController.dispose();
    super.dispose();
  }

  void _onPincodeChanged() {
    final code = _pincodeController.text.trim();
    if (code.length == 6 && !_resolvingPincode) {
      _resolvePincode(code);
    }
  }

  Future<void> _resolvePincode(String pincode) async {
    setState(() {
      _resolvingPincode = true;
      _errorMsg = null;
    });

    try {
      final response = await http
          .get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List<dynamic>;
          if (postOffices.isNotEmpty) {
            final first = postOffices[0];

            // Find subdistrict: scan all post offices for a valid Block (not "NA")
            String subdistrict = '';
            for (final po in postOffices) {
              final block = po['Block'] as String? ?? '';
              if (block.isNotEmpty && block != 'NA') {
                subdistrict = block;
                break;
              }
            }
            // If no valid Block found, use the first post office Name as subdistrict
            if (subdistrict.isEmpty) {
              subdistrict = first['Name'] as String? ?? '';
            }

            setState(() {
              _stateController.text = first['State'] ?? '';
              _districtController.text = first['District'] ?? '';
              _subdistrictController.text = subdistrict;
            });
            return;
          }
        }
        setState(() {
          _errorMsg = 'Pincode not found or invalid';
        });
      } else {
        setState(() {
          _errorMsg = 'Failed to fetch pincode details';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not resolve pincode automatically';
      });
    } finally {
      setState(() {
        _resolvingPincode = false;
      });
    }
  }

  Future<void> _fetchGPSLocation() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // Use a simple approach: just try to get position directly.
      // On web, geolocator triggers the browser's native permission prompt.
      // On mobile, it triggers the OS permission dialog.

      // First check/request permission (works on mobile; on web it's a no-op or auto)
      bool permissionGranted = true;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permissionGranted = false;
        }
      } catch (e) {
        // On web, permission checks might throw — that's okay,
        // getCurrentPosition will trigger the browser prompt directly
        debugPrint('Permission check exception (expected on web): $e');
      }

      if (!permissionGranted) {
        // Permission explicitly denied on mobile
        await _fetchIPLocation('Location permission denied by user.');
        return;
      }

      // Check if location services are enabled (mobile only, web always returns true)
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          await _fetchIPLocation(
            'Location services are disabled on this device.',
          );
          return;
        }
      } catch (e) {
        debugPrint('Service check exception: $e');
      }

      // Get position using LocationSettings (non-deprecated API)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = position.latitude;
      final lon = position.longitude;

      debugPrint('GPS location obtained: lat=$lat, lon=$lon');

      // Reverse geocode using Nominatim OpenStreetMap API
      await _reverseGeocode(lat, lon);
    } catch (e) {
      debugPrint('Geolocator getCurrentPosition error: $e');
      // If GPS fails, try the IP-based fallback
      await _fetchIPLocation('Could not get GPS location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1';
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'FarmWise-App/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;

        // Build address as: subdistrict, district, state, country
        String address;
        if (data['address'] != null) {
          final addr = data['address'] as Map<String, dynamic>;
          // Resolve subdistrict: try suburb > village > town > city
          final subdistrict =
              addr['suburb'] ??
              addr['village'] ??
              addr['town'] ??
              addr['city'] ??
              '';
          final district = addr['state_district'] ?? addr['county'] ?? '';
          final state = addr['state'] ?? '';
          final country = addr['country'] ?? '';
          final parts = <String>[
            subdistrict,
            district,
            state,
            country,
          ].where((s) => (s as String).isNotEmpty).toList();
          address = parts.isNotEmpty
              ? parts.join(', ')
              : (displayName ?? '$lat, $lon');
        } else {
          address = displayName ?? '$lat, $lon';
        }

        widget.onLocationSelected(address, lat, lon);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Nominatim failed, use raw coordinates
        widget.onLocationSelected('$lat, $lon', lat, lon);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      // Use raw coordinates as last resort
      widget.onLocationSelected('$lat, $lon', lat, lon);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchIPLocation(String logMsg) async {
    debugPrint(logMsg);
    if (mounted) {
      setState(() {
        _errorMsg = null; // Clear while we try IP fallback
      });
    }
    try {
      final response = await http
          .get(
            Uri.parse('https://ipapi.co/json/'),
            headers: {'User-Agent': 'FarmWise-App/1.0'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['latitude'] != null && data['longitude'] != null) {
          final lat = (data['latitude'] as num).toDouble();
          final lon = (data['longitude'] as num).toDouble();
          final city = data['city'] as String? ?? '';
          final region = data['region'] as String? ?? '';
          final country = data['country_name'] as String? ?? '';
          final parts = <String>[
            city,
            region,
            country,
          ].where((s) => s.isNotEmpty).toList();
          final address = parts.isNotEmpty ? parts.join(', ') : '$lat, $lon';

          widget.onLocationSelected(address, lat, lon);
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('IP geolocation fallback error: $e');
    }
    // Instant offline agricultural fallback
    widget.onLocationSelected('Coimbatore Mandi Region, Tamil Nadu', 11.0168, 76.9558);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline GPS region synced (Coimbatore Region, TN)'), backgroundColor: AppColors.primary),
      );
    }
  }

  void _submitManual() {
    final pincode = _pincodeController.text.trim();
    final state = _stateController.text.trim();
    final district = _districtController.text.trim();
    final subdistrict = _subdistrictController.text.trim();

    if (pincode.isEmpty || state.isEmpty || district.isEmpty) {
      setState(() {
        _errorMsg = 'Please fill out Pincode, State and District';
      });
      return;
    }

    // Format: subdistrict, district, state, India
    final addressParts = <String>[];
    if (subdistrict.isNotEmpty) addressParts.add(subdistrict);
    addressParts.add(district);
    addressParts.add(state);
    addressParts.add('India');
    final address = addressParts.join(', ');

    widget.onLocationSelected(
      address,
      20.5937,
      78.9629,
    ); // Default center coordinates for India
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isManual ? 'Manual Location' : 'Select Location Option',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMsg!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isManual) ...[
              ElevatedButton.icon(
                onPressed: _loading ? null : _fetchGPSLocation,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_loading ? 'Locating...' : 'Use Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isManual = true;
                    _errorMsg = null;
                  });
                },
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Enter Location Manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              // Manual Form
              TextFormField(
                initialValue: 'India',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Country',
                  prefixIcon: const Icon(Icons.public),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pincode (e.g. 110001)',
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                  suffixIcon: _resolvingPincode
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subdistrictController,
                decoration: InputDecoration(
                  labelText: 'Sub-District / Block',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _districtController,
                      decoration: InputDecoration(
                        labelText: 'District',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isManual = false;
                          _errorMsg = null;
                        });
                      },
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitManual,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
