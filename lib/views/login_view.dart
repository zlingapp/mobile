import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../global_state.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.appstate});
  final GlobalState appstate;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  String _emailField = "";
  String _passwordField = "";
  bool? _loadingOrFailed = false; // True if loading, null if login failed.
  bool _invalidPassword = false;
  bool _invalidEmail = false;
  bool _passwordVisible = false;

  static final emailRegex = RegExp(
      r"""^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$""");

  void validateEmail() {
    RegExpMatch? match = emailRegex.firstMatch(_emailField);
    if (match == null) {
      _invalidEmail = true;
    } else {
      _invalidEmail = false;
    }
  }

  void validatePassword() {
    _invalidPassword = _passwordField.length > 128;
  }

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/login-background.jpg"),
                fit: BoxFit.cover)),
        child: Center(
          child: BlurryContainer(
            borderRadius: BorderRadius.zero,
            color: const Color.fromARGB(150, 50, 50, 50),
            blur: 64,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Welcome Back!",
                      style: theme.primaryTextTheme.displayMedium!
                          .copyWith(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Log into you account to continue",
                      style: theme.primaryTextTheme.labelMedium!
                          .copyWith(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 48),
                  TextField(
                    autocorrect: false,
                    style: theme.primaryTextTheme.bodyMedium!.copyWith(
                        fontSize: 18, decoration: TextDecoration.none),
                    onChanged: (value) {
                      setState(() {
                        _emailField = value;
                        validateEmail();
                      });
                    },
                    onSubmitted: (value) {
                      if (_loadingOrFailed != true &&
                          !_invalidEmail &&
                          !_invalidPassword) {
                        _loadingOrFailed = true;
                        appstate
                            .login(_emailField, _passwordField)
                            .then((value) => (setState(() {
                                  if (value) {
                                    _loadingOrFailed = false;
                                  } else {
                                    _loadingOrFailed = null;
                                  }
                                })));
                      }
                    },
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: "Email",
                        hintStyle: theme.textTheme.labelMedium!
                            .copyWith(color: Colors.grey, fontSize: 18)),
                  ),
                  if (_emailField != "" && _invalidEmail)
                    Row(
                      children: [
                        Text("INVALID EMAIL",
                            textAlign: TextAlign.left,
                            style: theme.primaryTextTheme.labelSmall!.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.error)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextField(
                      autocorrect: false,
                      style: theme.primaryTextTheme.bodyMedium!.copyWith(
                          fontSize: 18, decoration: TextDecoration.none),
                      onChanged: (value) {
                        setState(() {
                          _passwordField = value;
                          validatePassword();
                        });
                      },
                      onSubmitted: (value) {
                        if (_loadingOrFailed != true &&
                            !_invalidEmail &&
                            !_invalidPassword) {
                          _loadingOrFailed = true;
                          appstate
                              .login(_emailField, _passwordField)
                              .then((value) => (setState(() {
                                    if (value) {
                                      _loadingOrFailed = false;
                                    } else {
                                      _loadingOrFailed = null;
                                    }
                                  })));
                        }
                      },
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: "Password",
                          hintStyle: theme.textTheme.labelMedium!
                              .copyWith(color: Colors.grey, fontSize: 18),
                          suffixIcon: IconButton(
                              onPressed: () {
                                setState(() =>
                                    (_passwordVisible = !_passwordVisible));
                              },
                              icon: Icon(_passwordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off)))),
                  if (_passwordField != "" && _invalidPassword)
                    Row(
                      children: [
                        Text("INVALID PASSWORD",
                            textAlign: TextAlign.left,
                            style: theme.primaryTextTheme.labelSmall!.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.error)),
                      ],
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary),
                      onPressed: () {
                        if (_loadingOrFailed != true &&
                            !_invalidEmail &&
                            !_invalidPassword) {
                          _loadingOrFailed = true;
                          appstate
                              .login(_emailField, _passwordField)
                              .then((value) => (setState(() {
                                    if (value) {
                                      _loadingOrFailed = false;
                                    } else {
                                      _loadingOrFailed = null;
                                    }
                                  })));
                        }
                      },
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: Center(
                            child: Text("Log In",
                                style: theme.primaryTextTheme.labelLarge!
                                    .copyWith(
                                        color: theme.colorScheme.onPrimary))),
                      )),
                  if (_loadingOrFailed == true)
                    const Center(child: CircularProgressIndicator()),
                  if (_loadingOrFailed == null)
                    Text("Login Failed, please try again",
                        style: theme.textTheme.bodyLarge!
                            .copyWith(color: theme.colorScheme.error))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
