import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widgets.dart';
import 'dart:collection';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/scheduler.dart';
import 'package:crypto_tracker/feature_discovery.dart';
import 'mydropdown.dart' as MyDropdown;
import 'package:dynamic_theme/dynamic_theme.dart';

int itemCount = 1;

bool isInSwap = false;

String currency = "USD";

String symbol = "\$";

double rate = 1.0;

double usdRate = 1.0;

Map<String, String> currencySymbolMap = {
  "USD": "\$",
  "AUD": "A\$",
  "BRL": "R\$",
  "CAD": "C\$",
  "CHF": "Fr. ",
  "CLP": "\$",
  "CNY": "¥",
  "CZK": "Kč",
  "DKK": "kr. ",
  "EUR": "€",
  "GBP": "£",
  "HKD": "HK\$",
  "HUF": "Ft ",
  "IDR": "Rp ",
  "ILS": "₪",
  "INR": "₹",
  "JPY": "¥",
  "KRW": "₩",
  "MXN": "\$",
  "MYR": "RM",
  "NOK": "kr ",
  "NZD": "\$",
  "PHP": "₱",
  "PKR": "₨ ",
  "PLN": "zł",
  "RUB": "₽",
  "SEK": "kr ",
  "SGD": "S\$",
  "THB": "฿",
  "TRY": "₺",
  "TWD": "NT\$",
  "ZAR": "R "
};

List<String> features = ["f1","f2","f3","f4","f5","f6"];

int featureCount = 0;

final DataStorage storage = new DataStorage();

final ThemeInfo themeInfo = new ThemeInfo();

bool wentBack = false;

HashMap<int, int> idIndex = new HashMap<int, int>();

Map<String, dynamic> data;

bool displayGraphs;

String response;

bool bright;

bool firstTime = false;

void main() {
  timeDilation = 1.0;
  themeInfo.readData().then((value){
    if(value==null || value.length!=3){
      themeInfo.writeData("1 1 USD").then((f){
        bright = false;
        displayGraphs = true;
        firstTime = true;
        runApp(new DynamicTheme(
            themedWidgetBuilder: (context, theme){
              return new MaterialApp(
                  theme: theme,
                  home: new FeatureDiscovery(child: new HomePage())
              );
            },
            data: (brightness) => new ThemeData(fontFamily: "MavenPro",brightness: bright?Brightness.light:Brightness.dark),
            defaultBrightness: bright?Brightness.light:Brightness.dark
        ));
      });
    }else{
      bright = value[0]=="0";
      displayGraphs = value[1]=="1";
      currency = value[2];
      if(currency!="USD"){
        symbol = currencySymbolMap.putIfAbsent(currency, ()=>null);
        http.get(
            Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/1?convert="+currency)
        ).then((response){
          Map<String, dynamic> map = json.decode(response.body)["data"];
          rate = map["quotes"][currency]["price"]/map["quotes"]["USD"]["price"]*1.0;
          usdRate = rate;
          runApp(new DynamicTheme(
              themedWidgetBuilder: (context, theme){
                return new MaterialApp(
                    theme: theme,
                    home: new FeatureDiscovery(child: new HomePage())
                );
              },
              data: (brightness) => new ThemeData(fontFamily: "MavenPro",brightness: bright?Brightness.light:Brightness.dark),
              defaultBrightness: bright?Brightness.light:Brightness.dark
          ));
        });
      }else{
        usdRate = 1.0;
        rate = 1.0;
        symbol = "\$";
        runApp(new DynamicTheme(
          themedWidgetBuilder: (context, theme){
            return new MaterialApp(
                theme: theme,
                home: new FeatureDiscovery(child: new HomePage())
            );
          },
          data: (brightness) => new ThemeData(fontFamily: "MavenPro",brightness: bright?Brightness.light:Brightness.dark),
          defaultBrightness: bright?Brightness.light:Brightness.dark
        ));
      }
    }
  });
}

int buildCount = 0;

class HomePage extends StatefulWidget{

  @override
  HomePageState createState() => new HomePageState();
}

class HomePageState extends State<HomePage>{

  static List<Widget> filteredList = new List<Widget>();

  Future<http.Response> getSpecificData(int id) async{
    return await http.get(
        Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/"+id.toString())
    );
  }

  Future<String> getData() async{
    http.Response r = await http.get(
        Uri.encodeFull("https://api.coinmarketcap.com/v2/listings")
    );
    data = json.decode(r.body);
    int runs = data["metadata"]["num_cryptocurrencies"];
    itemCount = runs;
    fullList.length = itemCount;
    for(int i = 0; i<runs;i++){
      // ignore: conflicting_dart_import
      fullList[i] = new Crypto(data["data"][i]["website_slug"],Colors.black12,i,data["data"][i]["name"],data["data"][i]["id"],new CachedNetworkImage(
        // ignore: conflicting_dart_import
          imageUrl: "https://s2.coinmarketcap.com/static/img/coins/64x64/"+data["data"][i]["id"].toString()+".png",key: new Key("Icon for "+data["data"][i]["name"].toString()),placeholder: Image.asset("icon/platypus2.png",height:32.0,width:32.0),fadeInDuration: const Duration(milliseconds:100),height:32.0,width:32.0
      ),data["data"][i]["symbol"],new CachedNetworkImage(
          imageUrl: "https://s2.coinmarketcap.com/generated/sparklines/web/7d/usd/"+data["data"][i]["id"].toString()+'.png',width:105.0,key: new Key("Graph for "+data["data"][i]["name"].toString()),fadeInDuration: const Duration(milliseconds:100),placeholder: Image.asset("icon/platypus2.png",height:35.0,width:0.0)
      ));
      idIndex.putIfAbsent(data["data"][i]["id"], ()=>i);
    }
    buildCount=100;
    setState((){});
    return new Future<String>((){return "0";});
  }

  int count = 0;

  int realCount = 0;

