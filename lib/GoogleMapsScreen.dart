import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, asin;

class EnhancedGoogleMapsScreen extends StatefulWidget {
  @override
  _EnhancedGoogleMapsScreenState createState() =>
      _EnhancedGoogleMapsScreenState();
}

class _EnhancedGoogleMapsScreenState extends State<EnhancedGoogleMapsScreen>
    with TickerProviderStateMixin {
  GoogleMapController? mapController;
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Set<Marker> markers = {};
  List<dynamic> autocompleteSuggestions = [];
  bool isSearching = false;
  Timer? debounceTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? selectedPlaceDetails;

  static const String apiKey = 'AIzaSyB_BCq0oZsuBcUYWs_yS2RlRaKTJL2-5XM';

  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(40.7128, -74.0060),
    zoom: 14.0,
  );

  bool darkMode = false;

  // For route calculation
  LatLng? _locationA;
  LatLng? _locationB;
  String? _addressA;
  String? _addressB;
  double? _distanceMeters;
  List<LatLng> _routePoints = [];
  Polyline? _routePolyline;

  // For custom location selection with tap
  bool _selectingLocation = false;
  bool _selectingForA = true; // If false, next tap is for B

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (darkMode) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(_lightMapStyle);
    }
  }

  Future<void> getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        autocompleteSuggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&types=establishment|geocode';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          autocompleteSuggestions = data['predictions'] ?? [];
          isSearching = false;
        });
      } else {
        setState(() {
          isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        isSearching = false;
      });
    }
  }

  Future<void> getPlaceDetails(
    String placeId, {
    bool setA = false,
    bool setB = false,
  }) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,geometry,formatted_address,rating,photos,types,review,user_ratings_total,website,opening_hours,reviews&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final place = data['result'];
        if (setA) {
          _setLocationA(
            LatLng(
              place['geometry']['location']['lat'],
              place['geometry']['location']['lng'],
            ),
            place['formatted_address'] ?? place['name'],
          );
        } else if (setB) {
          _setLocationB(
            LatLng(
              place['geometry']['location']['lat'],
              place['geometry']['location']['lng'],
            ),
            place['formatted_address'] ?? place['name'],
          );
        } else {
          selectPlace(place);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading place details'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void selectPlace(dynamic place) {
    final lat = place['geometry']['location']['lat'];
    final lng = place['geometry']['location']['lng'];
    final name = place['name'];
    final address = place['formatted_address'] ?? '';
    final rating = place['rating']?.toString() ?? '';

    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: MarkerId(place['place_id'] ?? UniqueKey().toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: rating.isNotEmpty ? '⭐ $rating | $address' : address,
            onTap: () {
              showPlaceDetails(place);
            },
          ),
          onTap: () {
            showPlaceDetails(place);
          },
        ),
      );
      autocompleteSuggestions = [];
      searchFocusNode.unfocus();
      selectedPlaceDetails = place;
    });

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
      );
    }
    showPlaceDetails(place);
  }

  void showPlaceDetails(dynamic place) {
    setState(() {
      selectedPlaceDetails = place;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassmorphicSheet(place),
    );
  }

  String _getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photoreference=$photoReference&key=$apiKey';
  }

  Widget _buildGlassmorphicSheet(dynamic place) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          gradient: LinearGradient(
            colors: darkMode
                ? [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.4)]
                : [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.6),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 40,
              spreadRadius: 0,
              offset: Offset(0, -16),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: darkMode
              ? ImageFilter.blur(sigmaX: 16, sigmaY: 16)
              : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: _buildPlaceDetailSheet(place),
        ),
      ),
    );
  }

  Widget _buildPlaceDetailSheet(dynamic place) {
    final name = place['name'] ?? '';
    final address = place['formatted_address'] ?? '';
    final rating = place['rating']?.toString() ?? '';
    final totalRatings = place['user_ratings_total']?.toString() ?? '';
    final photos = place['photos'] as List<dynamic>? ?? [];
    final website = place['website'] ?? '';
    final reviews = place['reviews'] as List<dynamic>? ?? [];
    final openingHours =
        place['opening_hours']?['weekday_text'] as List<dynamic>?;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.48,
        minChildSize: 0.22,
        maxChildSize: 0.92,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Images (carousel if multiple)
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      itemCount: photos.length,
                      controller: PageController(viewportFraction: 0.88),
                      itemBuilder: (context, index) {
                        final photoRef = photos[index]['photo_reference'];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: darkMode
                                    ? Colors.black54
                                    : Colors.grey.withOpacity(0.14),
                                blurRadius: 22,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(
                              _getPhotoUrl(photoRef, maxWidth: 900),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : Center(child: CircularProgressIndicator()),
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 18),

                Text(
                  name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: darkMode ? Colors.white : Colors.grey[900],
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: darkMode ? Colors.black45 : Colors.white54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    if (rating.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 22,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '$rating',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: darkMode
                                  ? Colors.amber[300]
                                  : Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    if (totalRatings.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Text(
                        '($totalRatings reviews)',
                        style: TextStyle(
                          fontSize: 14,
                          color: darkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: darkMode ? Colors.blue[200] : Colors.blue[400],
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          fontSize: 15,
                          color: darkMode ? Colors.grey[200] : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                if (website.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 18,
                        color: darkMode ? Colors.blue[200] : Colors.blue[400],
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: InkWell(
                          onTap: () async {
                            if (await canLaunchUrl(Uri.parse(website))) {
                              await launchUrl(
                                Uri.parse(website),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Text(
                            website,
                            style: TextStyle(
                              color: darkMode
                                  ? Colors.blue[100]
                                  : Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 8),
                if (openingHours != null && openingHours.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opening Hours:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkMode ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      ...openingHours.map(
                        (e) => Text(
                          e,
                          style: TextStyle(
                            color: darkMode
                                ? Colors.grey[200]
                                : Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                if (reviews.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text(
                    'Top Reviews',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: darkMode ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 5),
                  ...reviews.take(3).map((rev) => _buildReviewItem(rev)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(dynamic review) {
    final authorName = review['author_name'] ?? '';
    final rating = review['rating']?.toString() ?? '';
    final text = review['text'] ?? '';
    final timeDesc = review['relative_time_description'] ?? '';
    final profilePhoto = review['profile_photo_url'];

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: darkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey[50]?.withOpacity(0.70),
        boxShadow: [
          BoxShadow(
            color: darkMode ? Colors.black26 : Colors.grey[200]!,
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profilePhoto != null)
            CircleAvatar(
              backgroundImage: NetworkImage(profilePhoto),
              radius: 19,
            ),
          if (profilePhoto == null)
            CircleAvatar(child: Icon(Icons.person), radius: 19),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: darkMode ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    if (rating.isNotEmpty) ...[
                      SizedBox(width: 6),
                      Icon(Icons.star, color: Colors.amber, size: 15),
                      Text(
                        rating,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: darkMode
                              ? Colors.amber[300]
                              : Colors.amber[900],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  timeDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: darkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: darkMode ? Colors.grey[100] : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: darkMode
              ? [Color(0xff232526), Color(0xff414345)]
              : [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: darkMode
                ? Colors.black.withOpacity(0.30)
                : Colors.blue.withOpacity(0.12),
            blurRadius: 30,
            offset: Offset(0, 10),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: darkMode ? Colors.white : Colors.grey[800],
                      shadows: [
                        Shadow(
                          blurRadius: 7,
                          color: darkMode ? Colors.black26 : Colors.white30,
                        ),
                      ],
                    ),
                    decoration: InputDecoration(
                      hintText: 'Where do you want to go?',
                      hintStyle: TextStyle(
                        color: darkMode ? Colors.grey[400] : Colors.grey[400],
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Container(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.search_rounded,
                          color: darkMode ? Colors.blue[100] : Colors.blue[600],
                          size: 24,
                        ),
                      ),
                      suffixIcon: isSearching
                          ? Container(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    darkMode
                                        ? Colors.blue[100]!
                                        : Colors.blue[600]!,
                                  ),
                                ),
                              ),
                            )
                          : searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey[400],
                              ),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  autocompleteSuggestions = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (value) {
                      debounceTimer?.cancel();
                      debounceTimer = Timer(Duration(milliseconds: 300), () {
                        if (value == searchController.text) {
                          getAutocompleteSuggestions(value);
                        }
                      });
                    },
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 250),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: IconButton(
                    key: ValueKey(darkMode),
                    tooltip: darkMode
                        ? "Switch to Light Mode"
                        : "Switch to Dark Mode",
                    icon: Icon(
                      darkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: darkMode ? Colors.yellow[300] : Colors.blue[600],
                    ),
                    onPressed: () {
                      setState(() {
                        darkMode = !darkMode;
                        if (mapController != null) {
                          mapController!.setMapStyle(
                            darkMode ? _darkMapStyle : _lightMapStyle,
                          );
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectingLocation = true;
                      _selectingForA = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tap on map to select Location A'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _markerLocationTile(
                      title: 'Loc A',
                      subtitle: _addressA,
                      selected: _locationA != null,
                      darkMode: darkMode,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectingLocation = true;
                      _selectingForA = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tap on map to select Location B'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _markerLocationTile(
                      title: 'Loc B',
                      subtitle: _addressB,
                      selected: _locationB != null,
                      darkMode: darkMode,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.route_rounded,
                  color: (_locationA != null && _locationB != null)
                      ? (darkMode ? Colors.tealAccent[100] : Colors.blue)
                      : Colors.grey,
                ),
                tooltip: 'Show Route',
                onPressed: (_locationA != null && _locationB != null)
                    ? () => _showRoute()
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.clear, color: Colors.redAccent),
                tooltip: 'Clear Route',
                onPressed: _clearRoute,
              ),
            ],
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              maxHeight: autocompleteSuggestions.isNotEmpty ? 300 : 0,
            ),
            child: autocompleteSuggestions.isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: darkMode
                              ? Colors.grey[900]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: autocompleteSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = autocompleteSuggestions[index];
                        return _buildSuggestionItem(suggestion, index);
                      },
                    ),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }

  Widget _markerLocationTile({
    required String title,
    String? subtitle,
    required bool selected,
    required bool darkMode,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: selected
            ? (darkMode ? Colors.teal[900]!.withOpacity(0.6) : Colors.blue[50])
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? (darkMode ? Colors.tealAccent : Colors.blueAccent)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(
            title == 'Location A'
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected
                ? (darkMode ? Colors.tealAccent[100] : Colors.blue[700])
                : (darkMode ? Colors.white30 : Colors.grey[400]),
          ),
          SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: selected
                  ? (darkMode ? Colors.tealAccent[100] : Colors.blue[900])
                  : (darkMode ? Colors.white70 : Colors.grey[800]),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: darkMode ? Colors.tealAccent[100] : Colors.blue[900],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(dynamic suggestion, int index) {
    final mainText = suggestion['structured_formatting']['main_text'] ?? '';
    final secondaryText =
        suggestion['structured_formatting']['secondary_text'] ?? '';
    final types = suggestion['types'] as List<dynamic>? ?? [];

    IconData iconData = Icons.place_rounded;
    Color iconColor = darkMode ? Colors.tealAccent[200]! : Colors.red[400]!;

    if (types.contains('establishment')) {
      iconData = Icons.store_rounded;
      iconColor = darkMode ? Colors.orange[200]! : Colors.orange[400]!;
    } else if (types.contains('route')) {
      iconData = Icons.route_rounded;
      iconColor = darkMode ? Colors.blue[200]! : Colors.blue[400]!;
    }

    return InkWell(
      onTap: () {
        searchController.text = mainText;
        // By default, not used for A/B, but could do that by adding a mode
        getPlaceDetails(suggestion['place_id']);
      },
      onLongPress: () {
        // Long press to choose as A or B
        showModalBottomSheet(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.looks_one_rounded, color: Colors.blue),
                  title: Text('Set as Location A'),
                  onTap: () {
                    Navigator.pop(context);
                    getPlaceDetails(suggestion['place_id'], setA: true);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.looks_two_rounded, color: Colors.green),
                  title: Text('Set as Location B'),
                  onTap: () {
                    Navigator.pop(context);
                    getPlaceDetails(suggestion['place_id'], setB: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          border: index < autocompleteSuggestions.length - 1
              ? Border(
                  bottom: BorderSide(
                    color: darkMode ? Colors.grey[800]! : Colors.grey[100]!,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.09),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(iconData, color: iconColor, size: 21),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: darkMode ? Colors.white : Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondaryText.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: TextStyle(
                        fontSize: 14,
                        color: darkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_outward_rounded,
              color: darkMode ? Colors.blue[200] : Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _setLocationA(LatLng latLng, String address) {
    setState(() {
      _locationA = latLng;
      _addressA = address;
      markers.removeWhere(
        (m) => m.markerId.value == 'A' || m.markerId.value == 'B',
      );
      markers.add(
        Marker(
          markerId: MarkerId('A'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: "Location A", snippet: address),
          draggable: true,
          onDragEnd: (newPos) {
            _setLocationA(newPos, address);
          },
        ),
      );
    });
    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    }
  }

  void _setLocationB(LatLng latLng, String address) {
    setState(() {
      _locationB = latLng;
      _addressB = address;
      markers.removeWhere(
        (m) => m.markerId.value == 'A' || m.markerId.value == 'B',
      );
      if (_locationA != null) {
        markers.add(
          Marker(
            markerId: MarkerId('A'),
            position: _locationA!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: "Location A",
              snippet: _addressA ?? "",
            ),
          ),
        );
      }
      markers.add(
        Marker(
          markerId: MarkerId('B'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: "Location B", snippet: address),
          draggable: true,
          onDragEnd: (newPos) {
            _setLocationB(newPos, address);
          },
        ),
      );
    });
    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    }
  }

  Future<void> _showRoute() async {
    if (_locationA == null || _locationB == null) return;
    // Use Google Directions API for best results
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_locationA!.latitude},${_locationA!.longitude}&destination=${_locationB!.latitude},${_locationB!.longitude}&mode=driving&key=$apiKey";
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data['status'] == 'OK') {
      final points = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(points);
      setState(() {
        _routePoints = polylinePoints;
        _routePolyline = Polyline(
          polylineId: PolylineId("route"),
          points: polylinePoints,
          color: darkMode ? Colors.tealAccent : Colors.blue,
          width: 7,
        );
        _distanceMeters = data['routes'][0]['legs'][0]['distance']['value']
            .toDouble();
      });
      // Zoom to fit both markers
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(_locationA!.latitude, _locationB!.latitude),
          min(_locationA!.longitude, _locationB!.longitude),
        ),
        northeast: LatLng(
          max(_locationA!.latitude, _locationB!.latitude),
          max(_locationA!.longitude, _locationB!.longitude),
        ),
      );
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      // Show a result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Distance: ${(_distanceMeters! / 1000).toStringAsFixed(2)} km",
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to get route. Try again later.")),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _locationA = null;
      _locationB = null;
      _addressA = null;
      _addressB = null;
      _routePoints.clear();
      _routePolyline = null;
      _distanceMeters = null;
      markers.removeWhere(
        (m) => m.markerId.value == 'A' || m.markerId.value == 'B',
      );
    });
  }

  List<LatLng> _decodePolyline(String poly) {
    var list = poly.codeUnits;
    var lList = new List<double>.empty(growable: true);

    int index = 0;
    int len = poly.length;
    int c = 0;
    // repeating until all attributes are decoded
    do {
      var shift = 0;
      int result = 0;

      // for decoding value of latitude and longitude
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      var delta = ((result & 1) == 1 ? ~(result >> 1) : (result >> 1));
      lList.add(delta.toDouble());
    } while (index < len);

    List<LatLng> positions = [];
    double lat = 0;
    double lng = 0;

    for (int i = 0; i < lList.length; i++) {
      if (i % 2 == 0) {
        lat += (lList[i] / 1E5);
      } else {
        lng += (lList[i] / 1E5);
        positions.add(LatLng(lat, lng));
      }
    }
    return positions;
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;

  Future<String?> _getAddressFromLatLng(LatLng position) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].length > 0) {
        return data['results'][0]['formatted_address'];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = darkMode ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: darkMode ? Color(0xff181a1b) : Colors.grey[50],
        primaryColor: darkMode ? Colors.blueGrey[900] : Colors.blue[600],
        colorScheme: theme.colorScheme.copyWith(
          secondary: darkMode ? Colors.blueGrey[700]! : Colors.blue[600]!,
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Google Map with custom styling
            ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: darkMode
                          ? Colors.black.withOpacity(0.55)
                          : Colors.blue.withOpacity(0.08),
                      blurRadius: 47,
                      spreadRadius: 0,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: GoogleMap(
                  onMapCreated: onMapCreated,
                  initialCameraPosition: initialPosition,
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  tiltGesturesEnabled: true,
                  polylines: _routePolyline != null ? {_routePolyline!} : {},
                  onTap: (LatLng latLng) async {
                    if (_selectingLocation) {
                      final address = await _getAddressFromLatLng(latLng);
                      if (_selectingForA) {
                        _setLocationA(latLng, address ?? latLng.toString());
                      } else {
                        _setLocationB(latLng, address ?? latLng.toString());
                      }
                      setState(() {
                        _selectingLocation = false;
                      });
                    }
                  },
                ),
              ),
            ),

            // 3D Glassy Floating Buttons
            Positioned(
              bottom: 25,
              right: 21,
              child: Column(
                children: [
                  _GlassButton(
                    icon: Icons.my_location_rounded,
                    tooltip: "Go to Initial Location",
                    darkMode: darkMode,
                    onTap: () {
                      if (mapController != null) {
                        mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            initialPosition.target,
                            14.0,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 18),
                  _GlassButton(
                    icon: Icons.add_rounded,
                    tooltip: "Zoom In",
                    darkMode: darkMode,
                    onTap: () {
                      if (mapController != null) {
                        mapController!.animateCamera(CameraUpdate.zoomIn());
                      }
                    },
                  ),
                  SizedBox(height: 18),
                  _GlassButton(
                    icon: Icons.remove_rounded,
                    tooltip: "Zoom Out",
                    darkMode: darkMode,
                    onTap: () {
                      if (mapController != null) {
                        mapController!.animateCamera(CameraUpdate.zoomOut());
                      }
                    },
                  ),
                ],
              ),
            ),

            // Enhanced search bar
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top - 60,
              left: 0,
              right: 0,
              child: _buildSearchBar(),
            ),

            // Gradient overlay at the top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: darkMode
                          ? [Colors.black.withOpacity(0.55), Colors.transparent]
                          : [Colors.blue.withOpacity(0.19), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const String _lightMapStyle = '''
  [
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9e9e9"},{"lightness":17}]},
    {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f5"},{"lightness":20}]}
  ]
  ''';

  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
    {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [{"color": "#1b1b1b"}]},
    {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
    {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
    {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f2f2f"}]},
    {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
  ]
  ''';
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final bool darkMode;
  final VoidCallback onTap;
  const _GlassButton({
    required this.icon,
    this.tooltip,
    required this.darkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 0,
      child: Tooltip(
        message: tooltip ?? "",
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: darkMode
                      ? Colors.black.withOpacity(0.36)
                      : Colors.grey.withOpacity(0.16),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: darkMode
                    ? [
                        Colors.blueGrey[900]!.withOpacity(0.78),
                        Colors.blueGrey[700]!.withOpacity(0.49),
                      ]
                    : [
                        Colors.white.withOpacity(0.85),
                        Colors.blue[50]!.withOpacity(0.73),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: darkMode
                    ? Colors.blueGrey[800]!.withOpacity(0.35)
                    : Colors.blue[100]!.withOpacity(0.14),
                width: 1.2,
              ),
            ),
            width: 52,
            height: 52,
            child: Center(
              child: Icon(
                icon,
                color: darkMode ? Colors.tealAccent[100] : Colors.blue[600],
                size: 28,
                shadows: [
                  Shadow(
                    color: darkMode ? Colors.black54 : Colors.blue[100]!,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
