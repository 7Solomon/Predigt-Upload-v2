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
  String _selectedPrediger = 'Philipp Hönes';
  DateTime _selectedDate = DateTime.now();
  
  @override
  Widget build(BuildContext context) {
  // Placeholder: list of themes
  final themes = AsyncValue.data(<String>["Gnade", "Glaube", "Hoffnung"]);
    
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
                data: (themesList) => DropdownButtonFormField<String>(
                  value: _titelController.text.isEmpty ? null : _titelController.text,
                  decoration: const InputDecoration(
                    labelText: 'Predigt Titel',
                    border: OutlineInputBorder(),
                  ),
                  items: themesList.map((theme) => DropdownMenuItem(
                    value: theme,
                    child: Text(theme),
                  )).toList(),
                  onChanged: (value) => _titelController.text = value ?? '',
                  validator: (value) => value?.isEmpty == true ? 'Bitte Titel eingeben' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => TextFormField(
                  controller: _titelController,
                  decoration: const InputDecoration(
                    labelText: 'Predigt Titel',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Prediger Auswahl
              DropdownButtonFormField<String>(
                value: _selectedPrediger,
                items: const [
                  DropdownMenuItem(value: 'Philipp Hönes', child: Text('Philipp Hönes')),
                  // DropdownMenuItem(value: 'Max Mustermann', child: Text('Max Mustermann')),
                ],
                onChanged: (v) => setState(() => _selectedPrediger = v ?? _selectedPrediger),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Prediger'),
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
  
  Future<void> _processAudio() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Navigate to Processing Screen with parameters
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcessingScreen(
          livestream: widget.livestream,
          prediger: _selectedPrediger,
          titel: _titelController.text,
          datum: _selectedDate,
        ),
      ),
    );
  }
}