  Future<String> setUpData() async{
    count = 0;
    realCount = 0;
    http.Response r;
    while(count<itemCount+1){
      r = await http.get(
          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/?start="+count.toString())
      );
      data = json.decode(r.body);
      Map<String,dynamic> map = data["data"];
      for(Map<String,dynamic> s in map.values){
        int place = idIndex.putIfAbsent(s["id"], ()=>-1);
        (fullList[place] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]*usdRate:-1.0;
        (fullList[place] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1000000.0;
        (fullList[place] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1000000.0;
        (fullList[place] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1000000.0;
        (fullList[place] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]*usdRate:-1.0;
        (fullList[place] as Crypto).circSupply = s["circulating_supply"]!=null?s["circulating_supply"]:-1.0;
        (fullList[place] as Crypto).totalSupply = s["total_supply"]!=null?s["total_supply"]:-1.0;
        (fullList[place] as Crypto).maxSupply = s["max_supply"]!=null?s["max_supply"]:-1.0;
        (fullList[place] as Crypto).volume24h = s["quotes"]["USD"]["volume_24h"]!=null?s["quotes"]["USD"]["volume_24h"]*usdRate:-1.0;
        realCount++;
      }
      setState((){});
      count+=count==0?101:100;
    }
    if(first){
      buildCount = 199;
    }
    first = false;
    done = true;
    setState((){});
    return new Future<String>((){return "0";});
  }

  bool first = true;

  bool done = false;

  void initState(){
    super.initState();
    if(buildCount==0){
      getData();
    }
    buildCount++;
  }

  bool firstLoad = false;

  static bool inSearch = false;

  ScrollController scrollController = new ScrollController();

  int a = 0;

  String search;

  static bool hasSearched = false;

  bool loadGood = true;

  @override
  Widget build(BuildContext context){

    if(search==null){
      if(filteredList.length==0){
        filteredList.addAll(favList);
      }
    }

    if(buildCount==100){
      setUpData();
      buildCount++;
    }
    if(buildCount==199){
      //build fav list
      inds = new List<int>();
      storage.readData().then((List<int> value){
        if(value!=null && value.length>0){
          inds.addAll(value);
          favList = new List<Widget>();
          favList.length = (inds.length/2).floor();
          for(int i = 0; i<inds.length;i+=2){
            int dex = idIndex.putIfAbsent(inds[i], ()=>-1);
            if(dex!=-1){
              Crypto temp = (fullList[dex] as Crypto);
              (fullList[dex] as Crypto).favIndex = inds[i+1];
              favList[inds[i+1]]=(new FavCrypto(temp.slug,inds[i+1],dex,temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap,temp.image,temp.shortName,temp.smallImage,temp.circSupply,temp.totalSupply,temp.maxSupply,temp.volume24h));
              (fullList[dex] as Crypto).color = Colors.black26;
            }
          }
        }
        buildCount = 300;
        int dex = 0;
        for(Widget w in fullList){
          dex++;
          if((w as Crypto).price==null){
            Crypto temp = (w as Crypto);
            temp.price = -1.0;
            temp.oneHour = -1000000.0;
            temp.twentyFourHours = -1000000.0;
            temp.sevenDays = -1000000.0;
            temp.mCap = -1.0;
            temp.circSupply = -1.0;
            temp.totalSupply = -1.0;
            temp.maxSupply = -1.0;
            temp.volume24h = -1.0;
            if((w as Crypto).favIndex!=null && (w as Crypto).favIndex>=0){
              FavCrypto temperino = favList[(fullList[dex] as Crypto).favIndex] as FavCrypto;
              temperino.price = temp.price;
              temperino.oneHour = temp.oneHour;
              temperino.twentyFourHours = temp.twentyFourHours;
              temperino.sevenDays = temp.sevenDays;
              temperino.mCap = temp.mCap;
              temperino.circSupply = temp.circSupply;
              temperino.totalSupply = temp.totalSupply;
              temperino.maxSupply = temp.maxSupply;
              temperino.volume24h = temp.volume24h;
            }
          }
        }
        wait(){
          if(dex==fullList.length){
            setState((){firstLoad = true;});
            if(firstTime){
              FeatureDiscovery.discoverFeatures(context, [features[0]]);
            }
            setState((){});
          }else{
            new Timer(Duration.zero,wait);
          }
        }
        wait();
      });
    }
    if(firstTime && featureCount==2 && loadGood){
      new Timer(new Duration(seconds:1),(){FeatureDiscovery.discoverFeatures(context, features.sublist(2,features.length));loadGood = false;});
    }
    return firstLoad?new Scaffold(
        appBar:new AppBar(
            bottom: completer.isCompleted?new PreferredSize(preferredSize: new Size(0.0,0.0),child: new Container()):new PreferredSize(preferredSize: new Size(double.infinity,2.0),child: new Container(height:2.0,child:new LinearProgressIndicator(value:realCount/itemCount))),
            title:!inSearch?new Text("Favorites"):new TextField(
                autocorrect: false,
                decoration: new InputDecoration(
                    hintText: "Search",
                    // ignore: conflicting_dart_import
                    hintStyle: new TextStyle(color:Colors.white),
                    prefixIcon: new Icon(Icons.search)
                ),
                style:new TextStyle(color:Colors.white),
                autofocus: true,
                onChanged: (s) {
                  search = s;
                },
                onSubmitted: (s){
                  scrollController.jumpTo(1.0);
                  filteredList.clear();
                  search = s;
                  for(int i = 0; i<favList.length;i++){
                    if((favList[i] as FavCrypto).name.toUpperCase().contains(search.toUpperCase()) || (favList[i] as FavCrypto).shortName.toUpperCase().contains(search.toUpperCase())){
                      filteredList.add(favList[i]);
                    }
                  }
                  hasSearched = true;
                  setState((){});
                }
            ),
            backgroundColor: Colors.black54,
            actions: [
              new DescribedFeatureOverlay(
                featureId: features[2],
                color: Colors.teal,
                title: 'Searching',
                icon: Icons.search,
                  description: new Text(
                      'Tap here to search your favorites list.',
                    style: new TextStyle(
                      fontSize: 16.0,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                child: new IconButton(
                    icon: new Icon(!hasSearched?Icons.search:Icons.clear),
                    onPressed: (){
                      if(firstTime){
                        setState((){firstTime = false;featureCount = 100;});
                      }
                      if(hasSearched){
                        filteredList.clear();
                        filteredList.addAll(favList);
                        hasSearched = false;
                        setState((){inSearch = false;});
                      }else{
                        setState((){inSearch = true;});
                      }
                    }
                ),
                doAction: (f){
                  featureCount++;
                  f();
                }
              ),
              new DescribedFeatureOverlay(
                  doAction: (f){
                    featureCount++;
                    f();
                  },
                  featureId: features[3],
                  color: Colors.teal,
                  title: 'Sorting',
                  icon: Icons.sort,
                  description: new Text(
                    'Tap here to sort your favorites list.',
                    style: new TextStyle(
                      fontSize: 16.0,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  child: new Container(
                    width: 35.0,
                    child: new PopupMenuButton<String>(
                        itemBuilder: (BuildContext context)=><PopupMenuItem<String>>[
                          new PopupMenuItem<String>(
                              child: const Text("Name Ascending"), value: "Name Ascending"),
                          new PopupMenuItem<String>(
                              child: const Text("Name Descending"), value: "Name Descending"),
                          new PopupMenuItem<String>(
                              child: const Text("Price Ascending"), value: "Price Ascending"),
                          new PopupMenuItem<String>(
                              child: const Text("Price Descending"), value: "Price Descending"),
                          new PopupMenuItem<String>(
                              child: const Text("Market Cap Ascending"), value: "Market Cap Ascending"),
                          new PopupMenuItem<String>(
                              child: const Text("Market Cap Descending"), value: "Market Cap Descending"),
                          new PopupMenuItem<String>(
                              child: const Text("24H Change Ascending"), value: "24H Change Ascending"),
                          new PopupMenuItem<String>(
                              child: const Text("24H Change Descending"), value: "24H Change Descending"),
                          new PopupMenuItem<String>(
                              child: const Text("Custom Order"), value: "Default")
                        ],
                        child: new Icon(Icons.sort),
                        onSelected:(s){
                          if(firstTime){
                            setState((){firstTime = false;featureCount = 100;});
                          }
                          setState(() {
                            scrollController.jumpTo(1.0);
                            if(s=="Name Ascending"){
                              filteredList.sort((o1,o2){
                                if((o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name)!=0){
                                  return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                                }
                                return ((o1 as FavCrypto).price-(o2 as FavCrypto).price).floor().toInt();
                              });
                            }else if(s=="Name Descending"){
                              filteredList.sort((o1,o2){
                                if((o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name)!=0){
                                  return (o2 as FavCrypto).name.compareTo((o1 as FavCrypto).name);
                                }
                                return ((o1 as FavCrypto).price-(o2 as FavCrypto).price).floor().toInt();
                              });
                            }else if(s=="Price Ascending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).price!=(o2 as FavCrypto).price)){
                                  return ((o1 as FavCrypto).price*1000000000-(o2 as FavCrypto).price*1000000000).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="Price Descending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).price!=(o2 as FavCrypto).price)){
                                  return ((o2 as FavCrypto).price*1000000000-(o1 as FavCrypto).price*1000000000).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="Market Cap Ascending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).mCap!=(o2 as FavCrypto).mCap)){
                                  return ((o1 as FavCrypto).mCap*100-(o2 as FavCrypto).mCap*100).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="Market Cap Descending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).mCap!=(o2 as FavCrypto).mCap)){
                                  return ((o2 as FavCrypto).mCap*100-(o1 as FavCrypto).mCap*100).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="24H Change Ascending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).twentyFourHours!=(o2 as FavCrypto).twentyFourHours)){
                                  return ((o1 as FavCrypto).twentyFourHours*100-(o2 as FavCrypto).twentyFourHours*100).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="24H Change Descending"){
                              filteredList.sort((o1,o2){
                                if(((o1 as FavCrypto).twentyFourHours!=(o2 as FavCrypto).twentyFourHours)){
                                  return ((o2 as FavCrypto).twentyFourHours*100-(o1 as FavCrypto).twentyFourHours*100).round();
                                }
                                return (o1 as FavCrypto).name.compareTo((o2 as FavCrypto).name);
                              });
                            }else if(s=="Default"){
                              filteredList.clear();
                              filteredList.addAll(favList);
                            }
                          });
                        }
                    )
                )
              ),
              new DescribedFeatureOverlay(
                  doAction: (f){
                    featureCount++;
                    setState((){});
                    f();
                  },
                  featureId: features[4],
                  color: Colors.teal,
                  title: 'Extra',
                  icon: Icons.more_vert,
                  description: new Text(
                    'Tap here to open settings, report a bug, or submit a review.',
                    style: new TextStyle(
                      fontSize: 16.0,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  child: new Container(width: 30.0,child: new PopupMenuButton<String>(
                    onSelected: (String selected){
                      if(firstTime){
                        setState((){firstTime = false;featureCount = 100;});
                      }
                      if(selected=="Settings"){
                        Navigator.push(context,new MaterialPageRoute(builder: (context) => new Settings()));
                      }else if(selected=="Rate us"){
                        if(Platform.isIOS){
                          launchIOS() async{
                            const url = 'https://itunes.apple.com/us/app/platypus-crypto/id1397122793';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchIOS();
                        }else if(Platform.isAndroid){
                          launchAndroid() async{
                            const url = 'https://play.google.com/store/apps/details?id=land.platypus.crypto';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchAndroid();
                        }
                      }else if(selected=="Report a Bug"){
                        if(Platform.isIOS){
                          launchIOS() async{
                            const url = 'mailto:support@platypus.land?subject=Bug%20Report&body=Description%20of%20Bug:%0A%0A%0ASteps%20to%20reproduce%20error:%0A%0A%0AAttach%20any%20relevant%20screenshots%20or%20screen%20recordings%20below:%0A%0A%0AThanks%20for%20your%20report!';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchIOS();
                        }else if(Platform.isAndroid){
                          launchAndroid() async{
                            const url = 'mailto:support@platypus.land?subject=Bug%20Report&body=Description%20of%20Bug:%0A%0A%0ASteps%20to%20reproduce%20error:%0A%0A%0AAttach%20any%20relevant%20screenshots%20or%20screen%20recordings%20below:%0A%0A%0AThanks%20for%20your%20report!';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchAndroid();
                        }
                      }else if(selected=="Website"){
                        if(Platform.isIOS){
                          launchIOS() async{
                            const url = 'https://www.platypus.land';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchIOS();
                        }else if(Platform.isAndroid){
                          launchAndroid() async{
                            const url = 'https://www.platypus.land';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchAndroid();
                        }
                      }else if(selected=="About"){
                        Navigator.push(context,new MaterialPageRoute(builder: (context) => new Scaffold(
                            appBar: new AppBar(title:new Text("About"),backgroundColor: Colors.black54),
                            body: new Container(
                                child: new Center(
                                    child: new Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: <Widget>[
                                          new Text("\n"),
                                          Image.asset("icon/platypus2.png",height:150.0*(MediaQuery.of(context).size.width<=MediaQuery.of(context).size.height?MediaQuery.of(context).size.width:MediaQuery.of(context).size.height)/375.0,width:150.0*(MediaQuery.of(context).size.width<=MediaQuery.of(context).size.height?MediaQuery.of(context).size.width:MediaQuery.of(context).size.height)/375.0),
                                          new Text("\nPlatypus Crypto V1.0.9"),
                                          new Text("©2018 Blake Bottum and Caleb Jiang",style: new TextStyle(fontWeight:FontWeight.bold))
                                        ]
                                    )
                                )
                            )
                        )));
                      }
                    },
                    itemBuilder: (BuildContext context)=><PopupMenuItem<String>>[
                      new PopupMenuItem<String>(
                          child: const Text("Settings"), value: "Settings"),
                      new PopupMenuItem<String>(
                          child: const Text("Rate us"), value: "Rate us"),
                      new PopupMenuItem<String>(
                          child: const Text("Report a Bug"), value: "Report a Bug"),
                      new PopupMenuItem<String>(
                          child: const Text("Website"), value: "Website"),
                      new PopupMenuItem<String>(
                          child: const Text("About"), value: "About"),
                    ],
                    child: new Icon(Icons.more_vert)
                ))
              )
            ]
        ),
        floatingActionButton: (done && completer.isCompleted)?new DescribedFeatureOverlay(
            featureId: features[0],
            color: Colors.teal,
            title: 'Adding',
            icon: Icons.add,
            description: new Text(
              'Tap here to add a cryptocurrency to your Favorites list.',
              style: new TextStyle(
                fontSize: 16.0,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            doAction: (f){
              featureCount++;
              completer = new Completer<Null>();
              completer.complete();
              Navigator.push(context,new MaterialPageRoute(builder: (context) => new FeatureDiscovery(child:new CryptoList())));
              inSearch = false;
              search = null;
              hasSearched = false;
              buttonPressed = true;
              f();
            },
            child: new Opacity(opacity:.75,child:new FloatingActionButton(
                onPressed: (){
                  if(firstTime){
                    setState((){firstTime = false;featureCount = 100;});
                  }
                  filteredList.clear();
                  completer = new Completer<Null>();
                  completer.complete();
                  Navigator.push(context,new MaterialPageRoute(builder: (context) => new FeatureDiscovery(child:new CryptoList())));
                  inSearch = false;
                  search = null;
                  hasSearched = false;
                  buttonPressed = true;
                },
                child: new Icon(Icons.add)
            ))):new Container(),
        body: new Container(
            color: bright?Colors.white:Colors.grey[700],
            child: new Center(
                child: new RefreshIndicator(
                  child: featureCount==5?new ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (bc,i){
                          if(firstTime && i==0){
                            return new DescribedFeatureOverlay(
                                featureId: features[5],
                                color: Colors.teal,
                                icon: Icons.info,
                                title: "More Info",
                                description: new Text(
                                  "Tap on an item for more info and graphs. Swipe to the left to remove an item and press and hold and tap on another item to change its position.",
                                  style: new TextStyle(
                                    fontSize: 16.0,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                child: filteredList[0],
                                doAction: (f){
                                  f();
                                  FavCrypto temp = (filteredList[0] as FavCrypto);
                                  firstTime = false;
                                  featureCount++;
                                  Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(temp.slug,temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap,temp.image,temp.shortName,temp.circSupply,temp.totalSupply,temp.maxSupply,temp.volume24h)));
                                }
                            );
                          }
                          return filteredList[i];

                      },
                      controller: scrollController,
                      physics: new AlwaysScrollableScrollPhysics()
                  ):new ListView(
                    children: [
                      new Column(
                        children: filteredList
                      )
                    ],
                    controller: scrollController,
                    physics: new AlwaysScrollableScrollPhysics(),
                  ),
                  onRefresh: (){
                    setState((){completer = new Completer<Null>();});
                    done = false;
                    setUpData();
                    wait(){
                      if(done){
                        int i = 0;
                        doubleWait(){
                          if(i==favList.length){
                            completer.complete();
                          }else{
                            new Timer(Duration.zero,doubleWait);
                          }
                        }
                        for(i = 0; i<favList.length;i++){
                          Crypto temp = fullList[(favList[i] as FavCrypto).friendIndex];
                          (favList[i] as FavCrypto).price = temp.price;
                          (favList[i] as FavCrypto).oneHour = temp.oneHour;
                          (favList[i] as FavCrypto).twentyFourHours = temp.twentyFourHours;
                          (favList[i] as FavCrypto).sevenDays = temp.sevenDays;
                          (favList[i] as FavCrypto).mCap = temp.mCap;
                          (favList[i] as FavCrypto).circSupply = temp.circSupply;
                          (favList[i] as FavCrypto).totalSupply = temp.totalSupply;
                          (favList[i] as FavCrypto).maxSupply = temp.maxSupply;
                          (favList[i] as FavCrypto).volume24h = temp.volume24h;
                        }
                        doubleWait();
                      }else{
                        new Timer(Duration.zero, wait);
                      }
                    }
                    wait();
                    done = false;
                    setState((){});
                    return completer.future;
                  },
                )
            )
        )
    ):new Scaffold(
        appBar: new AppBar(
            title: new Text("Loading..."),
            backgroundColor: Colors.black54
        ),
        body: new Container(
            padding: EdgeInsets.all(15.0),
            child:new Center(
                child: new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      new Text(((realCount/itemCount)*100).round().toString()+"%"),
                      new LinearProgressIndicator(
                          value: realCount/itemCount
                      )
                    ]
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

  bool doneChanging = true;

  @override
  Widget build(BuildContext context){
    return new WillPopScope(child: new Scaffold(
        appBar: new AppBar(title:new Text("Settings",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold)),backgroundColor: Colors.black54),
        body: new Container(
            padding:EdgeInsets.only(bottom:10.0,top:10.0),
            child: new Center(
                child: new Column(
                    children: <Widget>[
                      new Container(
                          padding: EdgeInsets.only(top:5.0,bottom:5.0),
                          color: bright?Colors.black12:Colors.black87,
                          child: new Row(
                              children: <Widget>[
                                new Expanded(
                                    child: new Text("  Dark Mode",style:new TextStyle(fontSize:20.0))
                                ),
                                new Switch(
                                    value: !bright,
                                    onChanged: (dark){
                                      if(doneChanging){
                                        bright = !bright;
                                        themeInfo.writeData((dark?"1":"0")+(displayGraphs?" 1":" 0")+" "+currency).then((file){
                                          DynamicTheme.of(context).setBrightness(bright?Brightness.light:Brightness.dark);
                                        });
                                      }
                                    }
                                ),
                              ]
                          )
                      ),
                      new Container(
                          padding: EdgeInsets.only(top:10.0),
                          child: new Container(
                              padding: EdgeInsets.only(top:5.0,bottom:5.0),
                              color: bright?Colors.black12:Colors.black87,
                              child: new Row(
                                  children: <Widget>[
                                    new Expanded(
                                        child: new Text("  Disable 7 day graphs",style:new TextStyle(fontSize:20.0))
                                    ),
                                    new Switch(
                                        value: !displayGraphs,
                                        onChanged: (dark){
                                          if(doneChanging){
                                            setState((){
                                              displayGraphs = !displayGraphs;
                                            });
                                            themeInfo.writeData((bright?"0":"1")+(displayGraphs?" 1":" 0")+" "+currency);
                                          }
                                        }
                                    ),
                                  ]
                              )
                          )
                      ),
                      new Container(
                          padding: EdgeInsets.only(top:10.0),
                          child: new Container(
                              padding: EdgeInsets.only(top:5.0,bottom:5.0),
                              color: bright?Colors.black12:Colors.black87,
                              child: new Row(
                                  children: <Widget>[
                                    new Expanded(
                                        child: new Text("  Currency",style:new TextStyle(fontSize:20.0)),
                                    ),
                                    doneChanging?new Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [new Container(
                                          color: bright?Colors.white:Colors.white12,
                                          child: new MyDropdown.DropdownButtonHideUnderline(
                                            child: new ButtonTheme(alignedDropdown: true,minWidth: 0.0,child: new MyDropdown.DropdownButton<String>(
                                                items: currencySymbolMap.keys.map((key)=>new MyDropdown.DropdownMenuItem<String>(value: key, child: new Text("$key ${currencySymbolMap[key]}"))).toList(),
                                                onChanged: (s){
                                                  if(doneChanging){
                                                    setState((){doneChanging = false;});
                                                    double firstRate;
                                                    double secondRate;
                                                    http.get(
                                                        Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/1?convert="+s)
                                                    ).then((response){
                                                      Map<String, dynamic> map1 = json.decode(response.body)["data"];
                                                      firstRate = map1["quotes"][s]["price"];
                                                      usdRate = firstRate/map1["quotes"]["USD"]["price"]*1.0;
                                                      http.get(
                                                          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/1?convert="+currency)
                                                      ).then((response){
                                                        Map<String, dynamic> map2 = json.decode(response.body)["data"];
                                                        secondRate = map2["quotes"][currency]["price"];
                                                        rate = firstRate/secondRate;
                                                        for(int i = 0; i<fullList.length;i++){
                                                          Crypto temp = (fullList[i] as Crypto);
                                                          temp.price = temp.price*rate;
                                                          temp.mCap = temp.mCap*rate;
                                                          temp.volume24h = temp.volume24h*rate;
                                                          if(temp.favIndex!=null && temp.favIndex>=0){
                                                            FavCrypto temperino = (favList[temp.favIndex] as FavCrypto);
                                                            temperino.price = temp.price;
                                                            temperino.mCap = temp.mCap;
                                                            temperino.volume24h = temp.volume24h;
                                                          }
                                                        }
                                                        setState((){currency = s;symbol = currencySymbolMap.putIfAbsent(currency, ()=>null);});
                                                        themeInfo.writeData((bright?"0":"1")+(displayGraphs?" 1":" 0")+" "+currency);
                                                        setState((){doneChanging = true;});
                                                      });
                                                    });
                                                  }
                                                },
                                                value: currency,
                                                style: Theme.of(context).textTheme.title
                                            ))
                                          )
                                        )]
                                    ):new Container(
                                      height: 48.0,
                                      width: 48.0,//130.0,
                                      child: new CircularProgressIndicator()//new LinearProgressIndicator()
                                    )
                                  ]
                              )
                          )
                      ),
                    ]
                )
            )
        )
    ),onWillPop:()=>new Future(()=>doneChanging));
  }
}

List<Widget> favList = [];

List<Widget> fullList = [];

class CryptoList extends StatefulWidget{

  @override
  CryptoListState createState() => new CryptoListState();
}

class CryptoListState extends State<CryptoList>{
  int realCount = 0;
  Future<String> setUpData() async{
    realCount = 0;
    int count = 0;
    http.Response r;
    while(count<itemCount+1){
      r = await http.get(
          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/?start="+count.toString())
      );
      data = json.decode(r.body);
      Map<String,dynamic> map = data["data"];
      for(Map<String,dynamic> s in map.values){
        int place = idIndex.putIfAbsent(s["id"], ()=>-1);
        (fullList[place] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]*usdRate:-1.0;
        (fullList[place] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1000000.0;
        (fullList[place] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1000000.0;
        (fullList[place] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1000000.0;
        (fullList[place] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]*usdRate:-1.0;
        (fullList[place] as Crypto).circSupply = s["circulating_supply"]!=null?s["circulating_supply"]:-1.0;
        (fullList[place] as Crypto).totalSupply = s["total_supply"]!=null?s["total_supply"]:-1.0;
        (fullList[place] as Crypto).maxSupply = s["max_supply"]!=null?s["max_supply"]:-1.0;
        (fullList[place] as Crypto).volume24h = s["quotes"]["USD"]["volume_24h"]!=null?s["quotes"]["USD"]["volume_24h"]*usdRate:-1.0;
        realCount++;
      }
      setState((){});
      count+=count==0?101:100;
    }
    done = true;
    setState((){});
    return new Future<String>((){return "0";});
  }

  bool done = true;

  String search = "";

  List<Widget> filteredList = new List<Widget>();

  ScrollController scrollController = new ScrollController();

  String selection;

  var focusNode = new FocusNode();

  TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context){


    if(search==null||search==""){
      if(filteredList.length==0){
        filteredList.addAll(fullList);
      }
    }

    if(buttonPressed){
      if(filteredList.length==0){
        filteredList.addAll(fullList);
      }
      filteredList.sort((o1,o2){
        if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
          return ((((o2 as Crypto).mCap!=null?(o2 as Crypto).mCap:-1)*100.0)-(((o1 as Crypto).mCap!=null?(o1 as Crypto).mCap:-1)*100.0)).round();
        }
        return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
      });
      buttonPressed = false;
      if(firstTime && featureCount==1){
        new Timer(const Duration(seconds:4),(){
          FeatureDiscovery.discoverFeatures(context, [features[1]]);
        });
      }
    }

    return new WillPopScope(
        child: new GestureDetector(
            onTap: (){FocusScope.of(context).requestFocus(new FocusNode());},
            child: new Scaffold(
                floatingActionButton: new Opacity(
                    opacity: bright?1.0:.75,
                    child: new FloatingActionButton(
                      child: new Icon(Icons.arrow_upward),
                      onPressed: (){
                        scrollController.jumpTo(1.0);
                        scrollController.jumpTo(1.0);
                      },
                      backgroundColor: bright?Colors.black26:Colors.tealAccent,
                    )
                ),
                appBar: new AppBar(
                    bottom: completer.isCompleted?new PreferredSize(preferredSize: new Size(0.0,0.0),child: new Container()):new PreferredSize(preferredSize: new Size(double.infinity,2.0),child: new Container(height:2.0,child:new LinearProgressIndicator(value:realCount/itemCount))),
                    title: new TextField(
                        focusNode: focusNode,
                        controller: textController,
                        autocorrect: false,
                        decoration: new InputDecoration(
                            hintText: "Search",
                            // ignore: conflicting_dart_import
                            hintStyle: new TextStyle(color:Colors.white),
                            prefixIcon: new Icon(Icons.search)
                        ),
                        style:new TextStyle(color:Colors.white),
                        onChanged:(s){
                          setState((){search = s;});
                        },
                        onSubmitted: (s){
                          selection = null;
                          scrollController.jumpTo(1.0);
                          filteredList.clear();
                          search = s;
                          for(int i = 0; i<fullList.length;i++){
                            if((fullList[i] as Crypto).name.toUpperCase().contains(search.toUpperCase()) || (fullList[i] as Crypto).shortName.toUpperCase().contains(search.toUpperCase())){
                              this.filteredList.add(fullList[i]);
                            }
                          }
                          filteredList.sort((o1,o2){
                            if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
                              return ((o2 as Crypto).mCap*100-(o1 as Crypto).mCap*100).round();
                            }
                            return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                          });
                          setState(() {});
                        }
                    ),
                    backgroundColor: Colors.black54,
                    actions: <Widget>[
                      new IconButton(
                          icon: (search!=null&&search.length>0)?new Icon(Icons.close):new Icon(Icons.search),
                          onPressed: (){
                            if(search!=null&&search.length>0){
                              selection = null;
                              setState((){
                                search = null;
                              });
                              textController.text = "";
                              scrollController.jumpTo(1.0);
                              filteredList.clear();
                              filteredList.addAll(fullList);
                              filteredList.sort((o1,o2){
                                if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
                                  return ((o2 as Crypto).mCap*100-(o1 as Crypto).mCap*100).round();
                                }
                                return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                              });
                              FocusScope.of(context).requestFocus(new FocusNode());
                            }else{
                              FocusScope.of(context).requestFocus(focusNode);
                            }
                          }
                      ),
                      new Container(
                          width:40.0,
                          padding: EdgeInsets.only(right:5.0),
                          child: new PopupMenuButton<String>(
                              itemBuilder: (BuildContext context)=><PopupMenuItem<String>>[
                                new PopupMenuItem<String>(
                                    child: const Text("Name Ascending"), value: "Name Ascending"),
                                new PopupMenuItem<String>(
                                    child: const Text("Name Descending"), value: "Name Descending"),
                                new PopupMenuItem<String>(
                                    child: const Text("Price Ascending"), value: "Price Ascending"),
                                new PopupMenuItem<String>(
                                    child: const Text("Price Descending"), value: "Price Descending"),
                                new PopupMenuItem<String>(
                                    child: const Text("Market Cap Ascending"), value: "Market Cap Ascending"),
                                new PopupMenuItem<String>(
                                    child: const Text("Market Cap Descending"), value: "Market Cap Descending"),
                                new PopupMenuItem<String>(
                                    child: const Text("24H Change Ascending"), value: "24H Change Ascending"),
                                new PopupMenuItem<String>(
                                    child: const Text("24H Change Descending"), value: "24H Change Descending")
                              ],
                              child: new Icon(Icons.sort),
                              onSelected:(s){
                                scrollController.jumpTo(1.0);
                                wait(){
                                  if(scrollController.position.pixels==1.0){
                                    new Timer(new Duration(milliseconds:100),((){setState((){
                                      if(s=="Name Ascending"){
                                        filteredList.sort((o1,o2){
                                          if((o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase())!=0){
                                            return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                                          }
                                          return ((o1 as Crypto).price-(o2 as Crypto).price).floor().toInt();
                                        });
                                      }else if(s=="Name Descending"){
                                        filteredList.sort((o1,o2){
                                          if((o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase())!=0){
                                            return (o2 as Crypto).name.toUpperCase().compareTo((o1 as Crypto).name.toUpperCase());
                                          }
                                          return ((o1 as Crypto).price-(o2 as Crypto).price).floor().toInt();
                                        });
                                      }else if(s=="Price Ascending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).price!=(o2 as Crypto).price)){
                                            return ((o1 as Crypto).price*1000000000-(o2 as Crypto).price*1000000000).round();
                                          }
                                          return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                                        });
                                      }else if(s=="Price Descending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).price!=(o2 as Crypto).price)){
                                            return ((o2 as Crypto).price*1000000000-(o1 as Crypto).price*1000000000).round();
                                          }
                                          return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                                        });
                                      }else if(s=="Market Cap Ascending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
                                            return ((o1 as Crypto).mCap*100-(o2 as Crypto).mCap*100).round();
                                          }
                                          return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                                        });
                                      }else if(s=="Market Cap Descending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
                                            return ((o2 as Crypto).mCap*100-(o1 as Crypto).mCap*100).round();
                                          }
                                          return (o1 as Crypto).name.toUpperCase().compareTo((o2 as Crypto).name.toUpperCase());
                                        });
                                      }else if(s=="24H Change Ascending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).twentyFourHours!=(o2 as Crypto).twentyFourHours)){
                                            return ((o1 as Crypto).twentyFourHours*100-(o2 as Crypto).twentyFourHours*100).round();
                                          }
                                          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
                                        });
                                      }else if(s=="24H Change Descending"){
                                        filteredList.sort((o1,o2){
                                          if(((o1 as Crypto).twentyFourHours!=(o2 as Crypto).twentyFourHours)){
                                            return ((o2 as Crypto).twentyFourHours*100-(o1 as Crypto).twentyFourHours*100).round();
                                          }
                                          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
                                        });
                                      }
                                    });}));
                                  }else{
                                    scrollController.jumpTo(1.0);
                                    new Timer(Duration.zero,wait());
                                  }
                                }
                                wait();
                              }
                          )
                      )
                    ]
                ),
                body: new Container(
                    color: bright?Colors.white:Colors.grey[700],
                    child: new Center(
                        child: new RefreshIndicator(
                            child: new ListView.builder(
                                controller: scrollController,
                                itemCount: filteredList.length,
                                itemBuilder: (BuildContext context,int index){
                                  if(firstTime && index==0){
                                    return new DescribedFeatureOverlay(
                                        doAction: (f){
                                          for(int i = 0; i<favList.length;i++){
                                            Crypto temp = (fullList[((favList[i] as FavCrypto).friendIndex)] as Crypto);
                                            temp.color = temp.color==Colors.black12?Colors.black26:Colors.black12;
                                            temp.favIndex = null;
                                          }
                                          favList.clear();
                                          featureCount++;
                                          wentBack = true;
                                          Crypto temp = (filteredList[0] as Crypto);
                                          setState((){temp.color = temp.color==Colors.black12?Colors.black26:Colors.black12;});
                                          favList.add(new FavCrypto(temp.slug,favList.length,temp.index,temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap,temp.image,temp.shortName,temp.smallImage,temp.circSupply,temp.totalSupply,temp.maxSupply,temp.volume24h));
                                          temp.favIndex = favList.length-1;
                                          String dataBuild = "";
                                          for(int i = 0;i<favList.length;i++){
                                            dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                                          }
                                          storage.writeData(dataBuild);
                                          HomePageState.filteredList.clear();
                                          Navigator.of(context).pop();
                                        },
                                        featureId: features[1],
                                        color: Colors.teal,
                                        icon: Icons.add,
                                        title: "Items",
                                        description: new Column(
                                            children: [
                                             new Text(
                                                "Tap on an item in the list to add it. The format for each item is as follows:",
                                                style: new TextStyle(
                                                  fontSize: 16.0,
                                                  color: Colors.white.withOpacity(0.9),
                                                )
                                              ),
                                              new Container(
                                                height: 120.0,
                                                  padding: EdgeInsets.only(top:10.0),
                                                  child: new FlatButton(
                                                    padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
                                                    color: Colors.black87,
                                                    child: new Row(
                                                      children: <Widget>[
                                                        // ignore: conflicting_dart_import
                                                        new Expanded(child: new Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              new Row(
                                                                  children: [
                                                                    new Text("Name",style: new TextStyle(fontSize:20.0,color:Colors.white))
                                                                  ]
                                                              ),
                                                              new Row(
                                                                  children: [
                                                                    Image.asset("icon/platypus2.png",height:32.0,width:32.0),
                                                                    new Text(" TKR",style: new TextStyle(fontSize:15.0,color:Colors.white))
                                                                  ]
                                                              )
                                                            ]
                                                        )),
                                                        new Column(
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              new Text("Price",style: new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold,color:Colors.white)),
                                                              new Text("Market cap",style: new TextStyle(color:Colors.grey,fontSize:12.0)),
                                                              (fullList[0] as Crypto).smallImage
                                                            ]
                                                        ),
                                                        new Expanded(
                                                            child: new Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                              children: <Widget>[
                                                                new Text("1H %Change",style: new TextStyle(fontSize:10.0,color:Colors.white)),
                                                                new Text("1D %Change",style: new TextStyle(fontSize:10.0,color:Colors.white)),
                                                                new Text("1W %Change",style: new TextStyle(fontSize:10.0,color:Colors.white)),
                                                              ],
                                                            )
                                                        )
                                                      ],
                                                    ),
                                                    onPressed: (){}
                                                 )
                                              )
                                            ]
                                        ),
                                        child: filteredList[index]
                                    );
                                  }
                                  return filteredList[index];
                                }
                            ),
                            onRefresh: (){
                              if(!kill){
                                done = false;
                                setUpData();
                                completer = new Completer<Null>();
                                wait() {
                                  if (done) {
                                    int i = 0;
                                    doubleWait(){
                                      if(i==favList.length){
                                        completer.complete();
                                      }else{
                                        new Timer(Duration.zero,doubleWait);
                                      }
                                    }
                                    for(i = 0; i<favList.length;i++){
                                      Crypto temp = fullList[(favList[i] as FavCrypto).friendIndex];
                                      (favList[i] as FavCrypto).price = temp.price;
                                      (favList[i] as FavCrypto).oneHour = temp.oneHour;
                                      (favList[i] as FavCrypto).twentyFourHours = temp.twentyFourHours;
                                      (favList[i] as FavCrypto).sevenDays = temp.sevenDays;
                                      (favList[i] as FavCrypto).mCap = temp.mCap;
                                      (favList[i] as FavCrypto).circSupply = temp.circSupply;
                                      (favList[i] as FavCrypto).totalSupply = temp.totalSupply;
                                      (favList[i] as FavCrypto).maxSupply = temp.maxSupply;
                                      (favList[i] as FavCrypto).volume24h = temp.volume24h;
                                    }
                                    doubleWait();
                                  } else {
                                    new Timer(Duration.zero, wait);
                                  }
                                }
                                wait();
                                setState((){});
                                return completer.future;
                              }else{
                                return new Completer<Null>().future;
                              }
                            }
                        )
                    )
                )
            )),
        onWillPop: (){
          kill = true;
          HomePageState.filteredList.clear();
          return new Future((){return completer.isCompleted && done;});
        }
    );
  }
  bool kill = false;
}

