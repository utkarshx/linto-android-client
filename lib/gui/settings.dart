import 'package:flutter/material.dart';
import 'package:linto_flutter_client/logic/maincontroller.dart';
import 'package:linto_flutter_client/logic/userpref.dart';
import 'package:linto_flutter_client/gui/dialogs.dart' show confirmDialog;


class OptionInterface extends StatefulWidget {
  final MainController mainController;

  OptionInterface({Key key, this.mainController}) : super(key: key);

  @override
  _OptionInterface createState() => new _OptionInterface();
}
// TODO: Implement basic option blocks and categories for easy maintenance and additions

class _OptionInterface extends State<OptionInterface> {
  MainController _mainController;
  UserPreferences _userPref;
  double _notif;
  double _speech;

  @override
  void initState() {
    super.initState();
    _mainController = widget.mainController;
    _userPref = _mainController.userPreferences;
    _notif = _userPref.systemPreferences["notificationVolume"] * 100;
    _speech = _userPref.systemPreferences["speechVolume"]  * 100;
  }

  @override
  Widget build(BuildContext context) {
    Orientation orientation = MediaQuery.of(context).orientation;

    return new WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            body: SafeArea(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.only(right: 20, left: 20),
                    child: Column(
                      children: <Widget>[
                        Container(
                          child: Row(
                            children: <Widget>[
                              FlatButton(
                                child: Icon(Icons.arrow_back, size: 48,),
                                onPressed: () => onPop(),
                              ),
                              Spacer(),
                              Text('SETTINGS', style: TextStyle(fontSize: 36),),
                              Spacer(flex: 2,)
                            ],
                          ),
                        ),
                        Container(
                          child: Expanded(
                            child: Flex(
                              mainAxisAlignment: MainAxisAlignment.start,
                              direction: orientation == Orientation.portrait ? Axis.vertical : Axis.horizontal,
                              children: <Widget>[
                                Text('Notification'.padRight(15, ' '), textAlign: TextAlign.left,),
                                Expanded(
                                  child: Slider(value: _notif,
                                    min: 0.0, max: 100.0,
                                    label: _notif.toString(),
                                    onChanged: (value) {setState(() {
                                      _notif = value;
                                    });},
                                  ),
                                  flex: 1,
                                ),
                              ],
                            ),
                          )
                        ),
                        Container(
                          child: Expanded(
                            child: Flex(

                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              direction: orientation == Orientation.portrait ? Axis.vertical : Axis.horizontal,
                              children: <Widget>[
                                Text('Speech'.padRight(17, ' '), textAlign: TextAlign.left, ),
                                Expanded(
                                  child: Slider(value: _speech,
                                      min: 0.0, max: 100.0,
                                      label: _speech.toString(),
                                      onChanged: (value) {setState(() {
                                        _speech = value;
                                      });
                                      }),
                                ),
                              ],
                            ),
                          )
                        ),
                        Container(
                          child: Expanded(
                            child: Flex(
                              mainAxisAlignment: MainAxisAlignment.start,
                              direction: orientation == Orientation.portrait ? Axis.vertical : Axis.horizontal,
                              children: <Widget>[
                                Text('Language'.padRight(15, ' '), textAlign: TextAlign.left, ),
                                Expanded(
                                    child: DropdownButton<String>(
                                      value: 'fr-FR',
                                      items: <String>['fr-FR',].map((String value) {
                                        return new DropdownMenuItem(
                                            value: value,
                                            child: new Text(value)
                                        );
                                      }).toList(),
                                      onChanged: (_) {},
                                    )
                                ),
                              ],
                            ),
                          )
                        ),
                        Container(
                            child: Expanded(
                              child: Flex(
                                mainAxisAlignment: MainAxisAlignment.start,
                                direction: orientation == Orientation.portrait ? Axis.vertical : Axis.horizontal,
                                children: <Widget>[
                                  Text('Application'.padRight(15, ' '), textAlign: TextAlign.left, ),
                                  Expanded(
                                      child: DropdownButton<String>(
                                        value: 'default',
                                        items: <String>['default', 'personnel'].map((String value) {
                                          return new DropdownMenuItem(
                                              value: value,
                                              child: new Text(value)
                                          );
                                        }).toList(),
                                        onChanged: (_) {},
                                      )
                                  ),
                                ],
                              ),
                            )
                        ),
                        sysInfo(_mainController),
                        Container(
                          child: Row(
                            children: <Widget>[
                              Spacer(),
                              FlatButton(
                                child: Row(
                                  children: <Widget>[
                                    Icon(Icons.person, size: 48,),
                                    Text("Disconnect")
                                  ],
                                ),
                                onPressed: () async => onDisconnect(context),
                              )
                            ],
                          ),
                        )

                      ],
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                    ),
                  )
                )
            )
        )
    );
  }

  Future onPop() async {
    _userPref.systemPreferences["notificationVolume"] = _notif / 100;
    _userPref.systemPreferences["speechVolume"] = _speech / 100;
    _userPref.updatePrefs();
    Navigator.pop(context, false);
  }

  void onDisconnect(BuildContext context) async {
    confirmDialog(context, "Disconnect ?").then((bool toDisconnect) {
      if (toDisconnect) {
        _userPref.clientPreferences["keep_info"] = false;
        _userPref.updatePrefs();
        Navigator.pop(context, true);
      }
    });
  }
  }

Container sysInfo(MainController controller) {
  Map<String, String> entryKeys = {
    'Login': controller.client.login,
    'Server': controller.client.server,
    'Scope' : controller.client.currentScope};

  return Container(
    child: Column(
      children: entryKeys.entries.map((e) => SysInfoEntry(e.key, e.value)).toList(),
    ),
    padding: EdgeInsets.only(left: 20, right: 20),
    color: Colors.black12,
  );
}

Container SysInfoEntry (String key, String value) {
  return Container(
    child: Row(
      children: <Widget>[
        Text(key.padRight(10, ' ') ,style: TextStyle(fontWeight: FontWeight.bold),),
        Text(value)
      ],
    ),
  );
}