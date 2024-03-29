import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(StatefulNavbarApp());
}

GoRouterWidgetBuilder _widgetForRoute(Widget widget) => (_, __) => widget;

/// An example demonstrating how to use nested navigators with a Material 3 NavigationBar
class StatefulNavbarApp extends StatelessWidget {
  StatefulNavbarApp({Key? key}) : super(key: key);

  static GoRoute _route(String path, Widget widget, List<RouteBase> routes) =>
      GoRoute(path: path, routes: routes, builder: _widgetForRoute(widget));

  static Destination _destination(
      String title, IconData icon, MaterialColor color) {
    final String path = '/${title.toLowerCase()}';
    return Destination(title, icon, color, path, routes: <RouteBase>[
      _route(path, RootPage(destinationTitle: title), [
        _route('list', ListPage(destinationTitle: title), [
          _route('text', TextPage(destinationTitle: title), []),
        ]),
      ])
    ]);
  }

  final GoRouter _router = GoRouter(
    initialLocation: '/teal',
    routes: <RouteBase>[
      StatefulShellRoute(
        branches: [
          _destination('Teal', Icons.home, Colors.teal),
          _destination('Cyan', Icons.business, Colors.cyan),
          _destination('Orange', Icons.school, Colors.orange),
          _destination('Blue', Icons.flight, Colors.blue),
        ],
        navigatorContainerBuilder: (BuildContext context, StatefulNavigationShell navigationShell,
            List<Widget> children) => Home(navigationShell: navigationShell, children: children),
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) =>
          navigationShell,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin<Home> {
  late final List<AnimationController> destinationFaders = [];

  StatefulNavigationShell get navigationShell => widget.navigationShell;
  Iterable<Destination> get destinations => navigationShell.route.branches
      .map((branch) => branch as Destination);

  List<Widget> destinationViews(List<Widget> branchNavigators) =>
      branchNavigators.mapIndexed((int i, Widget child) {
        return FadeTransition(
            opacity: destinationFaders[i]
                .drive(CurveTween(curve: Curves.fastOutSlowIn)),
            child: child);
      }).toList();

  AnimationController buildFaderController() {
    final AnimationController controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {}); // Rebuild unselected destinations offstage.
      }
    });
    return controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (destinationFaders.isEmpty) {
      destinationFaders.addAll(List<AnimationController>.generate(
          widget.children.length, (int index) => buildFaderController()).toList());
      destinationFaders[0].value = 1.0;
    }
  }

  @override
  void dispose() {
    for (final AnimationController controller in destinationFaders) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final List<Widget> children = destinationViews(widget.children);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: children.mapIndexed((int index, Widget view) {
            if (index == navigationShell.currentIndex) {
              destinationFaders[index].forward();
              return Offstage(offstage: false, child: view);
            } else {
              destinationFaders[index].reverse();
              if (destinationFaders[index].isAnimating) {
                return IgnorePointer(child: view);
              }
              return Offstage(child: view);
            }
          }).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(index),
        destinations: destinations.map((Destination destination) {
          return NavigationDestination(
            icon: Icon(destination.icon, color: destination.color),
            label: destination.title,
          );
        }).toList(),
      ),
    );
  }
}

class Destination extends StatefulShellBranch {
  Destination(this.title, this.icon, this.color, this.path,
      {required super.routes})
      : super(initialLocation: path);

  final String title;
  final IconData icon;
  final MaterialColor color;
  final String path;
}

class RootPage extends StatelessWidget {
  const RootPage({super.key, required this.destinationTitle});

  final String destinationTitle;

  Widget _buildDialog(BuildContext context, Destination destination) {
    return AlertDialog(
      title: Text('${destination.title} AlertDialog'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Destination destination = StatefulNavigationShell.of(context).destination(destinationTitle);
    final TextStyle headlineSmall = Theme.of(context).textTheme.headlineSmall!;
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: destination.color,
      visualDensity: VisualDensity.comfortable,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      textStyle: headlineSmall,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${destination.title} RootPage - /'),
        backgroundColor: destination.color,
      ),
      backgroundColor: destination.color[50],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                GoRouter.of(context).go('${destination.path}/list');
              },
              child: const Text('Push /list'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                showDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (context) => _buildDialog(context, destination),
                );
              },
              child: const Text('Local Dialog'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                showDialog(
                  context: context,
                  useRootNavigator: true,
                  builder: (context) => _buildDialog(context, destination),
                );
              },
              child: const Text('Root Dialog'),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  style: buttonStyle,
                  onPressed: () {
                    showBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          child: Text(
                            '${destination.title} BottomSheet\n'
                            'Tap the back button to dismiss',
                            style: headlineSmall,
                            softWrap: true,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Local BottomSheet'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ListPage extends StatelessWidget {
  const ListPage({super.key, required this.destinationTitle});

  final String destinationTitle;

  @override
  Widget build(BuildContext context) {
    final Destination destination = StatefulNavigationShell.of(context).destination(destinationTitle);
    const int itemCount = 50;
    final ButtonStyle buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: destination.color,
      fixedSize: const Size.fromHeight(128),
      textStyle: Theme.of(context).textTheme.headlineSmall,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('${destination.title} ListPage - /list'),
        backgroundColor: destination.color,
      ),
      backgroundColor: destination.color[50],
      body: SizedBox.expand(
        child: ListView.builder(
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: OutlinedButton(
                style: buttonStyle.copyWith(
                  backgroundColor: MaterialStatePropertyAll<Color>(Color.lerp(
                      destination.color[100],
                      Colors.white,
                      index / itemCount)!),
                ),
                onPressed: () {
                  GoRouter.of(context).go('${destination.path}/list/text');
                },
                child: Text('Push /text [$index]'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TextPage extends StatefulWidget {
  const TextPage({super.key, required this.destinationTitle});

  final String destinationTitle;

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: 'Sample Text');
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Destination destination = StatefulNavigationShell.of(context).destination(widget.destinationTitle);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${destination.title} TextPage - /list/text'),
        backgroundColor: destination.color,
      ),
      backgroundColor: destination.color[50],
      body: Container(
        padding: const EdgeInsets.all(32.0),
        alignment: Alignment.center,
        child: TextField(
          controller: textController,
          style: theme.primaryTextTheme.headlineMedium?.copyWith(
            color: destination.color,
          ),
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: destination.color,
                width: 3.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper extension on StatefulNavigationShellState to get the current Destination.
extension StatefulNavigationShellStateHelper on StatefulNavigationShellState {
  Destination destination(String title) => route.branches.whereType<Destination>()
      .firstWhere((e) => e.title == title);
}