bool buttonPressed = false;

Completer completer = new Completer<Null>()..complete();

class FavCrypto extends StatefulWidget{

  int filteredIndex;

  double circSupply;

  double totalSupply;

  double maxSupply;

  double volume24h;

  CachedNetworkImage smallImage;

  String shortName;

  CachedNetworkImage image;

  double mCap;

  final String slug;

  String name;

  int id;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int index,friendIndex;

  ObjectKey key;

  Color color = bright?Colors.black12:Colors.black87;

  FavCrypto(this.slug,this.index,this.friendIndex,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName,this.smallImage,this.circSupply,this.totalSupply,this.maxSupply,this.volume24h);

  @override
  FavCryptoState createState() => new FavCryptoState();
}

int removed = 0;

int friendSwap = -1;

class FavCryptoState extends State<FavCrypto>{

  bool isPressed = false;

  String displayedName;

  bool wrap = false;

  bool done = false;

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    if(!widget.name.contains(" ")){
      displayedName = widget.name;
      wrap = false;
    }else{
      displayedName = widget.name.replaceAll(" ","\n");
      wrap = true;
    }

    widget.color = !isPressed?bright?Colors.black12:Colors.black87:bright?Colors.black26:Colors.black54;

    widget.key = new ObjectKey(widget.slug);

