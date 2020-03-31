import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import "dart:collection";
import "dart:async";
import "dart:io";
import "package:intl/intl.dart";
import "dart:convert";
import "package:web_socket_channel/io.dart";
import "package:http/http.dart" as http;
import "package:url_launcher/url_launcher.dart";
import "package:path_provider/path_provider.dart";
import "package:local_database/local_database.dart";
import "package:auto_size_text/auto_size_text.dart";
import "dart:math";
import "package:syncfusion_flutter_charts/charts.dart";
import "package:syncfusion_flutter_core/core.dart";
import "image_keys.dart";
import "key.dart";
import "package:flutter_svg/flutter_svg.dart";

String _api = "https://api.coincap.io/v2/";
HashMap<String,Map<String,dynamic>> _coinData;
HashMap<String, ValueNotifier<num>> _valueNotifiers = new HashMap<String, ValueNotifier<num>>();
List<String> _savedCoins;
Database _userData;
Map<String,dynamic> _settings;
String _symbol;
Map<String, String> _currencySymbolMap = {
  "USD":"\$",
  "AUD":"A\$",
  "BGN":"Лв. ",
  "BRL":"R\$",
  "CAD": "C\$",
  "CHF": "Fr. ",
  "CNY": "¥",
  "CZK": "Kč",
  "DKK": "kr. ",
  "EUR": "€",
  "GBP": "£",
  "HKD": "HK\$",
  "HRK": "kn ",
  "HUF": "Ft ",
  "IDR": "Rp ",
  "ILS": "₪",
  "INR": "₹",
  "ISK": "kr ",
  "JPY": "¥",
  "KRW": "₩",
  "MXN": "\$",
  "MYR": "RM",
  "NOK": "kr ",
  "NZD": "\$",
  "PHP": "₱",
  "PLN": "zł",
  "RON": "lei ",
  "RUB": "₽",
  "SEK": "kr ",
  "SGD": "S\$",
  "THB": "฿",
  "TRY": "₺",
  "ZAR": "R "
};
Map<String, double> _exchangeRates;
double _exchangeRate;

bool _loading = false;

Future<dynamic> _apiGet(String link) async{
  return json.decode((await http.get(Uri.encodeFull("$_api$link"))).body);
}

void _changeCurrency(String currency){
  _exchangeRate = _exchangeRates[_settings["currency"]];
  _symbol = _currencySymbolMap[_settings["currency"]];
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  SyncfusionLicense.registerLicense(key);
  _userData = new Database((await getApplicationDocumentsDirectory()).path);
  _savedCoins = (await _userData["saved"])?.cast<String>() ?? [];
  _settings = await _userData["settings"];
  if(_settings==null){
    _settings = {
      "disableGraphs":false,
      "currency":"USD"
    };
    _userData["settings"] = _settings;
  }
  _exchangeRates = json.decode((await http.get("https://api.exchangeratesapi.io/latest?base=USD")).body)["rates"].cast<String,double>();
  _changeCurrency(_settings["currency"]);
  _coinData = new HashMap<String,Map<String,Comparable>>();
  runApp(new App());
}

class App extends StatefulWidget{
  @override
  _AppState createState() => new _AppState();
}

class _AppState extends State<App> {

  @override
  void initState(){
    super.initState();
    setUpData();
  }

  IOWebSocketChannel socket;

