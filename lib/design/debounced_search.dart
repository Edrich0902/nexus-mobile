import 'dart:async';

import 'package:flutter/widgets.dart';

/// Debounced search box state shared by index and search pages.
mixin DebouncedSearch<T extends StatefulWidget> on State<T> {
  final searchController = TextEditingController();
  Timer? _debounce;
  String searched = '';

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && value.trim() != searched) setState(() => searched = value.trim());
    });
  }

  void submitSearch(String value) {
    _debounce?.cancel();
    setState(() => searched = value.trim());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }
}