    return new Container(
        height: !wrap?displayGraphs?120.0:100.0:null,
        padding: EdgeInsets.only(top:10.0),
        child: new GestureDetector(
            onLongPress: (){
              if(firstTime){
                context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){firstTime = false;featureCount = 100;});
              }
              if(!isInSwap && favList.length==HomePageState.filteredList.length){
                if(widget.color==Colors.black26||widget.color==Colors.black54){
                  setState((){
                    widget.color = bright?Colors.black12:Colors.black87;
                    isInSwap = false;
                    friendSwap = -1;
                  });
                }else{
                  setState((){
                    widget.color = bright?Colors.black26:Colors.black54;
                    isPressed = true;
                    isInSwap = true;
                    friendSwap = widget.index;
                    wait(){
                      if(widget.index!=friendSwap){
                        setState((){});
                        isPressed = false;
                      }else{
                        new Timer(Duration.zero,wait);
                      }
                    }
                    wait();
                  });
                }
              }
            },
            child: new Dismissible(
                direction: completer.isCompleted?DismissDirection.endToStart:null,
                key: widget.key,
                onDismissed: (direction){
                  if(completer.isCompleted){
                    if(firstTime){
                      context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){firstTime = false;featureCount = 100;});
                    }
                    HomePageState.filteredList.remove(favList[widget.index]);
                    favList.removeAt(widget.index);
                    (fullList[widget.friendIndex] as Crypto).favIndex = null;
                    (fullList[widget.friendIndex] as Crypto).color = Colors.black12;
                    for(int i = 0;i<favList.length;i++){
                      (favList[i] as FavCrypto).index = i;
                      (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex = i;
                    }
                    context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){});
                    String dataBuild = "";
                    for(int i = 0;i<favList.length;i++){
                      dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                    }
                    storage.writeData(dataBuild);
                  }else{
                    wait(){
                      if(completer.isCompleted){
                        HomePageState.filteredList.remove(favList[widget.index]);
                        favList.removeAt(widget.index);
                        (fullList[widget.friendIndex] as Crypto).favIndex = null;
                        (fullList[widget.friendIndex] as Crypto).color = Colors.black12;
                        for(int i = 0;i<favList.length;i++){
                          (favList[i] as FavCrypto).index = i;
                          (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex = i;
                        }
                        context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){});
                        String dataBuild = "";
                        for(int i = 0;i<favList.length;i++){
                          dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                        }
                        storage.writeData(dataBuild);
                      }else{
                        new Timer(Duration.zero,wait);
                      }
                    }
                    wait();
                  }
                },
                background: new Container(color:Colors.red),
                child: new FlatButton(
                    padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
                    color: widget.color,
                    child: new Row(
                      children: <Widget>[
                        // ignore: conflicting_dart_import
                        new Expanded(child: new Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              new Row(
                                  children: [
                                    new Text(!wrap?widget.name:displayedName,style: new TextStyle(fontSize:(!wrap?(((6/widget.name.length)<1)?(22.0*6/widget.name.length):22.0):16.0)))
                                  ]
                              ),
                              new Row(
                                  children: [
                                    widget.image,
                                    new Text(" "+widget.shortName,style: new TextStyle(fontSize:((5/widget.shortName.length)<1)?(15.0*5/widget.name.length):15.0))
                                  ]
                              )
                            ]
                        )),
                        new Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              new Text((widget.price>=0?widget.price>1?symbol+new NumberFormat.currency(symbol:"",decimalDigits: widget.price<100000?2:0).format(widget.price):symbol+(widget.price>.000001?widget.price.toStringAsFixed(6):widget.price.toStringAsFixed(7)):"N/A"),style: new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold)),
                              new Text((widget.mCap>=0?widget.mCap>1?symbol+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(widget.mCap):symbol+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:bright?Colors.black45:Colors.grey,fontSize:12.0)),
                              displayGraphs?widget.smallImage:new Container()
                            ]
                        ),
                        new Expanded(
                            child: new Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                widget.oneHour!=-1000000.0?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString()+"\%",style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                                widget.twentyFourHours!=-1000000.0?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString()+"\%",style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                                widget.sevenDays!=-1000000.0?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString()+"\%",style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                              ],
                            )
                        )
                      ],
                    ),
                    onPressed: (){
                      if(firstTime){
                        context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){firstTime = false;featureCount = 100;});
                      }
                      if(completer.isCompleted){
                        if(!isInSwap){
                          Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.slug,widget.name,widget.id,widget.oneHour,widget.twentyFourHours,widget.sevenDays,widget.price,widget.mCap,widget.image,widget.shortName,widget.circSupply,widget.totalSupply,widget.maxSupply,widget.volume24h)));
                        }else{
                          setState((){
                            if(friendSwap!=-1){
                              isInSwap = false;
                              FavCrypto temp = (favList[friendSwap] as FavCrypto);
                              temp.color = bright?Colors.black12:Colors.black87;
                              temp.index = widget.index;
                              favList.removeAt(friendSwap);
                              favList.insert(widget.index,temp);
                              for(int i = 0; i<favList.length;i++){
                                (favList[i] as FavCrypto).index = i;
                                (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex = i;
                              }
                              friendSwap = -1;
                              HomePageState.inSearch = false;
                              HomePageState.hasSearched = false;
                              context.ancestorStateOfType(new TypeMatcher<HomePageState>()).setState((){
                                HomePageState.filteredList.clear();
                                HomePageState.filteredList.addAll(favList);
                              });
                              String dataBuild = "";
                              for(int i = 0;i<favList.length;i++){
                                dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                              }
                              storage.writeData(dataBuild);
                            }
                          });
                        }
                      }
                    }
                )
            )
        ));
  }
}

