import 'package:flutter_test/flutter_test.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication_platform_interface.dart';
import 'package:screen_launch_by_notfication/screen_launch_by_notfication_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockScreenLaunchByNotficationPlatform
    with MockPlatformInterfaceMixin
    implements ScreenLaunchByNotficationPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>> isFromNotification() {
    // TODO: implement isFromNotification
    throw UnimplementedError();
  }

  @override
  Future<bool> storeNotificationPayload(String payload) {
    // TODO: implement storeNotificationPayload
    throw UnimplementedError();
  }
}

void main() {
  final ScreenLaunchByNotficationPlatform initialPlatform = ScreenLaunchByNotficationPlatform.instance;

  test('$MethodChannelScreenLaunchByNotfication is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelScreenLaunchByNotfication>());
  });

  test('getPlatformVersion', () async {
    ScreenLaunchByNotfication screenLaunchByNotficationPlugin = ScreenLaunchByNotfication();
    MockScreenLaunchByNotficationPlatform fakePlatform = MockScreenLaunchByNotficationPlatform();
    ScreenLaunchByNotficationPlatform.instance = fakePlatform;

    expect(await screenLaunchByNotficationPlugin.getPlatformVersion(), '42');
  });
}
