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

int itemCount = 1;

bool isInSwap = false;

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
    if(value==null || value.length!=2){
      themeInfo.writeData("0 1").then((f){
        bright = true;
        displayGraphs = true;
        firstTime = true;
        runApp(new MaterialApp(
            theme: new ThemeData(fontFamily: "MavenPro",brightness: bright?Brightness.light:Brightness.dark),
            home: new FeatureDiscovery(child: new HomePage())
        ));
      });
    }else{
      if(value[0]==1){
        bright = false;
      }else{
        bright = true;
      }
      if(value[1]==1){
        displayGraphs = true;
      }else{
        displayGraphs = false;
      }
      runApp(new MaterialApp(
          theme: new ThemeData(fontFamily: "MavenPro",brightness: bright?Brightness.light:Brightness.dark),
          home: new FeatureDiscovery(child: new HomePage())
      ));
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
          imageUrl: "https://s2.coinmarketcap.com/generated/sparklines/web/7d/usd/"+data["data"][i]["id"].toString()+'.png',width:120.0,key: new Key("Graph for "+data["data"][i]["name"].toString()),fadeInDuration: const Duration(milliseconds:100),placeholder: Image.asset("icon/platypus2.png",height:35.0,width:0.0)
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
    //print(count);
    //print(itemCount);
    http.Response r;
    while(count<itemCount){
      //print(count);
      r = await http.get(
          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/?start="+count.toString())
      );
      data = json.decode(r.body);
      Map<String,dynamic> map = data["data"];
      for(Map<String,dynamic> s in map.values){
        int place = idIndex.putIfAbsent(s["id"], ()=>-1);
        (fullList[place] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]:-1.0;
        (fullList[place] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1.0;
        (fullList[place] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1.0;
        (fullList[place] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1.0;
        (fullList[place] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]:-1.0;
        (fullList[place] as Crypto).circSupply = s["circulating_supply"]!=null?s["circulating_supply"]:-1.0;
        (fullList[place] as Crypto).totalSupply = s["total_supply"]!=null?s["total_supply"]:-1.0;
        (fullList[place] as Crypto).maxSupply = s["max_supply"]!=null?s["max_supply"]:-1.0;
        (fullList[place] as Crypto).volume24h = s["quotes"]["USD"]["volume_24h"]!=null?s["quotes"]["USD"]["volume_24h"]:-1.0;
        realCount++;
        setState((){});
      }
      count+=100;
    }
    //print(count.toString()+" "+itemCount.toString());
    //print("Data Retrieved and Processed");
    if(first){
      buildCount = 199;
    }
    first = false;
    //print(data.toString());
    done = true;
    //print(fullList);
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

  String search = null;

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
    //print(buildCount);
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
        firstLoad = true;
        if(firstTime){
          FeatureDiscovery.discoverFeatures(context, [features[0]]);
        }
        setState((){});
      });
    }
    if(firstTime && featureCount==2 && loadGood){
      new Timer(new Duration(seconds:1),(){FeatureDiscovery.discoverFeatures(context, features.sublist(2,features.length));loadGood = false;});
    }
    return firstLoad?new Scaffold(
        appBar:new AppBar(
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
                color: Colors.blue,
                title: 'Searching',
                icon: Icons.search,
                description: 'Tap here to search your favorites list',
                child: new IconButton(
                    icon: new Icon(!hasSearched?Icons.search:Icons.clear),
                    onPressed: (){
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
                  color: Colors.blue,
                  title: 'Sorting',
                  icon: Icons.filter_list,
                  description: 'Tap here to sort your favorites list',
                  child: new Container(
                    padding: EdgeInsets.only(left:5.0,right:10.0),
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
                        child: new Icon(Icons.filter_list),
                        onSelected:(s){
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
                    f();
                  },
                  featureId: features[4],
                  color: Colors.blue,
                  title: 'Extra',
                  icon: Icons.more_vert,
                  description: 'Tap here to open settings, report a bug, or submit a review',
                  child: new PopupMenuButton<String>(
                    onSelected: (String selected){
                      if(selected=="Settings"){
                        Navigator.push(context,new MaterialPageRoute(builder: (context) => new Settings()));
                      }else if(selected=="Rate us"){
                        if(Platform.isIOS){
                          launchIOS() async{
                            const url = 'https://www.apple.com';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchIOS();
                        }else if(Platform.isAndroid){
                          launchAndroid() async{
                            const url = 'https://www.google.com';
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
                            const url = 'mailto:blakeplatypus@gmail.com?subject=Bug%20Report&body=Description%20of%20Bug:%0A%0A%0ASteps%20to%20reproduce%20error:%0A%0A%0AAttach%20any%20relevant%20screenshots%20below:%0A%0A%0AThanks%20for%20your%20report!';
                            if(await canLaunch(url)) {
                              await launch(url);
                            }else{
                              throw 'Could not launch $url';
                            }
                          }
                          launchIOS();
                        }else if(Platform.isAndroid){
                          launchAndroid() async{
                            const url = 'mailto:blakeplatypus@gmail.com?subject=Bug%20Report&body=Description%20of%20Bug:%0A%0A%0ASteps%20to%20reproduce%20error:%0A%0A%0AAttach%20any%20relevant%20screenshots%20below:%0A%0A%0AThanks%20for%20your%20report!';
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
                                          new Text("\nPlatypus Crypto V1.0.3"),
                                          new Text("2018© Blake Bottum and Caleb Jiang",style: new TextStyle(fontWeight:FontWeight.bold))
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
                          child: const Text("About"), value: "About"),
                    ],
                    child: new Icon(Icons.more_vert)
                )
              )
            ]
        ),
        floatingActionButton: (done && completer.isCompleted)?new DescribedFeatureOverlay(
            featureId: features[0],
            color: Colors.blue,
            title: 'Adding',
            icon: Icons.add,
            description: 'Tap here to add a crypto currency to your favorites list',
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
                  child: new ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (bc,i){
                          if(firstTime && i==0){
                            return new DescribedFeatureOverlay(
                                featureId: features[5],
                                color: Colors.blue,
                                icon: Icons.info,
                                title: "More Info",
                                description: "Click on an item for more info and graphs. Swipe to the left to remove an item and press and hold and click on another item to change its position",
                                child: filteredList[0],
                                doAction: (f){
                                  f();
                                  FavCrypto temp = (filteredList[0] as FavCrypto);
                                  firstTime = false;
                                  Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(temp.slug,temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap,temp.image,temp.shortName,temp.circSupply,temp.totalSupply,temp.maxSupply,temp.volume24h)));
                                }
                            );
                          }
                          return filteredList[i];

                      },
                      controller: scrollController,
                      physics: new AlwaysScrollableScrollPhysics()
                  ),
                  onRefresh: (){
                    completer = new Completer<Null>();
                    done = false;
                    setUpData();
                    wait() {
                      if (done) {
                        for(int i = 0; i<favList.length;i++){
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
                        completer.complete();
                      } else {
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

  @override
  Widget build(BuildContext context){
    return new Scaffold(
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
                                      bright = !bright;
                                      showDialog(
                                          barrierDismissible: false,
                                          context:context,
                                          builder: (BuildContext context)=>new AlertDialog(
                                              title: new Text("Are you sure?"),
                                              content: new Text("The application will close if you select this option"),
                                              actions: <Widget>[
                                                new FlatButton(
                                                  onPressed: (){bright = !bright;Navigator.of(context).pop(false);},
                                                  child: new Text('No'),
                                                ),
                                                new FlatButton(
                                                    onPressed: (){
                                                      if(dark==true){
                                                        themeInfo.writeData("1"+(displayGraphs?" 1":" 0")).then((file){
                                                          exit(0);
                                                        });
                                                      }else{
                                                        themeInfo.writeData("0"+(displayGraphs?" 1":" 0")).then((file){
                                                          exit(0);
                                                        });
                                                      }
                                                    },
                                                    child: new Text('Yes')
                                                )
                                              ]
                                          )
                                      );
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
                                          setState((){
                                            displayGraphs = !displayGraphs;
                                          });
                                          themeInfo.writeData((bright?"0":"1")+(displayGraphs?" 1":" 0"));
                                        }
                                    ),
                                  ]
                              )
                          )
                      )

                    ]
                )
            )
        )
    );
  }
}

