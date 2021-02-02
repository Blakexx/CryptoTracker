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
HashMap<String, ValueNotifier<num>> _valueNotifiers = HashMap<String, ValueNotifier<num>>();
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
  _userData = Database((await getApplicationDocumentsDirectory()).path);
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
  _coinData = HashMap<String,Map<String,Comparable>>();
  runApp(App());
}

class App extends StatefulWidget{
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {

  @override
  void initState(){
    super.initState();
    setUpData();
  }

  IOWebSocketChannel socket;

  Future<void> setUpData() async{
    _coinData = HashMap<String,Map<String,Comparable>>();
    _loading = true;
    setState((){});
    var data = (await _apiGet("assets?limit=2000"))["data"];
    data.forEach((e){
      String id = e["id"];
      _coinData[id] = e.cast<String,Comparable>();
      _valueNotifiers[id] = ValueNotifier(0);
      for(String s in e.keys){
        if(e[s]==null){
          e[s]=(s=="changePercent24Hr"?-1000000:-1);
        }else if(!["id","symbol","name"].contains(s)){
          e[s] = num.parse(e[s], (e) => null);
        }
      }
    });
    _loading = false;
    setState((){});
    socket?.sink?.close();
    socket = IOWebSocketChannel.connect("wss://ws.coincap.io/prices?assets=ALL");
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
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[700]
      ),
      debugShowCheckedModeBanner: false,
      home: ListPage(true)
    );
  }
}

String sortingBy;

class ListPage extends StatefulWidget {

  final bool savedPage;

  ListPage(this.savedPage) : super(key:ValueKey(savedPage));

