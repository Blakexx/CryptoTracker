import 'package:flutter/material.dart';
import 'package:crypto_tracker/layout.dart';

class FeatureDiscovery extends StatefulWidget {
  static String activeStep(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(_InheritedFeatureDiscovery)
            as _InheritedFeatureDiscovery)
        .activeStepId;
  }

  static void discoverFeatures(BuildContext context, List<String> steps) {
    _FeatureDiscoveryState state = context
        .ancestorStateOfType(new TypeMatcher<_FeatureDiscoveryState>()) as _FeatureDiscoveryState;

    state.discoverFeatures(steps);
  }

  static void markStepComplete(BuildContext context, String stepId) {
    _FeatureDiscoveryState state = context
        .ancestorStateOfType(new TypeMatcher<_FeatureDiscoveryState>()) as _FeatureDiscoveryState;

    state.markStepComplete(stepId);
  }

  static void dismiss(BuildContext context) {
    _FeatureDiscoveryState state = context
        .ancestorStateOfType(new TypeMatcher<_FeatureDiscoveryState>()) as _FeatureDiscoveryState;

    state.dismiss();
  }

  final Widget child;

  FeatureDiscovery({
    this.child,
  });

  @override
  _FeatureDiscoveryState createState() => new _FeatureDiscoveryState();
}

class _FeatureDiscoveryState extends State<FeatureDiscovery> {
  List<String> steps;
  int activeStepIndex;

  void discoverFeatures(List<String> steps) {
    setState(() {
      this.steps = steps;
      activeStepIndex = 0;
    });
  }

  void markStepComplete(String stepId) {
    if (steps != null && steps[activeStepIndex] == stepId) {
      setState(() {
        ++activeStepIndex;

        if (activeStepIndex >= steps.length) {
          _cleanupAfterSteps();
        }
      });
    }
  }

  void dismiss() {
    setState(() {
      _cleanupAfterSteps();
    });
  }

  void _cleanupAfterSteps() {
    steps = null;
    activeStepIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return new _InheritedFeatureDiscovery(
      activeStepId: steps?.elementAt(activeStepIndex),
      child: widget.child,
    );
  }
}

class _InheritedFeatureDiscovery extends InheritedWidget {
  final String activeStepId;