  Future<void> setUpData() async{
    _coinData = new HashMap<String,Map<String,Comparable>>();
    _loading = true;
    setState((){});
    var data = (await _apiGet("assets?limit=2000"))["data"];
    data.forEach((e){
      String id = e["id"];
      _coinData[id] = e.cast<String,Comparable>();
      _valueNotifiers[id] = new ValueNotifier(0);
      for(String s in e.keys){
        if(e[s]==null){
          e[s]=(s=="changePercent24Hr"?-1000000:-1);
        }else if(!["id","symbol","name"].contains(s)){
          e[s] = num.parse(e[s]);
        }
      }
    });
    _loading = false;
    setState((){});
    socket?.sink?.close();
    socket = new IOWebSocketChannel.connect("wss://ws.coincap.io/prices?assets=ALL");
    socket.stream.listen((message){
      Map<String,dynamic> data = json.decode(message);
      data.forEach((s,v){
        if(_coinData[s]!=null){
          num old = _coinData[s]["priceUsd"];
          _coinData[s]["priceUsd"]=num.parse(v)??-1;
          _valueNotifiers[s].value = old;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[700]
      ),
      debugShowCheckedModeBanner: false,
      home: new ListPage(true)
    );
  }
}

String sortingBy;

class ListPage extends StatefulWidget {

  final bool savedPage;

  ListPage(this.savedPage) : super(key:new ValueKey(savedPage));

  @override
  _ListPageState createState() => new _ListPageState();
}

typedef SortType(String s1, String s2);

SortType sortBy(String s){
  String sortVal = s.substring(0,s.length-1);
  bool ascending = s.substring(s.length-1).toLowerCase()=="a";
  return (s1,s2){
    if(s=="custom"){
      return _savedCoins.indexOf(s1)-_savedCoins.indexOf(s2);
    }
    Map<String,Comparable> m1 = _coinData[ascending?s1:s2], m2 = _coinData[ascending?s2:s1];
    dynamic v1 = m1[sortVal], v2 = m2[sortVal];
    if(sortVal=="name"){
      v1 = v1.toUpperCase();
      v2 = v2.toUpperCase();
    }
    int comp = v1.compareTo(v2);
    if(comp==0){
      return sortBy("nameA")(s1,s2) as int;
    }
    return comp;
  };
}

class _ListPageState extends State<ListPage> {

  bool searching = false;

  List<String> sortedKeys;
  String prevSearch = "";

  void reset(){
    if(widget.savedPage){
      sortedKeys = new List.from(_savedCoins)..sort(sortBy(sortingBy));
    }else{
      sortedKeys = new List.from(_coinData.keys)..sort(sortBy(sortingBy));
    }
    setState((){});
  }

  void search(String s){
    scrollController.jumpTo(0.0);
    reset();
    moving = false;
    moveWith = null;
    for(int i = 0; i<sortedKeys.length; i++){
      String key = sortedKeys[i];
      String name = _coinData[key]["name"];
      String ticker = _coinData[key]["symbol"];
      if(![name,ticker].any((w)=>w.toLowerCase().contains(s.toLowerCase()))){
        sortedKeys.removeAt(i--);
      }
    }
    prevSearch = s;
    setState((){});
  }

  void sort(String s){
    scrollController.jumpTo(0.0);
    moving = false;
    moveWith = null;
    sortingBy = s;
    setState(() {
      sortedKeys.sort(sortBy(s));
    });
  }

  @override
  void initState(){
    super.initState();
    sortingBy = widget.savedPage?"custom":"marketCapUsdD";
    reset();
  }

  Timer searchTimer;
  ScrollController scrollController = new ScrollController();

  @override
  Widget build(BuildContext context){
    List<PopupMenuItem> l = [
      new PopupMenuItem<String>(
          child: const Text("Name Ascending"), value: "nameA"),
      new PopupMenuItem<String>(
          child: const Text("Name Descending"), value: "nameD"),
      new PopupMenuItem<String>(
          child: const Text("Price Ascending"), value: "priceUsdA"),
      new PopupMenuItem<String>(
          child: const Text("Price Descending"), value: "priceUsdD"),
      new PopupMenuItem<String>(
          child: const Text("Market Cap Ascending"), value: "marketCapUsdA"),
      new PopupMenuItem<String>(
          child: const Text("Market Cap Descending"), value: "marketCapUsdD"),
      new PopupMenuItem<String>(
          child: const Text("24H Change Ascending"), value: "changePercent24HrA"),
      new PopupMenuItem<String>(
          child: const Text("24H Change Descending"), value: "changePercent24HrD")
    ];
    if(widget.savedPage){
      l.insert(0, new PopupMenuItem<String>(
          child: const Text("Custom"), value: "custom")
      );
    }
    Widget ret = new Scaffold(
      drawer: widget.savedPage?new Drawer(
        child: new ListView(
          children: [
            new GestureDetector(
              child: new Container(
                color: Colors.black,
                height:MediaQuery.of(context).size.height/5,
                child: new Image.asset("icon/platypus.png"),
              ),
              onTap: () async{
                String url = "https://platypuslabs.llc";
                if(await canLaunch(url)) {
                  await launch(url);
                }
              }
            ),
            new ListTile(
              leading: new Icon(Icons.import_export),
              title: new Text("Import/Export Favorites", style: new TextStyle(fontSize:16.0)),
              onTap: (){
                if(!_loading){
                  _didImport = false;
                  Navigator.push(context, new MaterialPageRoute(builder: (context) => new ImpExpPage())).then((f){
                    if(_didImport){
                      _didImport = false;
                      searching = false;
                      reset();
                    }
                    setState((){});
                  });
                }
              }
            ),
            new ListTile(
                leading: new Icon(Icons.settings),
                title: new Text("Settings",style: new TextStyle(fontSize:16.0)),
                onTap: (){
                  if(!_loading){
                    Navigator.push(context,new MaterialPageRoute(builder: (context) => new Settings()));
                  }
                }
            ),
            new ListTile(
                leading: new Icon(Icons.mail),
                title: new Text("Contact Us",style: new TextStyle(fontSize:16.0)),
                onTap: () async{
                  String url = Uri.encodeFull("mailto:support@platypuslabs.llc?subject=GetPass&body=Contact Reason: ");
                  if(await canLaunch(url)) {
                    await launch(url);
                  }
                }
            ),
            new ListTile(
                leading: new Icon(Icons.star),
                title: new Text("Rate Us",style: new TextStyle(fontSize:16.0)),
                onTap: () async{
                  String url = Platform.isIOS?"https://itunes.apple.com/us/app/platypus-crypto/id1397122793":"https://play.google.com/store/apps/details?id=land.platypus.cryptotracker";
                  if(await canLaunch(url)) {
                    await launch(url);
                  }
                }
            )
          ]
        ),
        key: new ValueKey(widget.savedPage)
      ):null,
      appBar: new AppBar(
        bottom: _loading?new PreferredSize(preferredSize: new Size(double.infinity,3.0),child: new Container(height:3.0, child: new LinearProgressIndicator())):null,
        title: searching?new TextField(
            autocorrect: false,
            autofocus: true,
            decoration: new InputDecoration(
                hintText: "Search",
                hintStyle: new TextStyle(color:Colors.white),
                border: InputBorder.none
            ),
            style:new TextStyle(color:Colors.white),
            onChanged:(s){
              searchTimer?.cancel();
              searchTimer = new Timer(new Duration(milliseconds: 500),(){
                search(s);
              });
            },
            onSubmitted: (s){
              search(s);
            }
        ):new Text(widget.savedPage?"Favorites":"All Coins"),
        actions: [
          new IconButton(
              icon: new Icon(searching?Icons.close:Icons.search),
              onPressed: (){
                if(_loading){
                  return;
                }
                setState((){
                  if(searching){
                    searching = false;
                    reset();
                  }else{
                    searching = true;
                  }
                });
              }
          ),
          new Container(
              width:35.0,
              child: new PopupMenuButton(
                  itemBuilder: (BuildContext context)=>l,
                  child: new Icon(Icons.sort),
                  onSelected:(s){
                    if(_loading){
                      return;
                    }
                    sort(s);
                  }
              )
          ),
          new IconButton(
              icon: new Icon(Icons.refresh),
              onPressed: () async{
                if(_loading){
                  return;
                }
                searching = false;
                sortingBy = widget.savedPage?"custom":"marketCapUsdD";
                await context.findAncestorStateOfType<_AppState>().setUpData();
                reset();
              }
          )
        ],
      ),
      body: !_loading?new Scrollbar(
          child: new ListView.builder(
              itemBuilder: (context, i)=>new Crypto(sortedKeys[i], widget.savedPage),
              itemCount: sortedKeys.length,
              controller: scrollController
          )
      ):new Container(),
      floatingActionButton: widget.savedPage?!_loading?new FloatingActionButton(
        onPressed: (){
          moving = false;
          moveWith = null;
          Navigator.push(context,new MaterialPageRoute(builder: (context) => new ListPage(false))).then((d){
            sortingBy = "custom";
            searching = false;
            reset();
            scrollController.jumpTo(0.0);
          });
        },
        child: new Icon(
            Icons.add
        ),
        heroTag: "newPage"
      ):null:new FloatingActionButton(
          onPressed: (){
            scrollController.jumpTo(0.0);
          },
          child: new Icon(
              Icons.arrow_upward
          ),
          heroTag: "jump"
      )
    );
    if(!widget.savedPage){
      ret = new WillPopScope(
          child: ret,
          onWillPop: ()=>new Future<bool>(()=>!_loading)
      );
    }
    return ret;
  }
}

bool _didImport = false;

class ImpExpPage extends StatefulWidget{
  @override
  ImpExpPageState createState() => new ImpExpPageState();
}

class ImpExpPageState extends State<ImpExpPage>{
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text("Import/Export")),
      body: new Builder(
        builder: (context)=>new Container(
            child: new Padding(
                padding: EdgeInsets.only(top:20.0,right:15,left:15),
                child: new ListView(
                    physics: new ClampingScrollPhysics(),
                    children: [
                      new Card(
                        color: Colors.black12,
                        child: new ListTile(
                            title: new Text("Export Favorites"),
                            subtitle: new Text("To your clipboard"),
                            trailing: new Icon(Icons.file_upload),
                            onTap: () async{
                              await Clipboard.setData(new ClipboardData(text:json.encode(_savedCoins)));
                              Scaffold.of(context).removeCurrentSnackBar();
                              Scaffold.of(context).showSnackBar(new SnackBar(duration: new Duration(milliseconds: 1000),content: new Text("Copied to clipboard",style:new TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
                            }
                        ),
                        margin: EdgeInsets.zero,
                      ),
                      new Container(height:20),
                      new Card(
                        color: Colors.black12,
                        child: new ListTile(
                            title: new Text("Import Favorites"),
                            subtitle: new Text("From your clipboard"),
                            trailing: new Icon(Icons.file_download),
                            onTap: () async{
                              String str = (await Clipboard.getData("text/plain")).text;
                              try{
                                List<String> data = json.decode(str).cast<String>();
                                 for(int i = 0; i<data.length;i++){
                                  if(_coinData[data[i]]==null){
                                    data.removeAt(i--);
                                  }
                                }
                                _savedCoins = data;
                                _userData["saved"] = data;
                                _didImport = true;
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(new SnackBar(duration: new Duration(milliseconds: 1000),content: new Text("Imported",style:new TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
                              }catch(e){
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(new SnackBar(duration: new Duration(milliseconds: 1000),content: new Text("Invalid data",style:new TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
                              }
                            }
                        ),
                        margin: EdgeInsets.zero,
                      ),
                    ]
                )
            )
        )
      )
    );
  }
}

class Settings extends StatefulWidget{
  @override
  SettingsState createState() => new SettingsState();
}

class SettingsState extends State<Settings>{

  @override
  Widget build(BuildContext context){
    return new Scaffold(
        appBar: new AppBar(title:new Text("Settings",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold)),backgroundColor: Colors.black54),
        body: new Padding(
            padding: EdgeInsets.only(top:20.0,right:15,left:15),
            child: new ListView(
                physics: new ClampingScrollPhysics(),
                children: [
                  new Card(
                    color: Colors.black12,
                    child: new ListTile(
                        title: new Text("Disable 7 day graphs"),
                        subtitle: new Text("More compact cards"),
                        trailing: new Switch(
                            value: _settings["disableGraphs"],
                            onChanged: (disp){
                              setState((){
                                _settings["disableGraphs"] = !_settings["disableGraphs"];
                              });
                              _userData["settings/disableGraphs"] = _settings["disableGraphs"];
                            }
                        ),
                        onTap: (){
                          setState((){
                            _settings["disableGraphs"] = !_settings["disableGraphs"];
                          });
                          _userData["settings/disableGraphs"] = _settings["disableGraphs"];
                        }
                    ),
                    margin: EdgeInsets.zero,
                  ),
                  new Container(height:20),
                  new Card(
                    color: Colors.black12,
                    child: new ListTile(
                        title: new Text("Change Currency"),
                        subtitle: new Text("33 fiat currency options"),
                        trailing: new Padding(
                            child: new Container(
                                color: Colors.white12,
                                padding: EdgeInsets.only(right:7.0,left:7.0),
                                child: new DropdownButtonHideUnderline(
                                    child: new DropdownButton<String>(
                                        value: _settings["currency"],
                                        onChanged: (s){
                                          _settings["currency"] = s;
                                          _changeCurrency(s);
                                          _userData["settings/currency"] = s;
                                          context.findAncestorStateOfType<_AppState>().setState((){});
                                        },
                                        items: _currencySymbolMap.keys.map((s)=>new DropdownMenuItem(
                                            value:s,
                                            child: new Text(s+" "+_currencySymbolMap[s])
                                        )).toList()
                                    )
                                )
                            ),
                            padding: EdgeInsets.only(right:10.0)
                        )
                    ),
                    margin: EdgeInsets.zero,
                  )
                ]
            )
        )
    );
  }
}

bool moving = false;
String moveWith;

class Crypto extends StatefulWidget{

  final String id;
  final bool savedPage;

  Crypto(this.id, this.savedPage) : super(key: new ValueKey(id+savedPage.toString()));

  @override
  _CryptoState createState() => new _CryptoState();
}

class _CryptoState extends State<Crypto>{

  bool saved;
  Color changeColor;
  Timer updateTimer;
  Map<String,Comparable> data;
  ValueNotifier<num> coinNotif;
  bool disp = false;

  void update(){
    if(data["priceUsd"].compareTo(coinNotif.value)>0){
      changeColor = Colors.green;
    }else{
      changeColor = Colors.red;
    }
    setState((){});
    updateTimer?.cancel();
    updateTimer = new Timer(new Duration(milliseconds: 400),(){
      if(disp){
        return;
      }
      setState(() {
        changeColor = null;
      });
    });
  }

  @override
  void initState(){
    super.initState();
    data = _coinData[widget.id];
    coinNotif = _valueNotifiers[widget.id];
    saved = _savedCoins.contains(widget.id);
    coinNotif.addListener(update);
  }

  @override
  void dispose(){
    super.dispose();
    disp = true;
    coinNotif.removeListener(update);
  }

  void move(List<String> coins){
    int moveTo = coins.indexOf(widget.id);
    int moveFrom = coins.indexOf(moveWith);
    coins.removeAt(moveFrom);
    coins.insert(moveTo, moveWith);
  }

  @override
  Widget build(BuildContext context){
    double width = MediaQuery.of(context).size.width;
    num price = data["priceUsd"];
    price*=_exchangeRate;
    num mCap = data["marketCapUsd"];
    mCap*=_exchangeRate;
    num change = data["changePercent24Hr"];
    String shortName = data["symbol"];
    return new Container(
      height: !_settings["disableGraphs"]?120.0:100.0,
      padding: EdgeInsets.only(top:10.0),
      child: new GestureDetector(
        onLongPress: (){
          if(sortingBy=="custom"){
            context.findAncestorStateOfType<_ListPageState>().setState((){
              moving = true;
              moveWith = widget.id;
            });
          }else if(!widget.savedPage){
            Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.id)));
          }
        },
        child: new Dismissible(
            background: new Container(color:Colors.red),
            key: new ValueKey(widget.id),
            direction: DismissDirection.endToStart,
            onDismissed: (d){
              _savedCoins.remove(widget.id);
              _userData["saved"] = _savedCoins;
              context.findAncestorStateOfType<_ListPageState>().sortedKeys.remove(widget.id);
              context.findAncestorStateOfType<_ListPageState>().setState((){});
            },
            child: new FlatButton(
              onPressed: (){
                if(widget.savedPage){
                  if(moving){
                    move(_savedCoins);
                    move(context.findAncestorStateOfType<_ListPageState>().sortedKeys);
                    setState((){
                      moveWith = null;
                      moving = false;
                    });
                    context.findAncestorStateOfType<_ListPageState>().setState((){});
                    _userData["saved"] = _savedCoins;
                  }else{
                    Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.id)));
                  }
                }else{
                  setState((){
                    if(saved){
                      saved = false;
                      _savedCoins.remove(widget.id);
                      _userData["saved"] = _savedCoins;
                    }else{
                      saved = true;
                      _savedCoins.add(widget.id);
                      _userData["saved"] = _savedCoins;
                    }
                  });
                }
              },
              padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
              color: saved&&moveWith!=widget.id?Colors.black45:Colors.black26,
              child: new Row(
                children: [
                  new Expanded(child: new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        new Row(
                            children: [
                              new ConstrainedBox(
                                constraints: new BoxConstraints(
                                  maxWidth: width/3
                                ),
                                child: new AutoSizeText(
                                    data["name"],
                                    maxLines: 2,
                                    minFontSize: 0.0,
                                    maxFontSize: 17.0,
                                    style: new TextStyle(fontSize:17.0)
                                )
                              )
                            ]
                        ),
                        new Container(height:5.0),
                        new Row(
                            children: [
                              new FadeInImage(
                                  image: !blacklist.contains(widget.id)?new NetworkImage("https://static.coincap.io/assets/icons/${shortName.toLowerCase()}@2x.png"):new AssetImage("icon/platypus2.png"),
                                  placeholder: new AssetImage("icon/platypus2.png"),
                                  fadeInDuration: const Duration(milliseconds:100),
                                  height:32.0,
                                  width:32.0
                              ),
                              new Container(width:4.0),
                              new ConstrainedBox(
                                  constraints: new BoxConstraints(
                                    maxWidth: width/3-40
                                  ),
                                  child: new AutoSizeText(
                                      shortName,
                                      maxLines: 1
                                  )
                              )
                            ]
                        )
                      ]
                  )),
                  new Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        new Text((price>=0?price>1?_symbol+new NumberFormat.currency(symbol:"",decimalDigits: price<100000?2:0).format(price):_symbol+(price>.000001?price.toStringAsFixed(6):price.toStringAsFixed(7)):"N/A"),style: new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold, color: changeColor)),
                        new Text((mCap>=0?mCap>1?_symbol+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(mCap):_symbol+mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:Colors.grey,fontSize:12.0)),
                        !_settings["disableGraphs"]?linkMap[shortName]!=null&&!blacklist.contains(widget.id)?new SvgPicture.network(
                          "https://www.coingecko.com/coins/${linkMap[shortName] ?? linkMap[widget.id]}/sparkline",
                          placeholderBuilder: (BuildContext context) => new Container(
                            width:0,
                            height:35.0
                          ),
                          width:105.0,
                          height:35.0
                        ):new Container(height:35.0):new Container(),
                      ]
                  ),
                  new Expanded(
                      child: new Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          change!=-1000000.0?new Text(((change>=0)?"+":"")+change.toStringAsFixed(3)+"\%",style:new TextStyle(color:((change>=0)?Colors.green:Colors.red))):new Text("N/A"),
                          new Container(width:2),
                          !widget.savedPage?new Icon(saved?Icons.check:Icons.add):new Container()
                        ]
                      )
                  )
                ],
              ),
            )
        )
      )
    );
  }
}

