import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EnterprisePdfExtractor(),
    );
  }
}

class EnterprisePdfExtractor extends StatefulWidget {
  const EnterprisePdfExtractor({super.key});

  @override
  State<EnterprisePdfExtractor> createState() => _EnterprisePdfExtractorState();
}

class _EnterprisePdfExtractorState extends State<EnterprisePdfExtractor> {
  bool isLoading = false;
  Map<String, String> dbData = {};

  // =========================
  // TEXT PREPROCESSING
  // =========================
  String preprocess(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  // =========================
  // SMART NUMBER EXTRACTOR
  // =========================
  String extractNumberNear(String text, String label) {
    int index = text.toLowerCase().indexOf(label.toLowerCase());
    if (index == -1) return "0";

    int end = (index + 250 < text.length) ? index + 250 : text.length;
    String snippet = text.substring(index, end);

    RegExp numberRegex = RegExp(r'\d+(\.\d+)?');
    Match? match = numberRegex.firstMatch(snippet);

    return match?.group(0) ?? "0";
  }

  // =========================
  // TEXT VALUE EXTRACTOR
  // =========================
  String extractTextNear(String text, String label) {
    int index = text.toLowerCase().indexOf(label.toLowerCase());
    if (index == -1) return "";

    int start = index + label.length;
    int end = (start + 150 < text.length) ? start + 150 : text.length;

    return text.substring(start, end).trim();
  }

  // =========================
  // ENTERPRISE BUILDER
  // =========================
  Map<String, String> buildFullDb(String rawText) {
    String text = preprocess(rawText);

    int totalFaculty = RegExp(r'Faculty Unique ID').allMatches(text).length;

    int totalStudents =
        int.tryParse(extractNumberNear(text, "Total Students")) ?? 0;

    int intake = int.tryParse(extractNumberNear(text, "Approved Intake")) ?? 0;

    int classrooms = int.tryParse(extractNumberNear(text, "Classrooms")) ?? 0;

    int labs = int.tryParse(extractNumberNear(text, "Lab")) ?? 0;

    double infra = double.tryParse(extractNumberNear(text, "Area")) ?? 0;

    double budget = double.tryParse(extractNumberNear(text, "Budget")) ?? 0;

    double ratio = totalFaculty > 0 ? totalStudents / totalFaculty : 0;

    int requiredFaculty = (intake / 20).ceil();

    bool facultyOk = totalFaculty >= requiredFaculty;
    bool infraOk = infra > 0;
    bool intakeOk = intake > 0;
    bool docsOk = text.isNotEmpty;

    int totalChecks = 4;
    int passed = [facultyOk, infraOk, intakeOk, docsOk].where((e) => e).length;

    int failed = totalChecks - passed;

    double compliance = (passed / totalChecks) * 100;

    return {
      "id": "AUTO",
      "institution_name": extractTextNear(text, "Institution Name"),
      "institution_code": "AUTO_GEN",
      "registration_number": extractTextNear(text, "Registration"),
      "affiliated_university": extractTextNear(text, "Affiliated"),
      "state": extractTextNear(text, "State"),
      "district": extractTextNear(text, "District"),
      "contact_email": extractTextNear(text, "Email"),
      "contact_phone": extractNumberNear(text, "Phone"),
      "uploaded_pdf": "UPLOADED",
      "extracted_text": "Stored (truncated)",

      "total_faculty": totalFaculty.toString(),
      "total_students": totalStudents.toString(),
      "approved_student_intake": intake.toString(),
      "total_classrooms": classrooms.toString(),
      "total_labs": labs.toString(),
      "infrastructure_area_sqft": infra.toString(),
      "total_courses_offered": extractNumberNear(text, "Course"),
      "annual_budget": budget.toString(),
      "financial_audit_status": extractTextNear(text, "Audit"),
      "previous_year_approval_status": extractTextNear(text, "Status"),

      "student_faculty_ratio": ratio.toStringAsFixed(2),
      "required_min_faculty": requiredFaculty.toString(),
      "faculty_compliance": facultyOk.toString(),
      "infrastructure_compliance": infraOk.toString(),
      "intake_compliance": intakeOk.toString(),
      "document_completeness": docsOk.toString(),

      "total_checks": totalChecks.toString(),
      "checks_passed": passed.toString(),
      "checks_failed": failed.toString(),
      "compliance_percentage": compliance.toStringAsFixed(2),

      "risk_level": compliance > 80 ? "Low" : "Medium",
      "approval_probability": compliance.toStringAsFixed(2),
      "predicted_decision": compliance > 75 ? "Approve" : "Conditional",
      "risk_factors": facultyOk ? "Minor" : "Faculty Deficit",
      "improvement_suggestions": facultyOk
          ? "Maintain compliance"
          : "Increase faculty",

      "is_reviewed": "False",
      "reviewed_by": "",
      "created_at": DateTime.now().toString(),
      "updated_at": DateTime.now().toString(),
    };
  }

  // =========================
  // PDF PICKER
  // =========================
  Future<void> pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null) return;

    setState(() => isLoading = true);

    Uint8List bytes = result.files.single.bytes!;

    PdfDocument document = PdfDocument(inputBytes: bytes);

    String fullText = "";
    for (int i = 0; i < document.pages.count; i++) {
      fullText += PdfTextExtractor(
        document,
      ).extractText(startPageIndex: i, endPageIndex: i);
    }

    document.dispose();

    setState(() {
      dbData = buildFullDb(fullText);
      isLoading = false;
    });
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enterprise PDF Extraction Engine")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(onPressed: pickPdf, child: const Text("Upload PDF")),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator(),
            if (dbData.isNotEmpty)
              Expanded(
                child: ListView(
                  children: dbData.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () {
                                    print(dbData);
                                  },
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(flex: 3, child: Text(e.value)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