class Crypto extends StatefulWidget{

  double circSupply;

  double totalSupply;

  double maxSupply;

  double volume24h;

  CachedNetworkImage smallImage;

  String shortName;

  CachedNetworkImage image;

  double mCap;

  String slug;

  int id;

  Color color;

  String name;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int favIndex;

  int index;

  Crypto(this.slug,this.color,this.index,this.name,this.id,this.image,this.shortName,this.smallImage);

  @override
  CryptoState createState() => new CryptoState();
}

class CryptoState extends State<Crypto>{

  String displayedName;

  bool wrap = false;

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context){

    if(!widget.name.contains(" ")){
      displayedName = widget.name;
      wrap = false;
    }else{
      displayedName = widget.name.replaceAll(" ","\n");
      wrap = true;
    }

    return new Container(
        height: !wrap?displayGraphs?120.0:100.0:null,
        key: new ObjectKey("full"+widget.slug),
        padding: EdgeInsets.only(top:10.0),
        child: new GestureDetector(child: new FlatButton(
            padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
            color: bright?widget.color:widget.color==Colors.black26?Colors.black87:Colors.black54,
            child: new Row(
              children: <Widget>[
                // ignore: conflicting_dart_import
                new Expanded(flex:3,child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      new Row(
                          children: [
                            new Text(!wrap?widget.name:displayedName,style: new TextStyle(fontSize:(!wrap?(((6/widget.name.length)<1)?(22.0*6/widget.name.length):22.0):16.0)))
                          ]
                      ),
                      new Row(
                          children: [
                            widget.image,
                            new Text(" "+widget.shortName,style: new TextStyle(fontSize:((5/widget.shortName.length)<1)?(15.0*5/widget.name.length):15.0))
                          ]
                      )
                    ]
                )),
                new Expanded(flex:4,child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      new Text((widget.price>=0?widget.price>1?symbol+new NumberFormat.currency(symbol:"",decimalDigits: widget.price<100000?2:0).format(widget.price):symbol+(widget.price>.000001?widget.price.toStringAsFixed(6):widget.price.toStringAsFixed(7)):"N/A"),style: new TextStyle(fontSize:20.0,fontWeight: FontWeight.bold)),
                      new Text((widget.mCap>=0?widget.mCap>1?symbol+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(widget.mCap):symbol+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:bright?Colors.black45:Colors.grey,fontSize:12.0)),
                      displayGraphs?widget.smallImage:new Container()
                    ]
                )),
                new Expanded(flex:3,child: new Row(crossAxisAlignment: CrossAxisAlignment.center,mainAxisAlignment: MainAxisAlignment.end,children: [new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        widget.oneHour!=-1000000.0?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString()+"\%",style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                        widget.twentyFourHours!=-1000000.0?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString()+"\%",style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                        widget.sevenDays!=-1000000.0?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString()+"\%",style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                      ],
                ),
                new Icon(widget.color==Colors.black12?Icons.add:Icons.check)]))
              ]
            ),
            onPressed: (){
              if(completer.isCompleted){
                FocusScope.of(context).requestFocus(new FocusNode());
                setState((){widget.color = widget.color==Colors.black12?Colors.black26:Colors.black12;});
                Scaffold.of(context).removeCurrentSnackBar();
                Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(widget.color==Colors.black26?"Added":"Removed"),duration: new Duration(milliseconds: 500)));
                if(widget.color==Colors.black26){
                  favList.add(new FavCrypto(widget.slug,favList.length,widget.index,widget.name,widget.id,widget.oneHour,widget.twentyFourHours,widget.sevenDays,widget.price,widget.mCap,widget.image,widget.shortName,widget.smallImage,widget.circSupply,widget.totalSupply,widget.maxSupply,widget.volume24h));
                  widget.favIndex = favList.length-1;
                  String dataBuild = "";
                  for(int i = 0;i<favList.length;i++){
                    dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                  }
                  storage.writeData(dataBuild);
                }else{
                  favList.removeAt(widget.favIndex);
                  widget.favIndex = null;
                  for(int i = 0; i<favList.length;i++){
                    (favList[i] as FavCrypto).index = i;
                    (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex=i;
                  }
                  String dataBuild = "";
                  for(int i = 0;i<favList.length;i++){
                    dataBuild+=(favList[i] as FavCrypto).id.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                  }
                  storage.writeData(dataBuild);
                }
              }
            }
        ),
        onLongPress: (){
          Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.slug,widget.name,widget.id,widget.oneHour,widget.twentyFourHours,widget.sevenDays,widget.price,widget.mCap,widget.image,widget.shortName,widget.circSupply,widget.totalSupply,widget.maxSupply,widget.volume24h)));
        })
    );
  }
}