List<Widget> favList = [

];

List<Widget> fullList = [
];

class CryptoList extends StatefulWidget{

  @override
  CryptoListState createState() => new CryptoListState();
}

class CryptoListState extends State<CryptoList>{

  Future<String> setUpData() async{
    int count = 1;
    http.Response r;
    while(count<itemCount+1){
      r = await http.get(
          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/?start="+count.toString())
      );
      data = json.decode(r.body);
      Map<String,dynamic> map = data["data"];
      for(Map<String,dynamic> s in map.values){
        int place = idIndex.putIfAbsent(s["id"], ()=>-1);
        (fullList[place] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]:-1.0;
        (fullList[place] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1.0;
        (fullList[place] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1.0;
        (fullList[place] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1.0;
        (fullList[place] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]:-1.0;
        (fullList[place] as Crypto).circSupply = s["circulating_supply"]!=null?s["circulating_supply"]:-1.0;
        (fullList[place] as Crypto).totalSupply = s["total_supply"]!=null?s["total_supply"]:-1.0;
        (fullList[place] as Crypto).maxSupply = s["max_supply"]!=null?s["max_supply"]:-1.0;
        (fullList[place] as Crypto).volume24h = s["quotes"]["USD"]["volume_24h"]!=null?s["quotes"]["USD"]["volume_24h"]:-1.0;
      }
      count+=100;
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
        Timer t = new Timer(const Duration(seconds:4),(){
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
                          padding: EdgeInsets.only(right:10.0),
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
                              child: new Icon(Icons.filter_list),
                              onSelected:(s){
                                setState(() {
                                  scrollController.jumpTo(1.0);
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
                                });
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
                                        color: Colors.blue,
                                        icon: Icons.add,
                                        title: "Items",
                                        description: "Just click on an item in the list to add it! The format for each item is as follows: Price in the middle in bold, Market cap below price, 1H change on right of box on top, 1D change in middle, and 1W change on bottom",
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
                                    for(int i = 0; i<favList.length;i++){
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
                                    completer.complete();
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

    widget.key = new ObjectKey(widget.slug);
    return new Container(
        height: !wrap?displayGraphs?120.0:100.0:null,
        padding: EdgeInsets.only(top:10.0),
        child: new GestureDetector(
            onLongPress: (){
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
                    isInSwap = true;
                    friendSwap = widget.index;
                    wait(){
                      if(widget.index!=friendSwap){
                        setState((){});
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
                              new Text((widget.price!=-1?widget.price>1?"\$"+new NumberFormat.currency(symbol:"",decimalDigits: 2).format(widget.price):"\$"+(widget.price>.000001?widget.price.toStringAsFixed(6):widget.price.toStringAsFixed(7)):"N/A"),style: new TextStyle(fontSize:22.0,fontWeight: FontWeight.bold)),
                              new Text((widget.mCap!=-1?widget.mCap>1?"\$"+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(widget.mCap):"\$"+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:bright?Colors.black45:Colors.grey,fontSize:12.0)),
                              displayGraphs?widget.smallImage:new Container()
                            ]
                        ),
                        new Expanded(
                            child: new Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                widget.oneHour!=-1?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString()+"\%",style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                                widget.twentyFourHours!=-1?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString()+"\%",style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                                widget.sevenDays!=-1?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString()+"\%",style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                              ],
                            )
                        )
                      ],
                    ),
                    onPressed: (){
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
        child: new FlatButton(
            padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
            color: bright?widget.color:widget.color==Colors.black26?Colors.black87:Colors.black54,
            child: new Row(
              children: <Widget>[
                // ignore: conflicting_dart_import
                new Expanded(child: new Column(
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
                new Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      new Text((widget.price!=-1?widget.price>1?"\$"+new NumberFormat.currency(symbol:"",decimalDigits: 2).format(widget.price):"\$"+(widget.price>.000001?widget.price.toStringAsFixed(6):widget.price.toStringAsFixed(7)):"N/A"),style: new TextStyle(fontSize:22.0,fontWeight: FontWeight.bold)),
                      new Text((widget.mCap!=-1?widget.mCap>1?"\$"+new NumberFormat.currency(symbol:"",decimalDigits: 0).format(widget.mCap):"\$"+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:bright?Colors.black45:Colors.grey,fontSize:12.0)),
                      displayGraphs?widget.smallImage:new Container()
                    ]
                ),
                new Expanded(
                    child: new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        widget.oneHour!=-1?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString()+"\%",style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                        widget.twentyFourHours!=-1?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString()+"\%",style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                        widget.sevenDays!=-1?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString()+"\%",style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                      ],
                    )
                ),
                new Icon(widget.color==Colors.black12?Icons.add:Icons.check)
              ],
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
                  //print(widget.favIndex);
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
                  //print(dataBuild);
                  storage.writeData(dataBuild);
                }
              }
            }
        )
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
    graphs[0]=new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,1,animate:false);
    graphs[1]=new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,7,animate:false);
    graphs[2]=new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,30,animate:false);
    graphs[3]=new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,180,animate:false);
    graphs[4]=new SimpleTimeSeriesChart(new List<charts.Series<TimeSeriesPrice,DateTime>>(),shortName,price,365,animate:false);
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
                      height: 232.0,
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
                  new InfoPiece("Price",price,fontSize,2,price>.000001?6:7),
                  new InfoPiece("Market Cap",mCap,fontSize,0,2),
                  new Container(
                      padding: EdgeInsets.only(top:5.0),
                      child: new Container(
                          color: bright?Colors.black12:Colors.black87,
                          padding: EdgeInsets.only(top:10.0,bottom:10.0),
                          child: new Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                new Expanded(child:new Text("Change 1H",style: new TextStyle(fontSize:fontSize))),
                                oneHour!=-1?new Text(((oneHour>=0)?"+":"")+oneHour.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((oneHour>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
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
                                twentyFourHours!=-1?new Text(((twentyFourHours>=0)?"+":"")+twentyFourHours.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
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
                                sevenDays!=-1?new Text(((sevenDays>=0)?"+":"")+sevenDays.toString()+"\%",style:new TextStyle(fontSize:fontSize,color:((sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A",style: new TextStyle(fontSize:fontSize))
                              ]
                          )
                      )
                  ),
                  new InfoPiece("Circulating Supply",circSupply,fontSize,0,2),
                  new InfoPiece("Total Supply",totalSupply,fontSize,0,2),
                  new InfoPiece("Max Supply",maxSupply,fontSize,0,2),
                  new InfoPiece("24H Volume",volume24h,fontSize,0,2),
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

  InfoPiece(this.name,this.info,this.fontSize,this.first,this.second);

  @override
  Widget build(BuildContext context){
    return new Container(
        padding: EdgeInsets.only(top:5.0),
        child: new Container(
          color: bright?Colors.black12:Colors.black87,
          padding: EdgeInsets.only(top:10.0,bottom:10.0),
          child: new Row(
              children: [
                new Expanded(child: new Text(" "+name,style:new TextStyle(fontSize:fontSize),textAlign: TextAlign.left)),
                new Text((info!=-1?info>1?new NumberFormat.currency(symbol:"\$",decimalDigits: first).format(info):"\$"+info.toStringAsFixed(second):"N/A"),style:new TextStyle(fontSize: fontSize))
              ]
          ),
        )
    );
  }
}


class Options{

  @override
  Widget build(BuildContext context){
    return new Scaffold(
      appBar:new AppBar(title:new Text("More"),backgroundColor: Colors.black54),

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

      // Read the file
      String contents = await file.readAsString();

      List<String> list = contents.split(" ");

      List<int> bigList = new List<int>();

      for(String s in list){
        bigList.add(int.parse(s));
      }

      return bigList;
    } catch (e) {
      // If we encounter an error, return 0
      return null;
    }
  }

  Future<File> writeData(String data) async {
    final file = await _localFile;
    // Write the file
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

  double maxPrice = -1.0,minPrice = double.maxFinite;

  SimpleTimeSeriesChartState(this.seriesList, this.shortName,this.price,this.days,{this.animate});

  @override
  Widget build(BuildContext context) {
    if(firstBuild){
      http.get(
          Uri.encodeFull("http://coincap.io/history/"+days.toString()+"day/"+shortName)
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
                new NumberFormat("\$###,###,###,###,###.###########","en_US")
            ),
            renderSpec: new charts.GridlineRendererSpec(
                labelStyle: new charts.TextStyleSpec(
                    color: bright?charts.MaterialPalette.black:charts.MaterialPalette.white
                ),
                lineStyle: new charts.LineStyleSpec(
                    color: bright?charts.MaterialPalette.gray.shade400:charts.MaterialPalette.white)
            )
        ),
        domainAxis: charts.DateTimeAxisSpec(
            tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                day: new charts.TimeFormatterSpec(
                    format: 'd',
                    transitionFormat: days==1?'MM/dd hh/mm a':days==7?'MM/dd':days==30?'MM/dd':days==180?"YY/MM":"YY/MM"
                )
            ),
            tickProviderSpec: new charts.DayTickProviderSpec(
                increments: days==1?[1]:days==7?[1]:days==30?[5]:days==180?[40]:[60]
            ),
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
                  selectedPrice = -1.0;
                  selectedTime = null;
                }
              }
          )
        ]
    )),
    new Container(
        height:32.0,
        child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              new Text((selectedTime!=null?"Date: "+new DateFormat("yyyy/MM/dd").add_jm().format(selectedTime):"")),
              new Text((selectedPrice!=-1.0?"Price: "+new NumberFormat.currency(symbol:"\$",decimalDigits: selectedPrice>1?2:selectedPrice>.000001?6:7).format(selectedPrice):""))
            ]
        )
    )

    ]):canLoad?new Container(height:232.0,padding:EdgeInsets.only(left:10.0,right:10.0),child:new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new CircularProgressIndicator()
        ]
    )):new Container(
        height:232.0,
        child: new Center(
            child: new Text("Sorry, this coin graph is not supported",style: new TextStyle(fontSize:17.0))
        )
    );
  }

  Future<List<charts.Series<TimeSeriesPrice, DateTime>>> createChart(http.Response response, String s) async {


    List<TimeSeriesPrice> data = [

    ];

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
        maxPrice = maxPrice<info["price"][i][1]*1.0?info["price"][i][1]*1.0:maxPrice;
        minPrice = minPrice>info["price"][i][1]*1.0?info["price"][i][1]*1.0:minPrice;
        data[i] = new TimeSeriesPrice(new DateTime.fromMillisecondsSinceEpoch(info["price"][i][0]), info["price"][i][1]*1.0);
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

  Future<List<int>> readData() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();

      if(contents.length!=3){
        return null;
      }

      List<String> list = contents.split(" ");

      List<int> finalList = new List<int>();

      for(int i = 0; i<2;i++){
        finalList.add(int.parse(list[i]));
      }

      return finalList;
    } catch (e) {
      return null;
    }
  }

  Future<File> writeData(String data) async {
    final file = await _localFile;
    return file.writeAsString(data);
  }

}

