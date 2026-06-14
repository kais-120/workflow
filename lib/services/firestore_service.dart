// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════
  //  WORKERS
  // ═══════════════════════════════════════
  CollectionReference get _workers => _db.collection('workers');

  Stream<List<WorkerModel>> watchWorkers() => _workers
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => WorkerModel.fromFirestore(d)).toList());

  Future<void> addWorker(WorkerModel w)    => _workers.doc(w.id).set(w.toMap());
  Future<void> updateWorker(WorkerModel w) => _workers.doc(w.id).update(w.toMap());
  Future<void> deleteWorker(String id)     => _workers.doc(id).delete();

  Future<WorkerModel?> getWorker(String id) async {
    final doc = await _workers.doc(id).get();
    return doc.exists ? WorkerModel.fromFirestore(doc) : null;
  }

  // ═══════════════════════════════════════
  //  CLIENTS
  // ═══════════════════════════════════════
  CollectionReference get _clients => _db.collection('clients');

  Stream<List<ClientModel>> watchClients() => _clients
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ClientModel.fromFirestore(d)).toList());

  Future<void> addClient(ClientModel c)    => _clients.doc(c.id).set(c.toMap());
  Future<void> updateClient(ClientModel c) => _clients.doc(c.id).update(c.toMap());
  Future<void> deleteClient(String id)     => _clients.doc(id).delete();

  // ═══════════════════════════════════════
  //  JOBS
  // ═══════════════════════════════════════
  CollectionReference get _jobs => _db.collection('jobs');

  Stream<List<JobModel>> watchJobs() => _jobs
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => JobModel.fromFirestore(d)).toList());

  Stream<List<JobModel>> watchActiveJobs() => _jobs
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((s) => s.docs.map((d) => JobModel.fromFirestore(d)).toList());

  Future<void> addJob(JobModel j)    => _jobs.doc(j.id).set(j.toMap());
  Future<void> updateJob(JobModel j) => _jobs.doc(j.id).update(j.toMap());

  // ═══════════════════════════════════════
  //  ATTENDANCE  (dayType based)
  // ═══════════════════════════════════════
  CollectionReference get _attendance => _db.collection('attendance');

  Future<List<AttendanceModel>> getAttendanceForJobOnDate(
    String jobId,
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day);
    final end   = start.add(const Duration(days: 1));

    final snap = await _attendance
        .where('jobId', isEqualTo: jobId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    return snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList();
  }

  // ✅ Returns total days (sum of multipliers: 0.5, 1.0, 1.5) for one job
  Future<double> getTotalDaysWorked(String workerId, String jobId) async {
    final snap = await _attendance
        .where('workerId', isEqualTo: workerId)
        .where('jobId',    isEqualTo: jobId)
        .where('present',  isEqualTo: true)
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      final a = AttendanceModel.fromFirestore(doc);
      total += a.daysValue;
    }
    return total;
  }

  // ✅ Returns total days across ALL jobs for a worker
  Future<double> getTotalDaysWorkedAllJobs(String workerId) async {
    final snap = await _attendance
        .where('workerId', isEqualTo: workerId)
        .where('present',  isEqualTo: true)
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      final a = AttendanceModel.fromFirestore(doc);
      total += a.daysValue;
    }
    return total;
  }

  // Stream attendance for a worker (all jobs, for history tab)
  Stream<List<AttendanceModel>> watchWorkerAttendance(String workerId) {
    return _attendance
        .where('workerId', isEqualTo: workerId)
        .where('present',  isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AttendanceModel.fromFirestore(d)).toList());
  }

  Future<void> saveAttendanceBatch(List<AttendanceModel> records) async {
    final batch = _db.batch();
    for (final r in records) {
      batch.set(_attendance.doc(r.id), r.toMap());
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════
  //  PAYMENTS  (days × dailyRate)
  // ═══════════════════════════════════════
  CollectionReference get _payments => _db.collection('payments');

  Stream<List<PaymentModel>> watchPayments() => _payments
      .orderBy('periodEnd', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentModel.fromFirestore(d)).toList());

  Stream<List<PaymentModel>> watchPendingPayments() => _payments
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentModel.fromFirestore(d)).toList());

  Future<void> addPayment(PaymentModel p) =>
      _payments.doc(p.id).set(p.toMap());

  Future<void> markPaymentPaid(String id) => _payments.doc(id).update({
        'status': 'paid',
        'paidAt': Timestamp.fromDate(DateTime.now()),
      });

  Future<void> markAllPendingPaid() async {
    final snap =
        await _payments.where('status', isEqualTo: 'pending').get();
    final batch = _db.batch();
    final now   = Timestamp.fromDate(DateTime.now());
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'paid', 'paidAt': now});
    }
    await batch.commit();
  }

  // ✅ Generate payment from attendance days × dailyRate
  Future<PaymentModel> generatePayment({
    required WorkerModel worker,
    required JobModel job,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final days  = await getTotalDaysWorked(worker.id, job.id);
    final total = days * worker.dailyRate;

    return PaymentModel(
      id:          '${worker.id}_${job.id}_${periodEnd.millisecondsSinceEpoch}',
      workerId:    worker.id,
      workerName:  worker.name,
      jobId:       job.id,
      jobLabel:    job.displayLabel,
      daysWorked:  days,
      dailyRate:   worker.dailyRate,
      totalAmount: total,
      status:      PaymentStatus.pending,
      periodStart: periodStart,
      periodEnd:   periodEnd,
    );
  }

  // ═══════════════════════════════════════
  //  DASHBOARD STATS
  // ═══════════════════════════════════════
  Future<Map<String, dynamic>> getDashboardStats() async {
    final jobs    = await _jobs.get();
    final workers = await _workers.get();
    final clients = await _clients.get();
    final pending = await _payments
        .where('status', isEqualTo: 'pending').get();
    final paid    = await _payments
        .where('status', isEqualTo: 'paid').get();

    double totalPending = 0;
    double totalPaid    = 0;

    for (final doc in pending.docs) {
      totalPending +=
          ((doc.data() as Map)['totalAmount'] ?? 0).toDouble();
    }
    for (final doc in paid.docs) {
      totalPaid +=
          ((doc.data() as Map)['totalAmount'] ?? 0).toDouble();
    }

    return {
      'activeJobs':    jobs.docs
          .where((d) => (d.data() as Map)['status'] == 'active')
          .length,
      'totalWorkers':  workers.docs.length,
      'totalClients':  clients.docs.length,
      'totalPending':  totalPending,
      'totalPaid':     totalPaid,
      'totalEarnings': totalPending + totalPaid,
    };
  }
}