class ItemInfo extends StatefulWidget{

  double circSupply;

  double totalSupply;

  double maxSupply;

  double volume24h;

  bool firstBuild = true;

  CachedNetworkImage image;

  String slug;

  String name,shortName;

  int id;

  double price,oneHour,twentyFourHours,sevenDays,mCap;

  ItemInfo(this.slug,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName,this.circSupply,this.totalSupply,this.maxSupply,this.volume24h);

  @override
  ItemInfoState createState() => new ItemInfoState(this.slug,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName);
}

class ItemInfoState extends State<ItemInfo>{


  List<SimpleTimeSeriesChart> graphs = [];

  int selected;

  bool firstBuild = true;

  CachedNetworkImage image;

  String slug;

  String name,shortName;

  int id;

  double price,oneHour,twentyFourHours,sevenDays,mCap;

  ItemInfoState(this.slug,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName);

  @override
  void initState(){
    super.initState();
    graphs.length = 5;
    graphs[0] = new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,1,animate:false);
    graphs[1] = new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,7,animate:false);
    graphs[2] = new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,30,animate:false);
    graphs[3] = new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,180,animate:false);
    graphs[4] = new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,365,animate:false);
    selected = 0;
  }

  @override
  Widget build(BuildContext context){
    return new DefaultTabController(
        length:5,
        child: new Scaffold(
            appBar:new AppBar(
                title:new Text(name,style:new TextStyle(fontSize:25.0)),
                backgroundColor: Colors.black54,
                actions: [
                  new Row(
                      children: [
                        image,
                        new Text(" "+this.shortName)
                      ]
                  )
                ]
            ),
            body:new ListView(
                children:[
                  new Container(
                      color: Colors.black54,
                      child: new TabBar(
                          tabs: [
                            new Tab(icon: new Text("1D",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold))),
                            new Tab(icon: new Text("1W",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold))),
                            new Tab(icon: new Text("1M",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold))),
                            new Tab(icon: new Text("6M",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold))),
                            new Tab(icon: new Text("1Y",style:new TextStyle(fontSize:25.0,fontWeight: FontWeight.bold)))
                          ]
                      )
                  ),
                  new Container(
                      height: 233.0,
                      child: new TabBarView(
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                            graphs[0],graphs[1],graphs[2],graphs[3],graphs[4]
                          ]
                      )
                  ),
                  new Info(this.slug,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName,widget.circSupply,widget.totalSupply,widget.maxSupply,widget.volume24h)
                ]
            )
        )
    );
  }
}

