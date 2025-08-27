import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/models.dart';
import 'processing_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Livestream livestream;
  
  const DetailScreen({required this.livestream});
  
  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titelController = TextEditingController();
  // Use a controller for the preacher field to allow typing
  final _predigerController = TextEditingController();
  // This list will hold the suggestions for the Autocomplete field
  final List<String> _predigerList = ['Philipp Hönes'];
  DateTime _selectedDate = DateTime.now();


    
  
  @override
  void initState() {
    super.initState();
    _initializeFormFields();
  }

  void _initializeFormFields() {
    final parts = widget.livestream.title.split('|');
    if (parts.isNotEmpty) {
      print(parts[0]);
      _titelController.text = parts[0].trim();
    }
    if (parts.length >= 2) {
      final preacherName = parts[1].trim();
      if (!_predigerList.contains(preacherName)) {
        _predigerList.add(preacherName);
      }
      _predigerController.text = preacherName;
      print(preacherName);
    }
    if (parts.length >= 3) {
      try {
        final dateString = parts[2].trim();
        final regExp = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})');
        final match = regExp.firstMatch(dateString);

        if (match != null) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          _selectedDate = DateTime(year < 100 ? year + 2000 : year, month, day);
        }
      } catch (e) {
        print('Error parsing date from title: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
  final themes = AsyncValue.data(<String>[]);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predigt Details'),
        actions: [
          IconButton(
            onPressed: _processAudio,
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Verarbeiten',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Titel Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.livestream.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Länge: ${(widget.livestream.length / 60000).toStringAsFixed(1)} min'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Predigt Titel
              themes.when(
                data: (themesList) => Autocomplete<String>(
                  initialValue: TextEditingValue(text: _titelController.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return themesList.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _titelController.text = selection;
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    _titelController.value = textEditingController.value;
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Predigt Titel',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Bitte Titel eingeben' : null,
                    );
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => TextFormField(
                  controller: _titelController,
                  decoration: const InputDecoration(
                    labelText: 'Predigt Titel',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Bitte Titel eingeben' : null,
                ),
              ),

              
              
              const SizedBox(height: 16),
              
              // Prediger Auswahl with Autocomplete
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _predigerController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _predigerList.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _predigerController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Sync our controller when the user types
                  _predigerController.value = textEditingController.value;
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Prediger',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty == true ? 'Bitte Prediger eingeben' : null,
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Kalender
              TableCalendar(
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2030),
                focusedDay: _selectedDate,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() => _selectedDate = selectedDay);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _titelController.dispose();
    _predigerController.dispose();
    super.dispose();
  }

  Future<void> _processAudio() async {
    if (!_formKey.currentState!.validate()) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          livestream: widget.livestream,
          prediger: _predigerController.text,
          titel: _titelController.text,
          datum: _selectedDate,
        ),
      ),
    );
  }
}