  @override
  _ListPageState createState() => _ListPageState();
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
      sortedKeys = List.from(_savedCoins)..sort(sortBy(sortingBy));
    }else{
      sortedKeys = List.from(_coinData.keys)..sort(sortBy(sortingBy));
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
  ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context){
    List<PopupMenuItem> l = [
      PopupMenuItem<String>(
          child: const Text("Name Ascending"), value: "nameA"),
      PopupMenuItem<String>(
          child: const Text("Name Descending"), value: "nameD"),
      PopupMenuItem<String>(
          child: const Text("Price Ascending"), value: "priceUsdA"),
      PopupMenuItem<String>(
          child: const Text("Price Descending"), value: "priceUsdD"),
      PopupMenuItem<String>(
          child: const Text("Market Cap Ascending"), value: "marketCapUsdA"),
      PopupMenuItem<String>(
          child: const Text("Market Cap Descending"), value: "marketCapUsdD"),
      PopupMenuItem<String>(
          child: const Text("24H Change Ascending"), value: "changePercent24HrA"),
      PopupMenuItem<String>(
          child: const Text("24H Change Descending"), value: "changePercent24HrD")
    ];
    if(widget.savedPage){
      l.insert(0, PopupMenuItem<String>(
          child: const Text("Custom"), value: "custom")
      );
    }
    Widget ret = Scaffold(
      drawer: widget.savedPage?Drawer(
        child: ListView(
          children: [
            GestureDetector(
              child: Container(
                color: Colors.black,
                height:MediaQuery.of(context).size.height/5,
                child: Image.asset("icon/platypus.png"),
              ),
              onTap: () async{
                String url = "https://platypuslabs.llc";
                if(await canLaunch(url)) {
                  await launch(url);
                }
              }
            ),
            ListTile(
              leading: Icon(Icons.import_export),
              title: Text("Import/Export Favorites", style: TextStyle(fontSize:16.0)),
              onTap: (){
                if(!_loading){
                  _didImport = false;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ImpExpPage())).then((f){
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
            ListTile(
                leading: Icon(Icons.settings),
                title: Text("Settings",style: TextStyle(fontSize:16.0)),
                onTap: (){
                  if(!_loading){
                    Navigator.push(context,MaterialPageRoute(builder: (context) => Settings()));
                  }
                }
            ),
            ListTile(
                leading: Icon(Icons.mail),
                title: Text("Contact Us",style: TextStyle(fontSize:16.0)),
                onTap: () async{
                  String url = Uri.encodeFull("mailto:support@platypuslabs.llc?subject=GetPass&body=Contact Reason: ");
                  if(await canLaunch(url)) {
                    await launch(url);
                  }
                }
            ),
            ListTile(
                leading: Icon(Icons.star),
                title: Text("Rate Us",style: TextStyle(fontSize:16.0)),
                onTap: () async{
                  String url = Platform.isIOS?"https://itunes.apple.com/us/app/platypus-crypto/id1397122793":"https://play.google.com/store/apps/details?id=land.platypus.cryptotracker";
                  if(await canLaunch(url)) {
                    await launch(url);
                  }
                }
            )
          ]
        ),
        key: ValueKey(widget.savedPage)
      ):null,
      appBar: AppBar(
        bottom: _loading?PreferredSize(preferredSize: Size(double.infinity,3.0),child: Container(height:3.0, child: LinearProgressIndicator())):null,
        title: searching?TextField(
            autocorrect: false,
            autofocus: true,
            decoration: InputDecoration(
                hintText: "Search",
                hintStyle: TextStyle(color:Colors.white),
                border: InputBorder.none
            ),
            style:TextStyle(color:Colors.white),
            onChanged:(s){
              searchTimer?.cancel();
              searchTimer = Timer(Duration(milliseconds: 500),(){
                search(s);
              });
            },
            onSubmitted: (s){
              search(s);
            }
        ):Text(widget.savedPage?"Favorites":"All Coins"),
        actions: [
          IconButton(
              icon: Icon(searching?Icons.close:Icons.search),
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
          Container(
              width:35.0,
              child: PopupMenuButton(
                  itemBuilder: (BuildContext context)=>l,
                  child: Icon(Icons.sort),
                  onSelected:(s){
                    if(_loading){
                      return;
                    }
                    sort(s);
                  }
              )
          ),
          IconButton(
              icon: Icon(Icons.refresh),
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
      body: !_loading?Scrollbar(
          child: ListView.builder(
              itemBuilder: (context, i)=>Crypto(sortedKeys[i], widget.savedPage),
              itemCount: sortedKeys.length,
              controller: scrollController
          )
      ):Container(),
      floatingActionButton: widget.savedPage?!_loading?FloatingActionButton(
        onPressed: (){
          moving = false;
          moveWith = null;
          Navigator.push(context,MaterialPageRoute(builder: (context) => ListPage(false))).then((d){
            sortingBy = "custom";
            searching = false;
            reset();
            scrollController.jumpTo(0.0);
          });
        },
        child: Icon(
            Icons.add
        ),
        heroTag: "newPage"
      ):null:FloatingActionButton(
          onPressed: (){
            scrollController.jumpTo(0.0);
          },
          child: Icon(
              Icons.arrow_upward
          ),
          heroTag: "jump"
      )
    );
    if(!widget.savedPage){
      ret = WillPopScope(
          child: ret,
          onWillPop: ()=>Future<bool>(()=>!_loading)
      );
    }
    return ret;
  }
}

bool _didImport = false;

class ImpExpPage extends StatefulWidget{
  @override
  ImpExpPageState createState() => ImpExpPageState();
}

class ImpExpPageState extends State<ImpExpPage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Import/Export")),
      body: Builder(
        builder: (context)=>Container(
            child: Padding(
                padding: EdgeInsets.only(top:20.0,right:15,left:15),
                child: ListView(
                    physics: ClampingScrollPhysics(),
                    children: [
                      Card(
                        color: Colors.black12,
                        child: ListTile(
                            title: Text("Export Favorites"),
                            subtitle: Text("To your clipboard"),
                            trailing: Icon(Icons.file_upload),
                            onTap: () async{
                              await Clipboard.setData(ClipboardData(text:json.encode(_savedCoins)));
                              Scaffold.of(context).removeCurrentSnackBar();
                              Scaffold.of(context).showSnackBar(SnackBar(duration: Duration(milliseconds: 1000),content: Text("Copied to clipboard",style:TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
                            }
                        ),
                        margin: EdgeInsets.zero,
                      ),
                      Container(height:20),
                      Card(
                        color: Colors.black12,
                        child: ListTile(
                            title: Text("Import Favorites"),
                            subtitle: Text("From your clipboard"),
                            trailing: Icon(Icons.file_download),
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
                                Scaffold.of(context).showSnackBar(SnackBar(duration: Duration(milliseconds: 1000),content: Text("Imported",style:TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
                              }catch(e){
                                Scaffold.of(context).removeCurrentSnackBar();
                                Scaffold.of(context).showSnackBar(SnackBar(duration: Duration(milliseconds: 1000),content: Text("Invalid data",style:TextStyle(color:Colors.white)),backgroundColor: Colors.grey[800]));
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
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings>{

  @override
  Widget build(BuildContext context){
    return Scaffold(
        appBar: AppBar(title:Text("Settings",style:TextStyle(fontSize:25.0,fontWeight: FontWeight.bold)),backgroundColor: Colors.black54),
        body: Padding(
            padding: EdgeInsets.only(top:20.0,right:15,left:15),
            child: ListView(
                physics: ClampingScrollPhysics(),
                children: [
                  Card(
                    color: Colors.black12,
                    child: ListTile(
                        title: Text("Disable 7 day graphs"),
                        subtitle: Text("More compact cards"),
                        trailing: Switch(
                            value: _settings["disableGraphs"],
                            onChanged: (disp){
                              context.findAncestorStateOfType<_AppState>().setState((){
                                _settings["disableGraphs"] = !_settings["disableGraphs"];
                              });
                              _userData["settings/disableGraphs"] = _settings["disableGraphs"];
                            }
                        ),
                        onTap: (){
                          context.findAncestorStateOfType<_AppState>().setState((){
                            _settings["disableGraphs"] = !_settings["disableGraphs"];
                          });
                          _userData["settings/disableGraphs"] = _settings["disableGraphs"];
                        }
                    ),
                    margin: EdgeInsets.zero,
                  ),
                  Container(height:20),
                  Card(
                    color: Colors.black12,
                    child: ListTile(
                        title: Text("Change Currency"),
                        subtitle: Text("33 fiat currency options"),
                        trailing: Padding(
                            child: Container(
                                color: Colors.white12,
                                padding: EdgeInsets.only(right:7.0,left:7.0),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        value: _settings["currency"],
                                        onChanged: (s){
                                          _settings["currency"] = s;
                                          _changeCurrency(s);
                                          _userData["settings/currency"] = s;
                                          context.findAncestorStateOfType<_AppState>().setState((){});
                                        },
                                        items: _currencySymbolMap.keys.map((s)=>DropdownMenuItem(
                                            value:s,
                                            child: Text(s+" "+_currencySymbolMap[s])
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

class PriceText extends StatefulWidget{

  final String id;

  PriceText(this.id);

  @override
  _PriceTextState createState() => _PriceTextState();
}

class _PriceTextState extends State<PriceText>{

  Color changeColor;
  Timer updateTimer;
  bool disp = false;
  ValueNotifier<num> coinNotif;
  Map<String,dynamic> data;

  void update(){
    if(data["priceUsd"].compareTo(coinNotif.value)>0){
      changeColor = Colors.green;
    }else{
      changeColor = Colors.red;
    }
    setState((){});
    updateTimer?.cancel();
    updateTimer = Timer(Duration(milliseconds: 400),(){
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
    coinNotif.addListener(update);
  }

  @override
  void dispose(){
    super.dispose();
    disp = true;
    coinNotif.removeListener(update);
  }

  @override
  Widget build(BuildContext context){
    num price = data["priceUsd"]*_exchangeRate;
    return Text(price>=0?NumberFormat.currency(symbol: _symbol, decimalDigits: price>1?price<100000?2:0:price>.000001?6:7).format(price):"N/A",style: TextStyle(fontSize:20.0,fontWeight: FontWeight.bold, color: changeColor));
  }

}

bool moving = false;
String moveWith;

class Crypto extends StatefulWidget{

  final String id;
  final bool savedPage;

  Crypto(this.id, this.savedPage) : super(key: ValueKey(id+savedPage.toString()));

  @override
  _CryptoState createState() => _CryptoState();
}

class _CryptoState extends State<Crypto>{

  bool saved;
  Map<String,dynamic> data;

  @override
  void initState(){
    super.initState();
    data = _coinData[widget.id];
    saved = _savedCoins.contains(widget.id);
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
    num mCap = data["marketCapUsd"];
    mCap*=_exchangeRate;
    num change = data["changePercent24Hr"];
    String shortName = data["symbol"];
    return Container(
      height: !_settings["disableGraphs"]?120.0:100.0,
      padding: EdgeInsets.only(top:10.0),
      child: GestureDetector(
        onLongPress: (){
          if(sortingBy=="custom"){
            context.findAncestorStateOfType<_ListPageState>().setState((){
              moving = true;
              moveWith = widget.id;
            });
          }else if(!widget.savedPage){
            Navigator.push(context,MaterialPageRoute(builder: (context) => ItemInfo(widget.id)));
          }
        },
        child: Dismissible(
            background: Container(color:Colors.red),
            key: ValueKey(widget.id),
            direction: DismissDirection.endToStart,
            onDismissed: (d){
              _savedCoins.remove(widget.id);
              _userData["saved"] = _savedCoins;
              context.findAncestorStateOfType<_ListPageState>().sortedKeys.remove(widget.id);
              context.findAncestorStateOfType<_ListPageState>().setState((){});
            },
            child: FlatButton(
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
                    Navigator.push(context,MaterialPageRoute(builder: (context) => ItemInfo(widget.id)));
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
              child: Row(
                children: [
                  Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: width/3
                                ),
                                child: AutoSizeText(
                                    data["name"],
                                    maxLines: 2,
                                    minFontSize: 0.0,
                                    maxFontSize: 17.0,
                                    style: TextStyle(fontSize:17.0)
                                )
                              )
                            ]
                        ),
                        Container(height:5.0),
                        Row(
                            children: [
                              FadeInImage(
                                  image: !blacklist.contains(widget.id)?NetworkImage("https://static.coincap.io/assets/icons/${shortName.toLowerCase()}@2x.png"):AssetImage("icon/platypus2.png"),
                                  placeholder: AssetImage("icon/platypus2.png"),
                                  fadeInDuration: const Duration(milliseconds:100),
                                  height:32.0,
                                  width:32.0
                              ),
                              Container(width:4.0),
                              ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: width/3-40
                                  ),
                                  child: AutoSizeText(
                                      shortName,
                                      maxLines: 1
                                  )
                              )
                            ]
                        )
                      ]
                  )),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PriceText(widget.id),
                        Text((mCap>=0?mCap>1?_symbol+NumberFormat.currency(symbol:"",decimalDigits: 0).format(mCap):_symbol+mCap.toStringAsFixed(2):"N/A"),style: TextStyle(color:Colors.grey,fontSize:12.0)),
                        !_settings["disableGraphs"]?linkMap[shortName]!=null&&!blacklist.contains(widget.id)?SvgPicture.network(
                          "https://www.coingecko.com/coins/${linkMap[shortName] ?? linkMap[widget.id]}/sparkline",
                          placeholderBuilder: (BuildContext context) => Container(
                            width:0,
                            height:35.0
                          ),
                          width:105.0,
                          height:35.0
                        ):Container(height:35.0):Container(),
                      ]
                  ),
                  Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          change!=-1000000.0?Text(((change>=0)?"+":"")+change.toStringAsFixed(3)+"\%",style:TextStyle(color:((change>=0)?Colors.green:Colors.red))):Text("N/A"),
                          Container(width:2),
                          !widget.savedPage?Icon(saved?Icons.check:Icons.add):Container()
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
  _ItemInfoState createState() => _ItemInfoState();
}

class _ItemInfoState extends State<ItemInfo>{


  Map<String,dynamic> data;

  @override
  void initState(){
    super.initState();
    data = _coinData[widget.id];
  }

  @override
  Widget build(BuildContext context){
    return DefaultTabController(
        length:5,
        child: Scaffold(
            appBar:AppBar(
                title:Text(data["name"],style:TextStyle(fontSize:25.0)),
                backgroundColor: Colors.black54,
                actions: [
                  Row(
                      children: [
                        FadeInImage(
                          image: NetworkImage("https://static.coincap.io/assets/icons/${data["symbol"].toLowerCase()}@2x.png"),
                          placeholder: AssetImage("icon/platypus2.png"),
                          fadeInDuration: const Duration(milliseconds:100),
                          height:32.0,
                          width:32.0,
                        ),
                        Text(" "+data["symbol"]),
                        Container(width:5.0)
                      ]
                  )
                ]
            ),
            body:ListView(
                physics: ClampingScrollPhysics(),
                children:[
                  Container(
                      color: Colors.black54,
                      child: TabBar(
                          tabs: [
                            Tab(icon: AutoSizeText(
                              "1D",
                              maxFontSize: 25.0,
                              style: TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            Tab(icon: AutoSizeText(
                              "1W",
                              maxFontSize: 25.0,
                              style: TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            Tab(icon: AutoSizeText(
                              "1M",
                              maxFontSize: 25.0,
                              style: TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            Tab(icon: AutoSizeText(
                              "6M",
                              maxFontSize: 25.0,
                              style: TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            )),
                            Tab(icon: AutoSizeText(
                              "1Y",
                              maxFontSize: 25.0,
                              style: TextStyle(fontSize:25.0,fontWeight: FontWeight.bold),
                              minFontSize: 0.0
                            ))
                          ]
                      )
                  ),
                  Container(height:15.0),
                  Container(
                      height: 200.0,
                      padding: EdgeInsets.only(right:10.0),
                      child: TabBarView(
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                            SimpleTimeSeriesChart(widget.id,1,"m5"),
                            SimpleTimeSeriesChart(widget.id,7,"m30"),
                            SimpleTimeSeriesChart(widget.id,30,"h2"),
                            SimpleTimeSeriesChart(widget.id,182,"h12"),
                            SimpleTimeSeriesChart(widget.id,364,"d1")
                          ]
                      )
                  ),
                  Container(height:10.0),
                  Row(
                      children: [
                        Expanded(child:Info("Price",widget.id,"priceUsd")),
                        Expanded(child:Info("Market Cap",widget.id,"marketCapUsd"))
                      ]
                  ),
                  Row(
                      children: [
                        Expanded(child:Info("Supply",widget.id,"supply")),
                        Expanded(child:Info("Max Supply",widget.id,"maxSupply")),
                      ]
                  ),
                  Row(
                      children: [
                        Expanded(child:Info("24h Change",widget.id,"changePercent24Hr")),
                        Expanded(child:Info("24h Volume",widget.id,"volumeUsd24Hr"))
                      ]
                  ),
                ]
            )
        )
    );
  }
}

class Info extends StatefulWidget{

  final String title,ticker,id;

  Info(this.title,this.ticker,this.id);

  @override
  _InfoState createState() => _InfoState();
}

class _InfoState extends State<Info>{

  dynamic value;

  ValueNotifier<num> coinNotif;

  Color textColor;

  Timer updateTimer;

  bool disp = false;

  Map<String,dynamic> data;

  void update(){
    if(data["priceUsd"].compareTo(coinNotif.value)>0){
      textColor = Colors.green;
    }else{
      textColor = Colors.red;
    }
    setState((){});
    updateTimer?.cancel();
    updateTimer = Timer(Duration(milliseconds: 400),(){
      if(disp){
        return;
      }
      setState(() {
        textColor = null;
      });
    });
  }

  @override
  void initState(){
    super.initState();
    if(widget.id=="priceUsd"){
      coinNotif = _valueNotifiers[widget.ticker];
      coinNotif.addListener(update);
    }else{
      textColor = Colors.white;
    }
    data = _coinData[widget.ticker];
  }

  @override
  void dispose(){
    super.dispose();
    if(widget.id=="priceUsd"){
      disp = true;
      coinNotif.removeListener(update);
    }
  }

  @override
  Widget build(BuildContext context){
    dynamic value = data[widget.id];
    String text;
    if((widget.id=="changePercent24Hr"&&value==-1000000)||value==null||value==-1){
      text = "N/A";
    }else{
      NumberFormat formatter;
      if(widget.id=="priceUsd"){
        formatter = NumberFormat.currency(symbol: _symbol, decimalDigits: value>1?value<100000?2:0:value>.000001?6:7);
      }else if(widget.id=="marketCapUsd"){
        formatter = NumberFormat.currency(symbol: _symbol, decimalDigits: value>1?0:2);
      }else if(widget.id=="changePercent24Hr"){
        formatter = NumberFormat.currency(symbol:"",decimalDigits:3);
      }else{
        formatter = NumberFormat.currency(symbol:"",decimalDigits:0);
      }
      text = formatter.format(value);
    }
    if(widget.id=="changePercent24Hr"&&value!=-1000000){
      text+="%";
      text = (value>0?"+":"")+text;
      textColor = value<0?Colors.red:value>0?Colors.green:Colors.white;
    }
    return Container(
        padding: EdgeInsets.only(top:2.0, left:2.0, right:2.0),
        child: Card(
          child: Container(
            height: 60.0,
            color: Colors.black45,
            padding: EdgeInsets.only(top:10.0,bottom:10.0),
            child: Column(
                children: [
                  Text(widget.title,textAlign: TextAlign.left, style:TextStyle(fontSize:17, fontWeight: FontWeight.bold)),
                  ConstrainedBox(
                    child: AutoSizeText(
                        text,
                        minFontSize: 0,
                        maxFontSize: 17,
                        style: TextStyle(fontSize:17,color: textColor),
                        maxLines: 1
                    ),
                    constraints: BoxConstraints(
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
  DateTime time;
  double price;

  TimeSeriesPrice(this.time, this.price);
}

class SimpleTimeSeriesChart extends StatefulWidget{

  final String period, id;

  final int startTime;

  SimpleTimeSeriesChart(this.id,this.startTime,this.period);

  @override
  _SimpleTimeSeriesChartState createState() => _SimpleTimeSeriesChartState();
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
    DateTime now = DateTime.now();
    http.get(Uri.encodeFull("https://api.coincap.io/v2/assets/${widget.id}/history?interval="+widget.period+"&start="+now.subtract(Duration(days:widget.startTime)).millisecondsSinceEpoch.toString()+"&end="+now.millisecondsSinceEpoch.toString())).then((value){
      seriesList = createChart(json.decode(value.body),widget.id);
      setState((){
        loading = false;
      });
      base = minVal>=0?max(0,(-log(minVal)/log(10)).ceil()+2):0;
      if(minVal<=1.1&&minVal>.9){
        base++;
      }
    });
  }

  Map<String,int> dataPerDay = {
    "m5":288,
    "m30":48,
    "h2":12,
    "h12":2,
    "d1":1
  };

  Map<String,DateFormat> formatMap = {
    "m5":DateFormat("h꞉mm a"),
    "m30":DateFormat.MMMd(),
    "h2":DateFormat.MMMd(),
    "h12":DateFormat.MMMd(),
    "d1":DateFormat.MMMd(),
  };

  @override
  Widget build(BuildContext context){
    bool hasData = seriesList!=null&&seriesList.length>(widget.startTime*dataPerDay[widget.period]/10);
    double dif, factor, visMax, visMin;
    DateFormat xFormatter = formatMap[widget.period];
    NumberFormat yFormatter = NumberFormat.currency(symbol:_symbol.toString().replaceAll("\.", ""),locale:"en_US",decimalDigits:base);
    if(!loading&&hasData){
      dif = (maxVal-minVal);
      factor = min(1,max(.2,dif/maxVal));
      visMin = max(0,minVal-dif*factor);
      visMax = visMin!=0?maxVal+dif*factor:maxVal+minVal;
    }
    return !loading&&canLoad&&hasData?Container(width: 350.0*MediaQuery.of(context).size.width/375.0,
        height:200.0,
        child: SfCartesianChart(
            series: [
            LineSeries<TimeSeriesPrice,DateTime>(
                dataSource: seriesList,
                xValueMapper: (TimeSeriesPrice s,_)=>s.time,
                yValueMapper: (TimeSeriesPrice s,_)=>s.price,
                animationDuration: 0,
                color: Colors.blue
            )
          ],
          plotAreaBackgroundColor: Colors.transparent,
          primaryXAxis: DateTimeAxis(
              dateFormat: xFormatter
          ),
          primaryYAxis: NumericAxis(
              numberFormat: yFormatter,
              decimalPlaces: base,
              visibleMaximum: visMax,
              visibleMinimum: visMin,
              interval: (visMax-visMin)/4.001
          ),
          selectionGesture: ActivationMode.singleTap,
          selectionType: SelectionType.point,
          onAxisLabelRender: (a){
            if(a.orientation==AxisOrientation.vertical){
              a.text = yFormatter.format(a.value);
            }else{
              a.text = xFormatter.format(DateTime.fromMillisecondsSinceEpoch(a.value));
            }
          },
          trackballBehavior: TrackballBehavior(
            activationMode: ActivationMode.singleTap,
            enable: true,
            shouldAlwaysShow: true,
            tooltipSettings: InteractiveTooltip(
                color: Colors.white,
                format: "point.x | point.y",
                decimalPlaces: base
            )
          ),
          onTrackballPositionChanging: (a){
              var v = a.chartPointInfo.chartDataPoint;
              a.chartPointInfo.label = "${xFormatter.format(v.x)} | ${yFormatter.format(v.y)}";
          },
        )
    ):canLoad&&(hasData||loading)?Container(
        height:233.0,
        padding:EdgeInsets.only(left:10.0,right:10.0),
        child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator()
          ]
        )
    ):Container(
        height:233.0,
        child: Center(
            child: Text("Sorry, this coin graph is not supported",style: TextStyle(fontSize:17.0))
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
        data.add(TimeSeriesPrice(DateTime.fromMillisecondsSinceEpoch(info["data"][i]["time"]), val));
      }
    }else{
      canLoad = false;
    }
    return data;
  }
}