class ItemInfo extends StatefulWidget{

  final String id;

  ItemInfo(this.id);

  @override
  _ItemInfoState createState() => new _ItemInfoState();
}

class _ItemInfoState extends State<ItemInfo>{

  ValueNotifier<num> coinNotif;

  Color changeColor;

  Timer updateTimer;

  bool disp = false;

  Map<String,dynamic> data;

  void update(){
    if(data["priceUsd"].compareTo(coinNotif.value)>0){
      changeColor = Colors.green;
    }else{
      changeColor = Colors.red;
    }
    setState((){});
    updateTimer?.cancel();
    updateTimer = new Timer(new Duration(milliseconds: 400),(){
      if(disp){
        return;
      }
      setState(() {
        changeColor = null;
      });
    });
  }

  @override
  void initState(){
    super.initState();
    coinNotif = _valueNotifiers[widget.id];
    coinNotif.addListener(update);
    data = _coinData[widget.id];
  }

  @override
  void dispose(){
    super.dispose();
    disp = true;
    coinNotif.removeListener(update);
  }

  @override
  Widget build(BuildContext context){
    num price = (_coinData[widget.id]["priceUsd"]*_exchangeRate);
    num mCap = (_coinData[widget.id]["marketCapUsd"]*_exchangeRate);
    num change = _coinData[widget.id]["changePercent24Hr"];
    return new DefaultTabController(
        length:5,
        child: new Scaffold(
            appBar:new AppBar(
                title:new Text(data["name"],style:new TextStyle(fontSize:25.0)),
                backgroundColor: Colors.black54,
                actions: [
                  new Row(
                      children: [
                        new FadeInImage(
                          image: new NetworkImage("https://static.coincap.io/assets/icons/${data["symbol"].toLowerCase()}@2x.png"),
                          placeholder: new AssetImage("icon/platypus2.png"),
                          fadeInDuration: const Duration(milliseconds:100),
                          height:32.0,
                          width:32.0,
                        ),
                        new Text(" "+data["symbol"]),
                        new Container(width:5.0)
                      ]
                  )
                ]
            ),
            body:new ListView(
                physics: new ClampingScrollPhysics(),
                children:[
                  new Container(
                      color: Colors.black54,
                      child: new TabBar(
                          tabs: [
                            new Tab(icon: new AutoSizeText(
                              "1D",
                              maxFontSize: 25.0,
                              style: new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            new Tab(icon: new AutoSizeText(
                              "1W",
                              maxFontSize: 25.0,
                              style: new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            new Tab(icon: new AutoSizeText(
                              "1M",
                              maxFontSize: 25.0,
                              style: new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            new Tab(icon: new AutoSizeText(
                              "6M",
                              maxFontSize: 25.0,
                              style: new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            new Tab(icon: new AutoSizeText(
                              "1Y",
                              maxFontSize: 25.0,
                              style: new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            ))
                          ]
                      )
                  ),
                  new Container(height:15.0),
                  new Container(
                      height: 200.0,
                      padding: EdgeInsets.only(right:10.0),
                      child: new TabBarView(
                          physics: new NeverScrollableScrollPhysics(),
                          children: [
                            new SimpleTimeSeriesChart(widget.id,1,"m5"),
                            new SimpleTimeSeriesChart(widget.id,7,"m30"),
                            new SimpleTimeSeriesChart(widget.id,30,"h2"),
                            new SimpleTimeSeriesChart(widget.id,182,"h12"),
                            new SimpleTimeSeriesChart(widget.id,364,"d1")
                          ]
                      )
                  ),
                  new Container(height:10.0),
                  /*new Column(
                    children: ["supply","maxSupply","marketCapUsd","volumeUsd24Hr","priceUsd","changePercent24Hr","vwap24Hr"].map((s)=>new Info(s,_coinData[widget.id][s].toString())).toList()
                  ),*/
                  new Row(
                      children: [
                        //(mCap>=0?mCap>1?_symbol+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(mCap):_symbol+mCap.toStringAsFixed(2):"N/A")
                        new Expanded(child: new Info("Price",price,price>=0?price>1?price<100000?2:0:price>.000001?6:7:null,true,new TextStyle(color:changeColor))),
                        new Expanded(child:new Info("Market Cap",mCap,mCap>=0?mCap>1?0:2:null,true))
                      ]
                  ),
                  new Row(
                      children: [
                        new Expanded(child:new Info("Supply",_coinData[widget.id]["supply"],0)),
                        new Expanded(child:new Info("Max Supply",_coinData[widget.id]["maxSupply"],0)),
                      ]
                  ),
                  new Row(
                      children: [
                        new Expanded(child:new Info("24h Change",change,3,false,new TextStyle(color:change<0?Colors.red:change>0?Colors.green:Colors.white))),
                        new Expanded(child:new Info("24h Volume",_coinData[widget.id]["volumeUsd24Hr"],0))
                      ]
                  ),
                ]
            )
        )
    );
  }
}

class Info extends StatefulWidget{

  final String title;
  final dynamic value;
  final TextStyle valueStyle;
  final int digits;
  final bool currency;

  Info(this.title,this.value,[this.digits,this.currency=false,this.valueStyle=const TextStyle()]);

  @override
  _InfoState createState() => new _InfoState();
}

class _InfoState extends State<Info>{

  NumberFormat formatter;

  @override
  void initState(){
    super.initState();
    formatter = new NumberFormat.currency(symbol: widget.currency?_symbol:"", decimalDigits: widget.digits);
  }

  @override
  Widget build(BuildContext context){
    String text;
    if((widget.title=="24h Change"&&widget.value==-1000000)||widget.value==null||widget.value==-1){
      text = "N/A";
    }else if(widget.digits!=null){
      text = formatter.format(widget.value);
    }else{
      text = widget.value.toString();
    }
    if(widget.title=="24h Change"&&widget.value!=-1000000){
      text+="%";
      text = (widget.value>0?"+":"")+text;
    }
    return new Container(
        padding: EdgeInsets.only(top:2.0, left:2.0, right:2.0),
        child: new Card(
          child: new Container(
            height: 60.0,
            color: Colors.black45,
            padding: EdgeInsets.only(top:10.0,bottom:10.0),
            child: new Column(
                children: [
                  new Text(widget.title,textAlign: TextAlign.left, style:new TextStyle(fontSize:17, fontWeight: FontWeight.bold)),
                  new ConstrainedBox(
                    child: new AutoSizeText(
                        text,
                        minFontSize: 0,
                        maxFontSize: 17,
                        style: text!="N/A"?widget.valueStyle.copyWith(fontSize: 17):new TextStyle(fontSize:17),
                        maxLines: 1
                    ),
                    constraints: new BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width/2-8
                    ),
                  )
                ]
            )
          )
        )
    );
  }
}

class TimeSeriesPrice {
  final DateTime time;
  final double price;

  TimeSeriesPrice(this.time, this.price);
}

class SimpleTimeSeriesChart extends StatefulWidget{

  final String period, id;

  final int startTime;

  SimpleTimeSeriesChart(this.id,this.startTime,this.period);

  @override
  _SimpleTimeSeriesChartState createState() => new _SimpleTimeSeriesChartState();
}

class _SimpleTimeSeriesChartState extends State<SimpleTimeSeriesChart> {
  List<TimeSeriesPrice> seriesList;
  double count = 0.0;
  double selectedPrice = -1.0;
  DateTime selectedTime;
  bool canLoad = true, loading = true;
  int base;
  num minVal, maxVal;

  @override
  void initState(){
    super.initState();
    DateTime now = new DateTime.now();
    http.get(Uri.encodeFull("https://api.coincap.io/v2/assets/${widget.id}/history?interval="+widget.period+"&start="+now.subtract(new Duration(days:widget.startTime)).millisecondsSinceEpoch.toString()+"&end="+now.millisecondsSinceEpoch.toString())).then((value){
      seriesList = createChart(json.decode(value.body),widget.id);
      setState((){
        loading = false;
      });
    });
    num price = _coinData[widget.id]["priceUsd"]*_exchangeRate;
    base = price>=0?max(0,(-log(price)/log(10)).ceil()+2):0;
    if(price<=1.1&&price>.9){
      base++;
    }
  }

  Map<String,int> dataPerDay = {
    "m5":288,
    "m30":48,
    "h2":12,
    "h12":2,
    "d1":1
  };

  @override
  Widget build(BuildContext context){
    bool hasData = seriesList!=null&&seriesList.length>(widget.startTime*dataPerDay[widget.period]/10);
    return !loading&&canLoad&&hasData?new Container(width: 350.0*MediaQuery.of(context).size.width/375.0,
        height:200.0,
        child: new SfCartesianChart(
          series: [
            new LineSeries<TimeSeriesPrice,DateTime>(
                dataSource: seriesList,
                xValueMapper: (TimeSeriesPrice s,_)=>s.time,
                yValueMapper: (TimeSeriesPrice s,_)=>s.price,
                animationDuration: 0,
                color: Colors.blue
            )
          ],
          plotAreaBackgroundColor: Colors.transparent,
          primaryXAxis: new DateTimeAxis(
              dateFormat: widget.startTime==1?new DateFormat("h꞉mm a"):null
          ),
          primaryYAxis: new NumericAxis(
              numberFormat: new NumberFormat.currency(symbol:_symbol.toString().replaceAll("\.", ""),locale:"en_US",decimalDigits:base),
              maximum: maxVal+(maxVal-minVal)*.1,
              minimum: minVal-(maxVal-minVal)*.1
          ),
          selectionGesture: ActivationMode.singleTap,
          selectionType: SelectionType.point,
          trackballBehavior: new TrackballBehavior(
            activationMode: ActivationMode.singleTap,
            enable: true,
            shouldAlwaysShow: true,
            tooltipSettings: new InteractiveTooltip(
                color: Colors.white,
                format: "point.x | point.y"
            )
          )
        )
    ):canLoad&&(hasData||loading)?new Container(
        height:233.0,
        padding:EdgeInsets.only(left:10.0,right:10.0),
        child:new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            new CircularProgressIndicator()
          ]
        )
    ):new Container(
        height:233.0,
        child: new Center(
            child: new Text("Sorry, this coin graph is not supported",style: new TextStyle(fontSize:17.0))
        )
    );
  }

List<TimeSeriesPrice> createChart(Map<String,dynamic> info, String s) {

    List<TimeSeriesPrice> data = [];

    if(info!=null&&info.length>1){
      for(int i = 0;i<info["data"].length;i++){
        num val = num.parse(info["data"][i]["priceUsd"])*_exchangeRate;
        minVal = min(minVal??val,val);
        maxVal = max(maxVal??val,val);
        data.add(new TimeSeriesPrice(new DateTime.fromMillisecondsSinceEpoch(info["data"][i]["time"]), val));
      }
    }else{
      canLoad = false;
    }
    return data;
  }
}