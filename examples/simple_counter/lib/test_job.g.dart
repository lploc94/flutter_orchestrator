// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_job.dart';

// **************************************************************************
// ExecutorRegistryGenerator
// **************************************************************************

void registerExecutors(String api) {
  final dispatcher = Dispatcher();
  dispatcher.register<TestJob>(TestExecutor(api));
}

// **************************************************************************
// NetworkJobGenerator
// **************************************************************************

// ignore_for_file: unused_element
extension _$TestJobSerialization on TestJob {
  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'renamed_field': count,
      };

  static TestJob fromJson(Map<String, dynamic> json) {
    return TestJob(
      id: json['id'] as String,
      data: json['data'] as String,
      count: json['renamed_field'] as int,
    );
  }

  // ignore: unused_element
  static BaseJob fromJsonToBase(Map<String, dynamic> json) => fromJson(json);
}
