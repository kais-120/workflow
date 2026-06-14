// lib/models/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
// Day type enum — admin selects per worker per day
// ─────────────────────────────────────────────
enum DayType {
  fullDay,    // 1.0  × dailyRate
  halfDay,    // 0.5  × dailyRate
  dayAndHalf, // 1.5  × dailyRate
}

extension DayTypeExt on DayType {
  double get multiplier {
    switch (this) {
      case DayType.fullDay:    return 1.0;
      case DayType.halfDay:    return 0.5;
      case DayType.dayAndHalf: return 1.5;
    }
  }

  String get label {
    switch (this) {
      case DayType.fullDay:    return 'Full Day';
      case DayType.halfDay:    return 'Half Day';
      case DayType.dayAndHalf: return 'Day & Half';
    }
  }

  String get shortLabel {
    switch (this) {
      case DayType.fullDay:    return '1 day';
      case DayType.halfDay:    return '½ day';
      case DayType.dayAndHalf: return '1½ day';
    }
  }
}

// ─────────────────────────────────────────────
// WorkerModel — dailyRate (DT/day)
// ─────────────────────────────────────────────
class WorkerModel {
  final String id;
  final String name;
  final String role;
  final double dailyRate; // DT per full day
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
// ClientModel
// ─────────────────────────────────────────────
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
// JobModel — no budget/totalDays, uses clientName + startDate as label
// ─────────────────────────────────────────────
enum JobStatus { active, completed, paused }

class JobModel {
  final String id;
  final String title;       // kept for internal use but not shown in UI
  final String clientId;
  final String clientName;
  final String address;
  final JobStatus status;
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
    required this.workerIds,
    required this.startDate,
    this.endDate,
  });

  /// Display label: "Client Name · dd/MM/yyyy"
  String get displayLabel {
    final d = startDate;
    final day   = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year  = d.year.toString();
    return '$clientName · $day/$month/$year';
  }

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JobModel(
      id:         doc.id,
      title:      d['title']      ?? '',
      clientId:   d['clientId']   ?? '',
      clientName: d['clientName'] ?? '',
      address:    d['address']    ?? '',
      status: JobStatus.values.firstWhere(
        (e) => e.name == (d['status'] ?? 'active'),
        orElse: () => JobStatus.active,
      ),
      workerIds: List<String>.from(d['workerIds'] ?? []),
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate:   d['endDate'] != null
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
    'workerIds':  workerIds,
    'startDate':  Timestamp.fromDate(startDate),
    'endDate':    endDate != null ? Timestamp.fromDate(endDate!) : null,
  };
}

// ─────────────────────────────────────────────
// AttendanceModel — stores dayType instead of hours
// ─────────────────────────────────────────────
class AttendanceModel {
  final String id;
  final String jobId;
  final String workerId;
  final DateTime date;
  final DayType dayType;   // fullDay / halfDay / dayAndHalf
  final bool present;

  AttendanceModel({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.date,
    required this.dayType,
    required this.present,
  });

  /// Days equivalent (e.g. 0.5, 1.0, 1.5)
  double get daysValue => present ? dayType.multiplier : 0.0;

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id:       doc.id,
      jobId:    d['jobId']    ?? '',
      workerId: d['workerId'] ?? '',
      date:     (d['date'] as Timestamp).toDate(),
      dayType:  DayType.values.firstWhere(
        (e) => e.name == (d['dayType'] ?? 'fullDay'),
        orElse: () => DayType.fullDay,
      ),
      present:  d['present'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'jobId':    jobId,
    'workerId': workerId,
    'date':     Timestamp.fromDate(date),
    'dayType':  dayType.name,
    'present':  present,
  };
}

// ─────────────────────────────────────────────
// PaymentModel — uses daysWorked + dailyRate
// ─────────────────────────────────────────────
enum PaymentStatus { pending, paid }

class PaymentModel {
  final String id;
  final String workerId;
  final String workerName;
  final String jobId;
  final String jobLabel;   // "ClientName · dd/MM/yyyy"
  final double daysWorked; // can be 0.5, 1.0, 1.5 etc
  final double dailyRate;
  final double totalAmount; // daysWorked × dailyRate
  final PaymentStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? paidAt;

  PaymentModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.jobId,
    required this.jobLabel,
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
      jobLabel:    d['jobLabel']    ?? '',
      daysWorked:  (d['daysWorked'] ?? 0).toDouble(),
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
    'jobLabel':    jobLabel,
    'daysWorked':  daysWorked,
    'dailyRate':   dailyRate,
    'totalAmount': totalAmount,
    'status':      status.name,
    'periodStart': Timestamp.fromDate(periodStart),
    'periodEnd':   Timestamp.fromDate(periodEnd),
    'paidAt':      paidAt != null ? Timestamp.fromDate(paidAt!) : null,
  };
}
