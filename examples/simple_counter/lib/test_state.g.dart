// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_state.dart';

// **************************************************************************
// AsyncStateGenerator
// **************************************************************************

// ignore_for_file: unused_element

const _$TestUserStateSentinel = Object();

extension TestUserStateGenerated on TestUserState {
  TestUserState copyWith(
      {Object? status = _$TestUserStateSentinel,
      Object? data = _$TestUserStateSentinel,
      Object? error = _$TestUserStateSentinel,
      Object? username = _$TestUserStateSentinel}) {
    return TestUserState(
      status: status == _$TestUserStateSentinel
          ? this.status
          : status as AsyncStatus,
      data: data == _$TestUserStateSentinel ? this.data : data as String?,
      error: error == _$TestUserStateSentinel ? this.error : error,
      username: username == _$TestUserStateSentinel
          ? this.username
          : username as String?,
    );
  }

  TestUserState toLoading() => copyWith(status: AsyncStatus.loading);

  TestUserState toRefreshing() => copyWith(status: AsyncStatus.refreshing);

  TestUserState toSuccess(String? data) => copyWith(
        status: AsyncStatus.success,
        data: data,
      );

  TestUserState toFailure(Object error) => copyWith(
        status: AsyncStatus.failure,
        error: error,
      );

  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(String? data) success,
    required R Function(Object error) failure,
    R Function(String? data)? refreshing,
  }) {
    return switch (status) {
      AsyncStatus.initial => initial(),
      AsyncStatus.loading => loading(),
      AsyncStatus.success => success(data!),
      AsyncStatus.failure => failure(error!),
      AsyncStatus.refreshing => refreshing?.call(data!) ?? loading(),
    };
  }

  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(String? data)? success,
    R Function(Object error)? failure,
    required R Function() orElse,
  }) {
    return switch (status) {
      AsyncStatus.initial => initial?.call() ?? orElse(),
      AsyncStatus.loading => loading?.call() ?? orElse(),
      AsyncStatus.success => success?.call(data!) ?? orElse(),
      AsyncStatus.failure => failure?.call(error!) ?? orElse(),
      AsyncStatus.refreshing => loading?.call() ?? orElse(),
    };
  }
}
