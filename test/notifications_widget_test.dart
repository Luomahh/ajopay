import 'package:ajopay/features/notifications/notifications.dart';
import 'package:ajopay/core/widgets/home_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
void main(){
 testWidgets('notification bell shows unread count', (tester) async {
  await tester.pumpWidget(ProviderScope(overrides:[notificationsProvider.overrideWith((ref) async => {'items':[],'unread':4})], child:const MaterialApp(home:Scaffold(appBar:null,body:NotificationBell()))));
  await tester.pumpAndSettle();
  expect(find.byTooltip('Notifications (4 unread)'),findsOneWidget);
  expect(find.text('4'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());
 });
 testWidgets('bottom destinations select Home and Profile', (tester) async {
  final router=GoRouter(initialLocation:'/dashboard', routes:[
   GoRoute(path:'/dashboard',builder:(_,_)=>const Scaffold(body:Text('Home content'),bottomNavigationBar:HomeNavigation(index:0))),
   GoRoute(path:'/profile',builder:(_,_)=>const Scaffold(body:Text('Profile content'),bottomNavigationBar:HomeNavigation(index:1))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig:router));
  await tester.tap(find.text('Profile'));await tester.pumpAndSettle();
  expect(find.text('Profile content'),findsOneWidget);
  expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,1);
  await tester.tap(find.text('Home'));await tester.pumpAndSettle();
  expect(find.text('Home content'),findsOneWidget);
 });
}
