import 'package:orchestrator_core/orchestrator_core.dart';

part 'test_job.g.dart';

@NetworkJob()
class TestJob extends BaseJob implements NetworkAction<String> {
  final String data;

  @JsonKey(name: 'renamed_field')
  final int count;

  @JsonIgnore()
  final bool ignored;

  TestJob({
    required this.data,
    required this.count,
    this.ignored = false,
    String? id,
  }) : super(id: id ?? 'test');

  @override
  String createOptimisticResult() => data;

  @override
  String? get deduplicationKey => null;

  @override
  Map<String, dynamic> toJson() => _$TestJobSerialization(this).toJson();

  // Added factory for testability
  static TestJob fromJson(Map<String, dynamic> json) =>
      _$TestJobSerialization.fromJson(json);
}

class TestExecutor extends BaseExecutor<TestJob> {
  final String api;
  TestExecutor(this.api);
  @override
  Future<String> execute(TestJob job) async => 'done';

  @override
  Future<String> process(TestJob job) async => 'done';
}

@ExecutorRegistry([(TestJob, TestExecutor)])
void setupExecutors(String api) {}
