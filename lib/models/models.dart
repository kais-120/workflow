// lib/models/worker_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String id;
  final String name;
  final String role;       // "Electrician" | "Technician" | "Helper"
  final double dailyRate;  // DT/day
  final String? currentJobId;
  final bool isActive;
  final DateTime createdAt;

  WorkerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.dailyRate,
    this.currentJobId,
    this.isActive = true,
    required this.createdAt,
  });

  factory WorkerModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WorkerModel(
      id:           doc.id,
      name:         d['name']         ?? '',
      role:         d['role']         ?? '',
      dailyRate:    (d['dailyRate']   ?? 0).toDouble(),
      currentJobId: d['currentJobId'],
      isActive:     d['isActive']     ?? true,
      createdAt:    (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':         name,
    'role':         role,
    'dailyRate':    dailyRate,
    'currentJobId': currentJobId,
    'isActive':     isActive,
    'createdAt':    Timestamp.fromDate(createdAt),
  };
}

// ─────────────────────────────────────────────
// lib/models/client_model.dart

class ClientModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.createdAt,
  });

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id:        doc.id,
      name:      d['name']    ?? '',
      address:   d['address'] ?? '',
      phone:     d['phone']   ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'address':   address,
    'phone':     phone,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ─────────────────────────────────────────────
// lib/models/job_model.dart

enum JobStatus { active, completed, paused }

class JobModel {
  final String id;
  final String title;
  final String clientId;
  final String clientName;
  final String address;
  final JobStatus status;
  final double budget;
  final int totalDays;
  final int currentDay;
  final List<String> workerIds;
  final DateTime startDate;
  final DateTime? endDate;

  JobModel({
    required this.id,
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.address,
    required this.status,
    required this.budget,
    required this.totalDays,
    required this.currentDay,
    required this.workerIds,
    required this.startDate,
    this.endDate,
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JobModel(
      id:          doc.id,
      title:       d['title']       ?? '',
      clientId:    d['clientId']    ?? '',
      clientName:  d['clientName']  ?? '',
      address:     d['address']     ?? '',
      status:      JobStatus.values.firstWhere(
        (e) => e.name == (d['status'] ?? 'active'),
        orElse: () => JobStatus.active,
      ),
      budget:      (d['budget']     ?? 0).toDouble(),
      totalDays:   d['totalDays']   ?? 0,
      currentDay:  d['currentDay']  ?? 0,
      workerIds:   List<String>.from(d['workerIds'] ?? []),
      startDate:   (d['startDate'] as Timestamp).toDate(),
      endDate:     d['endDate'] != null
          ? (d['endDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title':      title,
    'clientId':   clientId,
    'clientName': clientName,
    'address':    address,
    'status':     status.name,
    'budget':     budget,
    'totalDays':  totalDays,
    'currentDay': currentDay,
    'workerIds':  workerIds,
    'startDate':  Timestamp.fromDate(startDate),
    'endDate':    endDate != null ? Timestamp.fromDate(endDate!) : null,
  };

  double get progressPercent =>
      totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;
}

// ─────────────────────────────────────────────
// lib/models/attendance_model.dart

class AttendanceModel {
  final String id;
  final String jobId;
  final String workerId;
  final DateTime date;
  final bool present;

  AttendanceModel({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.date,
    required this.present,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id:       doc.id,
      jobId:    d['jobId']   ?? '',
      workerId: d['workerId']?? '',
      date:     (d['date'] as Timestamp).toDate(),
      present:  d['present'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'jobId':    jobId,
    'workerId': workerId,
    'date':     Timestamp.fromDate(date),
    'present':  present,
  };
}

// ─────────────────────────────────────────────
// lib/models/payment_model.dart

enum PaymentStatus { pending, paid }

class PaymentModel {
  final String id;
  final String workerId;
  final String workerName;
  final String jobId;
  final String jobTitle;
  final int daysWorked;
  final double dailyRate;
  final double totalAmount;
  final PaymentStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? paidAt;

  PaymentModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.jobId,
    required this.jobTitle,
    required this.daysWorked,
    required this.dailyRate,
    required this.totalAmount,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    this.paidAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id:          doc.id,
      workerId:    d['workerId']    ?? '',
      workerName:  d['workerName']  ?? '',
      jobId:       d['jobId']       ?? '',
      jobTitle:    d['jobTitle']    ?? '',
      daysWorked:  d['daysWorked']  ?? 0,
      dailyRate:   (d['dailyRate']  ?? 0).toDouble(),
      totalAmount: (d['totalAmount']?? 0).toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == (d['status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      periodStart: (d['periodStart'] as Timestamp).toDate(),
      periodEnd:   (d['periodEnd']   as Timestamp).toDate(),
      paidAt: d['paidAt'] != null
          ? (d['paidAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'workerId':    workerId,
    'workerName':  workerName,
    'jobId':       jobId,
    'jobTitle':    jobTitle,
    'daysWorked':  daysWorked,
    'dailyRate':   dailyRate,
    'totalAmount': totalAmount,
    'status':      status.name,
    'periodStart': Timestamp.fromDate(periodStart),
    'periodEnd':   Timestamp.fromDate(periodEnd),
    'paidAt':      paidAt != null ? Timestamp.fromDate(paidAt!) : null,
  };
}