class Info extends StatelessWidget{

  double circSupply;

  double totalSupply;

  double maxSupply;

  double volume24h;

  int selected;

  bool firstBuild = true;

  CachedNetworkImage image;

  String slug;

  String name,shortName;

  int id;

  double price,oneHour,twentyFourHours,sevenDays,mCap;

  double fontSize = 20.0;

  Info(this.slug,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName,this.circSupply,this.totalSupply,this.maxSupply,this.volume24h);

  @override
  Widget build(BuildContext context){
    return new Container(
        child: new Center(
            child: new Column(
                children: [
                  new Text("",style: new TextStyle(fontSize:5.0)),
                  new InfoPiece("Price",price,fontSize,2,price>.000001?6:7,true),
                  new InfoPiece("Market Cap",mCap,fontSize,0,2,true),
                  new Container(
                      padding: EdgeInsets.only(top:5.0),
                      child: new Container(
                          color: bright?Colors.black12:Colors.black87,
                          padding: EdgeInsets.only(top:10.0,bottom:10.0),
                          child: new Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                new Expanded(child:new Text("Change 1H",style: new TextStyle(fontSize:fontSize))),
                                oneHour!=-1000000.0?new Text(((oneHour>=0)?"+":"")+oneHour.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((oneHour>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
                              ]
                          )
                      )
                  ),
                  new Container(
                      padding: EdgeInsets.only(top:5.0),
                      child: new Container(
                          color: bright?Colors.black12:Colors.black87,
                          padding: EdgeInsets.only(top:10.0,bottom:10.0),
                          child: new Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                new Expanded(child:new Text("Change 1D",style: new TextStyle(fontSize:fontSize))),
                                twentyFourHours!=-1000000.0?new Text(((twentyFourHours>=0)?"+":"")+twentyFourHours.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
                              ]
                          )
                      )
                  ),
                  new Container(
                      padding: EdgeInsets.only(top:5.0),
                      child: new Container(
                          color: bright?Colors.black12:Colors.black87,
                          padding: EdgeInsets.only(top:10.0,bottom:10.0),
                          child: new Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                new Expanded(child:new Text("Change 1W",style: new TextStyle(fontSize:fontSize))),
                                sevenDays!=-1000000.0?new Text(((sevenDays>=0)?"+":"")+sevenDays.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
                              ]
                          )
                      )
                  ),
                  new InfoPiece("Circulating Supply",circSupply,fontSize,0,0,false),
                  new InfoPiece("Total Supply",totalSupply,fontSize,0,0,false),
                  new InfoPiece("Max Supply",maxSupply,fontSize,0,0,false),
                  new InfoPiece("24H Volume",volume24h,fontSize,0,2,true),
                ]
            )
        )
    );
  }
}

