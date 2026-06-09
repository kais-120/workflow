// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════
  //  WORKERS
  // ═══════════════════════════════════════

  CollectionReference get _workers => _db.collection('workers');

  Stream<List<WorkerModel>> watchWorkers() {
    return _workers
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => WorkerModel.fromFirestore(d)).toList());
  }

  Future<void> addWorker(WorkerModel worker) async {
    await _workers.doc(worker.id).set(worker.toMap());
  }

  Future<void> updateWorker(WorkerModel worker) async {
    await _workers.doc(worker.id).update(worker.toMap());
  }

  Future<void> deleteWorker(String id) async {
    await _workers.doc(id).delete();
  }

  Future<WorkerModel?> getWorker(String id) async {
    final doc = await _workers.doc(id).get();
    if (!doc.exists) return null;
    return WorkerModel.fromFirestore(doc);
  }

  // ═══════════════════════════════════════
  //  CLIENTS
  // ═══════════════════════════════════════

  CollectionReference get _clients => _db.collection('clients');

  Stream<List<ClientModel>> watchClients() {
    return _clients
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ClientModel.fromFirestore(d)).toList());
  }

  Future<void> addClient(ClientModel client) async {
    await _clients.doc(client.id).set(client.toMap());
  }

  Future<void> updateClient(ClientModel client) async {
    await _clients.doc(client.id).update(client.toMap());
  }

  Future<void> deleteClient(String id) async {
    await _clients.doc(id).delete();
  }

  // ═══════════════════════════════════════
  //  JOBS
  // ═══════════════════════════════════════

  CollectionReference get _jobs => _db.collection('jobs');

  Stream<List<JobModel>> watchJobs() {
    return _jobs
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => JobModel.fromFirestore(d)).toList());
  }

  Stream<List<JobModel>> watchActiveJobs() {
    return _jobs
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => JobModel.fromFirestore(d)).toList());
  }

  Future<void> addJob(JobModel job) async {
    await _jobs.doc(job.id).set(job.toMap());
  }

  Future<void> updateJob(JobModel job) async {
    await _jobs.doc(job.id).update(job.toMap());
  }

  Future<void> incrementJobDay(String jobId) async {
    await _jobs.doc(jobId).update({
      'currentDay': FieldValue.increment(1),
    });
  }

  // ═══════════════════════════════════════
  //  ATTENDANCE
  // ═══════════════════════════════════════

  CollectionReference get _attendance => _db.collection('attendance');

  // Get attendance for a specific job + date
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

  // Count days worked by a worker on a job
  Future<int> getDaysWorked(String workerId, String jobId) async {
    final snap = await _attendance
        .where('workerId', isEqualTo: workerId)
        .where('jobId', isEqualTo: jobId)
        .where('present', isEqualTo: true)
        .get();
    return snap.docs.length;
  }

  // Save attendance batch for a day
  Future<void> saveAttendanceBatch(
    List<AttendanceModel> records,
  ) async {
    final batch = _db.batch();
    for (final record in records) {
      final ref = _attendance.doc(record.id);
      batch.set(ref, record.toMap());
    }
    await batch.commit();
  }

  // Watch attendance for a job grouped by worker
  Stream<List<AttendanceModel>> watchJobAttendance(String jobId) {
    return _attendance
        .where('jobId', isEqualTo: jobId)
        .where('present', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AttendanceModel.fromFirestore(d)).toList());
  }

  // ═══════════════════════════════════════
  //  PAYMENTS
  // ═══════════════════════════════════════

  CollectionReference get _payments => _db.collection('payments');

  Stream<List<PaymentModel>> watchPayments() {
    return _payments
        .orderBy('periodEnd', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }

  Stream<List<PaymentModel>> watchPendingPayments() {
    return _payments
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }

  Future<void> addPayment(PaymentModel payment) async {
    await _payments.doc(payment.id).set(payment.toMap());
  }

  Future<void> markPaymentPaid(String paymentId) async {
    await _payments.doc(paymentId).update({
      'status': 'paid',
      'paidAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markAllPendingPaid() async {
    final snap = await _payments
        .where('status', isEqualTo: 'pending')
        .get();

    final batch = _db.batch();
    final now = Timestamp.fromDate(DateTime.now());
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'paid', 'paidAt': now});
    }
    await batch.commit();
  }

  // Auto-generate payment record from attendance
  Future<PaymentModel> generatePayment({
    required WorkerModel worker,
    required JobModel job,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final days = await getDaysWorked(worker.id, job.id);
    final total = days * worker.dailyRate;

    return PaymentModel(
      id:          '${worker.id}_${job.id}_${periodEnd.millisecondsSinceEpoch}',
      workerId:    worker.id,
      workerName:  worker.name,
      jobId:       job.id,
      jobTitle:    job.title,
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
    final pending = await _payments.where('status', isEqualTo: 'pending').get();
    final paid    = await _payments.where('status', isEqualTo: 'paid').get();

    double totalPending = 0;
    double totalPaid    = 0;

    for (final doc in pending.docs) {
      totalPending += ((doc.data() as Map)['totalAmount'] ?? 0).toDouble();
    }
    for (final doc in paid.docs) {
      totalPaid += ((doc.data() as Map)['totalAmount'] ?? 0).toDouble();
    }

    return {
      'activeJobs':    jobs.docs.where((d) => (d.data() as Map)['status'] == 'active').length,
      'totalWorkers':  workers.docs.length,
      'totalClients':  clients.docs.length,
      'totalPending':  totalPending,
      'totalPaid':     totalPaid,
      'totalEarnings': totalPending + totalPaid,
    };
  }
}