  _InheritedFeatureDiscovery({
    this.activeStepId,
    child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(_InheritedFeatureDiscovery oldWidget) {
    return oldWidget.activeStepId != activeStepId;
  }
}

class DescribedFeatureOverlay extends StatefulWidget {
  final String featureId;
  final IconData icon;
  final Color color;
  final String title;
  final Widget description;
  final Function(VoidCallback onActionComplete) doAction;
  final Widget child;

  DescribedFeatureOverlay({
    this.featureId,
    this.icon,
    this.color,
    this.title,
    this.description,
    this.doAction,
    this.child,
  });

  @override
  _DescribedFeatureOverlayState createState() => new _DescribedFeatureOverlayState();
}

class _DescribedFeatureOverlayState extends State<DescribedFeatureOverlay>
    with TickerProviderStateMixin {
  Size screenSize;
  bool showOverlay = false;
  _OverlayState state = _OverlayState.closed;
  double transitionPercent = 1.0;

  AnimationController openController;
  AnimationController pulseController;
  AnimationController activationController;
  AnimationController dismissController;

  @override
  void initState() {
    super.initState();

    initAnimationControllers();
  }

  void initAnimationControllers() {
    openController = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )
      ..addListener(() {
        setState(() => transitionPercent = openController.value);
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.forward) {
          setState(() => state = _OverlayState.opening);
        } else if (status == AnimationStatus.completed) {
          pulseController.forward(from: 0.0);
        }
      });

    pulseController = new AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )
      ..addListener(() {
        setState(() => transitionPercent = pulseController.value);
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.forward) {
          setState(() => state = _OverlayState.pulsing);
        } else if (status == AnimationStatus.completed) {
          pulseController.forward(from: 0.0);
        }
      });

    activationController = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )
      ..addListener(() {
        setState(() => transitionPercent = activationController.value);
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.forward) {
          setState(() => state = _OverlayState.activating);
        } else if (status == AnimationStatus.completed) {
          if (widget.doAction == null) {
            FeatureDiscovery.markStepComplete(context, widget.featureId);
          } else {
            widget.doAction(() {
              FeatureDiscovery.markStepComplete(context, widget.featureId);
            });
          }
        }
      });

    dismissController = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )
      ..addListener(() {
        setState(() => transitionPercent = dismissController.value);
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.forward) {
          setState(() => state = _OverlayState.dismissing);
        } else if (status == AnimationStatus.completed) {
          FeatureDiscovery.dismiss(context);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    screenSize = MediaQuery.of(context).size;

    showOverlayIfActiveStep();
  }

  void showOverlayIfActiveStep() {
    String activeStep = FeatureDiscovery.activeStep(context);
    setState(() => showOverlay = activeStep == widget.featureId);

    if (activeStep == widget.featureId) {
      openController.forward(from: 0.0);
    }
  }

  void activate() {
    pulseController.stop();

    activationController.forward(from: 0.0);
  }

  void dismiss() {
    pulseController.stop();

    dismissController.forward(from: 0.0);
  }

  Widget buildOverlay(Offset anchor) {
    return new Stack(
      children: <Widget>[
        new GestureDetector(
          onTap: dismiss,
          child: new Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        new _Background(
          state: state,
          transitionPercent: transitionPercent,
          anchor: anchor,
          color: widget.color,
          screenSize: screenSize,
        ),
        new _Content(
          state: state,
          transitionPercent: transitionPercent,
          anchor: anchor,
          screenSize: screenSize,
          title: widget.title,
          description: widget.description,
          touchTargetRadius: 44.0,
          touchTargetToContentPadding: 20.0,
        ),
        new _Pulse(
          state: state,
          transitionPercent: transitionPercent,
          anchor: anchor,
        ),
        new _TouchTarget(
          state: state,
          transitionPercent: transitionPercent,
          anchor: anchor,
          icon: widget.icon,
          color: widget.color,
          onPressed: activate,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new AnchoredOverlay(
      showOverlay: showOverlay,
      overlayBuilder: (BuildContext context, Offset anchor) {
        return buildOverlay(anchor);
      },
      child: widget.child,
    );
  }
}

class _Background extends StatelessWidget {
  final _OverlayState state;
  final double transitionPercent;
  final Offset anchor;
  final Color color;
  final Size screenSize;

  _Background({
    this.state,
    this.transitionPercent,
    this.anchor,
    this.color,
    this.screenSize,
  });

  bool isCloseToTopOrBottom(Offset position) {
    return position.dy >= 88.0 || (screenSize.height - position.dy) >= 88.0;
  }

  bool isOnTopHalfOfScreen(Offset position) {
    return position.dy < (screenSize.height / 2.0);
  }

  bool isOnLeftHalfOfScreen(Offset position) {
    return position.dx < (screenSize.width / 2.0);
  }

  Offset backgroundPosition() {
    final isBackgroundCentered = isCloseToTopOrBottom(anchor);
    if (isBackgroundCentered) {
      return anchor;
    } else {
      final startingBackgroundPosition = anchor;
      final endingBackgroundPosition = new Offset(
          screenSize.width / 2.0 + (isOnLeftHalfOfScreen(anchor) ? -20.0 : 20.0),
          anchor.dy +
              (isOnTopHalfOfScreen(anchor)
                  ? -(screenSize.width / 2.0) + 40.0
                  : (screenSize.width / 2.0) - 40.0));

      switch (state) {
        case _OverlayState.opening:
          final adjustedPercent =
              const Interval(0.0, 0.8, curve: Curves.easeOut).transform(transitionPercent);
          return Offset.lerp(startingBackgroundPosition, endingBackgroundPosition, adjustedPercent);
        case _OverlayState.activating:
          return endingBackgroundPosition;
        case _OverlayState.dismissing:
          return Offset.lerp(
              endingBackgroundPosition, startingBackgroundPosition, transitionPercent);
        default:
          return endingBackgroundPosition;
      }
    }
  }

  double radius() {
    final isBackgroundCentered = isCloseToTopOrBottom(anchor);
    final backgroundRadius = screenSize.width * (isBackgroundCentered ? 1.0 : 0.75);

    switch (state) {
      case _OverlayState.opening:
        final adjustedPercent =
            const Interval(0.0, 0.8, curve: Curves.easeOut).transform(transitionPercent);
        return backgroundRadius * adjustedPercent;
      case _OverlayState.activating:
        return backgroundRadius + (transitionPercent * 40.0);
      case _OverlayState.dismissing:
        return backgroundRadius * (1.0 - transitionPercent);
      default:
        return backgroundRadius;
    }
  }

  double backgroundOpacity() {
    switch (state) {
      case _OverlayState.opening:
        final adjustedPercent =
            const Interval(0.0, 0.3, curve: Curves.easeOut).transform(transitionPercent);
        return 0.96 * adjustedPercent;
      case _OverlayState.activating:
        final adjustedPercent =
            const Interval(0.1, 0.6, curve: Curves.easeOut).transform(transitionPercent);
        return 0.96 * (1.0 - adjustedPercent);
      case _OverlayState.dismissing:
        final adjustedPercent =
            const Interval(0.2, 1.0, curve: Curves.easeOut).transform(transitionPercent);
        return 0.96 * (1.0 - adjustedPercent);
      default:
        return 0.96;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (state == _OverlayState.closed) {
      return new Container();
    }

    return new CenterAbout(
      position: backgroundPosition(),
      child: new Container(
        width: 2 * radius(),
        height: 2 * radius(),
        decoration: new BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(backgroundOpacity()),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final _OverlayState state;
  final double transitionPercent;
  final Offset anchor;
  final Size screenSize;
  final String title;
  final Widget description;
  final double touchTargetRadius;
  final double touchTargetToContentPadding;

  _Content({
    this.state,
    this.transitionPercent,
    this.anchor,
    this.screenSize,
    this.title,
    this.description,
    this.touchTargetRadius,
    this.touchTargetToContentPadding,
  });

  bool isCloseToTopOrBottom(Offset position) {
    return position.dy >= 88.0 || (screenSize.height - position.dy) >= 88.0;
  }

  bool isOnTopHalfOfScreen(Offset position) {
    return position.dy < (screenSize.height / 2.0);
  }

  DescribedFeatureContentOrientation getContentOrientation(Offset position) {
    if (isCloseToTopOrBottom(position)) {
      if (isOnTopHalfOfScreen(position)) {
        return DescribedFeatureContentOrientation.below;
      } else {
        return DescribedFeatureContentOrientation.above;
      }
    } else {
      if (isOnTopHalfOfScreen(position)) {
        return DescribedFeatureContentOrientation.above;
      } else {
        return DescribedFeatureContentOrientation.below;
      }
    }
  }

  double opacity() {
    switch (state) {
      case _OverlayState.closed:
        return 0.0;
      case _OverlayState.opening:
        final adjustedPercent =
            const Interval(0.6, 1.0, curve: Curves.easeOut).transform(transitionPercent);
        return adjustedPercent;
      case _OverlayState.activating:
      case _OverlayState.dismissing:
        final adjustedPercent =
            const Interval(0.0, 0.4, curve: Curves.easeOut).transform(transitionPercent);
        return 1.0 - adjustedPercent;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentOrientation = getContentOrientation(anchor);
    final contentOffsetMultiplier =
        contentOrientation == DescribedFeatureContentOrientation.below ? 1.0 : -1.0;
    final contentY = anchor.dy + (contentOffsetMultiplier * (touchTargetRadius + 20.0));
    final contentFractionalOffset = contentOffsetMultiplier.clamp(-1.0, 0.0);

    return new Positioned(
        top: contentY,
        child: new FractionalTranslation(
          translation: new Offset(0.0, contentFractionalOffset),
          child: new Opacity(
            opacity: opacity(),
            child: new Container(
              width: screenSize.width,
              child: new Material(
                  color: Colors.transparent,
                  child: new Padding(
                      padding: const EdgeInsets.only(left: 40.0, right: 40.0),
                      child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          new Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: new Text(
                              title,
                              style: new TextStyle(
                                fontSize: 20.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          description,
                        ],
                      ))),
            ),
          ),
        ));
  }
}

class _Pulse extends StatelessWidget {
  final _OverlayState state;
  final double transitionPercent;
  final Offset anchor;

  _Pulse({
    this.state,
    this.transitionPercent,
    this.anchor,
  });

  double radius() {
    switch (state) {
      case _OverlayState.pulsing:
        double expandedPercent;
        if (transitionPercent >= 0.3 && transitionPercent <= 0.8) {
          expandedPercent = (transitionPercent - 0.3) / 0.5;
        } else {
          expandedPercent = 0.0;
        }

        return 44.0 + (35.0 * expandedPercent);
      case _OverlayState.dismissing:
      case _OverlayState.activating:
        return 0.0;
      default:
        return 0.0;
    }
  }

  double opacity() {
    switch (state) {
      case _OverlayState.pulsing:
        final percentOpaque = 1.0 - ((transitionPercent.clamp(0.3, 0.8) - 0.3) / 0.5);
        return (percentOpaque * 0.75).clamp(0.0, 1.0);
      case _OverlayState.activating:
      case _OverlayState.dismissing:
        return 0.0;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (state == _OverlayState.closed) {
      return new Container();
    }

    return new CenterAbout(
      position: anchor,
      child: new Container(
        width: radius() * 2,
        height: radius() * 2,
        decoration: new BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity()),
        ),
      ),
    );
  }
}

class _TouchTarget extends StatelessWidget {
  final _OverlayState state;
  final double transitionPercent;
  final Offset anchor;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  _TouchTarget({
    this.state,
    this.transitionPercent,
    this.anchor,
    this.icon,
    this.color,
    this.onPressed,
  });

  double radius() {
    switch (state) {
      case _OverlayState.closed:
        return 0.0;
      case _OverlayState.opening:
        return 20 + (24.0 * transitionPercent);
      case _OverlayState.pulsing:
        double expandedPercent;
        if (transitionPercent < 0.3) {
          expandedPercent = transitionPercent / 0.3;
        } else if (transitionPercent < 0.6) {
          expandedPercent = 1.0 - ((transitionPercent - 0.3) / 0.3);
        } else {
          expandedPercent = 0.0;
        }

        return 44.0 + (20.0 * expandedPercent);
      case _OverlayState.activating:
      case _OverlayState.dismissing:
        return 20 + (24.0 * (1.0 - transitionPercent));
      default:
        return 44.0;
    }
  }

  double opacity() {
    switch (state) {
      case _OverlayState.opening:
        return const Interval(0.0, 0.3, curve: Curves.easeOut).transform(transitionPercent);
      case _OverlayState.activating:
      case _OverlayState.dismissing:
        return 1.0 - const Interval(0.7, 1.0, curve: Curves.easeOut).transform(transitionPercent);
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return new CenterAbout(
      position: anchor,
      child: new Container(
        width: 2 * radius(),
        height: 2 * radius(),
        child: new Opacity(
          opacity: opacity(),
          child: new RawMaterialButton(
            shape: new CircleBorder(),
            fillColor: Colors.white,
            child: new Icon(
              icon,
              color: color,
            ),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

enum DescribedFeatureContentOrientation {
  above,
  below,
}

enum _OverlayState {
  closed,
  opening,
  pulsing,
  activating,
  dismissing,
}