class InfoPiece extends StatelessWidget{

  double fontSize;

  String name;

  double info;

  int first,second;

  bool useSymbol;

  InfoPiece(this.name,this.info,this.fontSize,this.first,this.second,this.useSymbol);

  @override
  Widget build(BuildContext context){
    return new Container(
        padding: EdgeInsets.only(top:5.0),
        child: new Container(
          color: bright?Colors.black12:Colors.black87,
          padding: EdgeInsets.only(top:10.0,bottom:10.0),
          child: new Row(
              children: [
                new Expanded(child: new Text(name,style:new TextStyle(fontSize:fontSize),textAlign: TextAlign.left)),
                new Text((info>=0?info>1?new NumberFormat.currency(symbol:useSymbol?symbol:"",decimalDigits: first).format(info):new NumberFormat.currency(symbol:useSymbol?symbol:"",decimalDigits: second).format(info):"N/A"),style:new TextStyle(fontSize: fontSize))
              ]
          ),
        )
    );
  }
}

List<int> inds;

class DataStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return new File('$path/data.txt');
  }

  Future<List<int>> readData() async {
    try {
      final file = await _localFile;

      String contents = await file.readAsString();

      List<String> list = contents.split(" ");

      List<int> bigList = new List<int>();

      for(String s in list){
        bigList.add(int.parse(s));
      }

      return bigList;
    } catch (e) {
      return null;
    }
  }

  Future<File> writeData(String data) async {
    final file = await _localFile;
    return data!=""?file.writeAsString(data.substring(0,data.length-1)):file.writeAsString("");
  }

}

class SimpleTimeSeriesChart extends StatefulWidget{

  int days;

  double price;

  String shortName;

  List<charts.Series<TimeSeriesPrice,DateTime>> seriesList;
  final bool animate;

  SimpleTimeSeriesChart(this.seriesList,this.shortName,this.price,this.days,{this.animate});

  @override
  SimpleTimeSeriesChartState createState() => new SimpleTimeSeriesChartState(seriesList,shortName,price,days,animate:animate);
}

class SimpleTimeSeriesChartState extends State<SimpleTimeSeriesChart> {
  bool canLoad = true;
  int days;
  List<charts.Series<TimeSeriesPrice,DateTime>> seriesList;
  final bool animate;
  String shortName;
  double count = 0.0;
  double price;
  http.Response response;
  bool firstBuild = true;
  int total = 100000;
  double selectedPrice = -1.0;
  DateTime selectedTime;

  SimpleTimeSeriesChartState(this.seriesList, this.shortName,this.price,this.days,{this.animate});

  @override
  Widget build(BuildContext context) {
    if(firstBuild){
      http.get(
          days!=-1?Uri.encodeFull("http://coincap.io/history/"+days.toString()+"day/"+shortName):Uri.encodeFull("http://coincap.io/history/"+shortName)
      ).then((value){
        response = value;
        createChart(response,shortName).then((value){
          seriesList = value;
        });
        setState((){});
      });
      firstBuild = false;
    }
    return count>=total?new Column(children: [new Container(width: 350.0*MediaQuery.of(context).size.width/375.0,height:200.0,child: new charts.TimeSeriesChart(
        seriesList,
        animate: animate,
        primaryMeasureAxis: new charts.NumericAxisSpec(
            tickProviderSpec: new charts.BasicNumericTickProviderSpec(desiredTickCount: 5,zeroBound: false,dataIsInWholeNumbers: false),
            tickFormatterSpec: new charts.BasicNumericTickFormatterSpec(
                new NumberFormat(symbol.toString().replaceAll("\.", "")+"###,###,###,###,###,###,###,###,###,###,###,###,###,###,###,###.###########","en_US")
            ),
            renderSpec: new charts.GridlineRendererSpec(
                labelStyle: new charts.TextStyleSpec(
                    color: bright?charts.MaterialPalette.black:charts.MaterialPalette.white
                ),
                lineStyle: new charts.LineStyleSpec(
                    color: bright?charts.MaterialPalette.gray.shade400:charts.MaterialPalette.white
                )
            )
        ),
        domainAxis: charts.DateTimeAxisSpec(
            tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                day: new charts.TimeFormatterSpec(
                    format: 'd',
                    transitionFormat: days==1?'MM/dd hh/mm a':days==7?'MM/dd':days==30?'MM/dd':days==180?"YY/MM":"YY/MM"
                )
            ),
            tickProviderSpec: days!=1?new charts.DayTickProviderSpec(
                increments: days==7?[1]:days==30?[5]:days==180?[40]:days==365?[60]:[365]
            ):new charts.AutoDateTimeTickProviderSpec(),
            renderSpec: new charts.SmallTickRendererSpec(
                labelStyle: new charts.TextStyleSpec(
                    color: bright?charts.MaterialPalette.black:charts.MaterialPalette.white
                ),lineStyle: new charts.LineStyleSpec(
                color: bright?charts.MaterialPalette.black:charts.MaterialPalette.white)
            )
        ),
        behaviors: [
          new charts.LinePointHighlighter(
              showHorizontalFollowLine: true, showVerticalFollowLine: true),
          new charts.SelectNearest(
              eventTrigger: charts.SelectNearestTrigger.tapAndDrag)
        ],
        selectionModels: [
          new charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              listener: (charts.SelectionModel model){
                final selectedDatum = model.selectedDatum;
                if(selectedDatum.isNotEmpty){
                  setState((){
                    selectedPrice = selectedDatum[0].datum.price;
                    selectedTime = selectedDatum[0].datum.time;
                  });
                }else{
                  setState((){
                    selectedPrice = -1.0;
                    selectedTime = null;
                  });
                }
              }
          )
        ]
    )),
    new Container(
        height:33.0,
        child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              new Text((selectedTime!=null?"Date: "+new DateFormat("yyyy/MM/dd").add_jm().format(selectedTime):"")),
              new Text((selectedPrice>=0?"Price: "+new NumberFormat.currency(symbol:symbol,decimalDigits: selectedPrice>1?2:selectedPrice>.000001?6:7).format(selectedPrice):""))
            ]
        )
    )
    ]):canLoad?new Container(height:233.0,padding:EdgeInsets.only(left:10.0,right:10.0),child:new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[new CircularProgressIndicator()]
    )):new Container(
        height:233.0,
        child: new Center(
            child: new Text("Sorry, this coin graph is not supported",style: new TextStyle(fontSize:17.0))
        )
    );
  }

  Future<List<charts.Series<TimeSeriesPrice, DateTime>>> createChart(http.Response response, String s) async {


    List<TimeSeriesPrice> data = [];

    Map<String, dynamic> info = json.decode(response.body);

    DateTime temp = DateTime.now();

    DateTime today = DateTime.now();

    if(response.body!="null"){
      temp = new DateTime.fromMillisecondsSinceEpoch(info["price"][info["price"].length-1][0]);

      temp = temp.add(new Duration(hours:-1*temp.hour,minutes:-1*temp.minute,seconds:-1*temp.second,milliseconds: -1*temp.millisecond,microseconds: -1*temp.microsecond));

      today = today.add(new Duration(hours:-1*today.hour,minutes:-1*today.minute,seconds:-1*today.second,milliseconds: -1*today.millisecond,microseconds: -1*today.microsecond));
    }

    if(response.body!="null"&&response.body!="{}"&&temp.isAtSameMomentAs(today)){
      setState((){total = info["price"].length-1;});
      data.length = total;
      for(int i = 0;i<total;i++){
        data[i] = new TimeSeriesPrice(new DateTime.fromMillisecondsSinceEpoch(info["price"][i][0]), info["price"][i][1]*1.0*usdRate);
        setState((){count++;});
      }
    }else{
      setState((){canLoad = false;});
    }
    setState((){});
    return [
      new charts.Series<TimeSeriesPrice, DateTime>(
        id: 'Prices',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (TimeSeriesPrice sales, _) => sales.time,
        measureFn: (TimeSeriesPrice sales, _) => sales.price,
        data: data,
      )
    ];
  }
}

class TimeSeriesPrice {
  final DateTime time;
  final double price;

  TimeSeriesPrice(this.time, this.price);
}

class ThemeInfo{
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return new File('$path/themeinfo.txt');
  }

  Future<List<String>> readData() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();

      if(contents.split(" ").length!=3){
        return null;
      }

      List<String> list = contents.split(" ");

      return list;
    } catch (e) {
      return null;
    }
  }

  Future<File> writeData(String data) async {
    final file = await _localFile;
    return file.writeAsString(data);
  }

}
