// lib/jobs/counter_jobs.dart
// Jobs represent actions/intents - pure data classes

import 'package:orchestrator_core/orchestrator_core.dart';

/// Job to increment the counter
class IncrementJob extends BaseJob {
  IncrementJob() : super(id: generateJobId('increment'));
}

/// Job to decrement the counter
class DecrementJob extends BaseJob {
  DecrementJob() : super(id: generateJobId('decrement'));
}

/// Job to reset the counter
class ResetJob extends BaseJob {
  ResetJob() : super(id: generateJobId('reset'));
}
