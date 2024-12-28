import 'package:flutter/material.dart';

class TrafficReportScreen extends StatefulWidget {
  @override
  _TrafficReportScreenState createState() => _TrafficReportScreenState();
}

class _TrafficReportScreenState extends State<TrafficReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _title;
  String? _description;
  String? _currentLocation = "Fetching location...";
  String? _priority = "Moderate";

  @override
  void initState() {
    super.initState();
    // Simulate fetching current location
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _currentLocation = "123 Main St, Springfield"; // Replace with actual location fetching logic
      });
    });
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Process the report data
      print("Report Submitted: ");
      print("Title: $_title");
      print("Description: $_description");
      print("Location: $_currentLocation");
      print("Priority: $_priority");

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Traffic report submitted successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Report Traffic Issue"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Title"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter a title";
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Description"),
                items: ["Accident", "Theft", "Road Block", "Default"]
                    .map((desc) => DropdownMenuItem(
                          value: desc,
                          child: Text(desc),
                        ))
                    .toList(),
                validator: (value) => value == null
                    ? "Please select a description"
                    : null,
                onChanged: (value) {
                  _description = value;
                },
              ),
              SizedBox(height: 16),
              Text("Location: $_currentLocation"),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Priority"),
                value: _priority,
                items: ["High", "Moderate", "Low"]
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _priority = value;
                  });
                },
              ),
              SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submitReport,
                  child: Text("Submit Report"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
