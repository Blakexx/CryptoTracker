import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

int itemCount = 1;

final DataStorage storage = new DataStorage();

Map<String, dynamic> data;

String response;

void main() {
  runApp(new MaterialApp(
      home: new HomePage()
  ));
}

int buildCount = 0;

class HomePage extends StatefulWidget{

  @override
  HomePageState createState() => new HomePageState();
}

List<int> ids;

class HomePageState extends State<HomePage>{

  static List<Widget> filteredList = new List<Widget>();

  Future<String> getData() async{
    ids = new List<int>();
    http.Response r = await http.get(
        Uri.encodeFull("https://api.coinmarketcap.com/v2/listings")
    );
    data = json.decode(r.body);
    //print(data.toString());
    int runs = data["metadata"]["num_cryptocurrencies"];
    itemCount = runs;
    ids.length = itemCount;
    for(int i = 0; i<runs;i++){
      // ignore: conflicting_dart_import
      fullList.add(new Crypto(data["data"][i]["website_slug"],Colors.black12,i,data["data"][i]["name"],data["data"][i]["id"],new Image.network(
        'https://s2.coinmarketcap.com/static/img/coins/32x32/'+data["data"][i]["id"].toString()+".png"
      ),data["data"][i]["symbol"]));
      ids[i] = data["data"][i]["id"];
    }
    //print(fullList);
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
      //print(data);
      //print(data["data"]["1"]);
      //print(data["data"]);
      Map<String,dynamic> map = data["data"];
      //print(map);
      for(Map<String,dynamic> s in map.values){
        //print(s);
        //print(s["id"]);
        //(fullList[ids.indexOf(data["data"][i]["id"])] as Crypto).price = data["data"][i]["price"];
        //print(s["quotes"]["USD"]["price"]);
        (fullList[ids.indexOf(s["id"])] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]:-1.0;
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

  bool inSearch = false;

  ScrollController scrollController = new ScrollController();

  int a = 0;

  String search = null;

  bool hasSearched = false;

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
            Crypto temp = (fullList[inds[i]] as Crypto);
            (fullList[inds[i]] as Crypto).favIndex = inds[i+1];
            favList[inds[i+1]]=(new FavCrypto(temp.slug,inds[i+1],inds[i],temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap,temp.image,temp.shortName));
            (fullList[inds[i]] as Crypto).color = Colors.black26;
            //print(favList);
          }
        }
        buildCount = 300;
        firstLoad = true;
        setState((){});
      });
    }
    return firstLoad?new Scaffold(
        appBar:new AppBar(
            title:!inSearch?new Text("Favorites"):new TextField(
              maxLength:20,
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
              new IconButton(
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
              new PopupMenuButton<String>(
                onSelected: (String selected){
                  if(selected=="Settings"){
                    Navigator.push(context,new MaterialPageRoute(builder: (context) => new Scaffold(
                      appBar: new AppBar(title:new Text("Settings"),backgroundColor: Colors.black54),
                      body: new Container(
                        child: new Center(
                          child: new Column(
                            children: <Widget>[
                              new Text("It's perfect the way it is")
                            ]
                          )
                        )
                      )
                    )));
                  }else if(selected=="Rate us"){
                    Navigator.push(context,new MaterialPageRoute(builder: (context) => new Scaffold(
                      appBar: new AppBar(title:new Text("Settings"),backgroundColor: Colors.black54),
                      body: new Container(
                        child: new Center(
                          child: new Column(
                            children: <Widget>[
                              new Text("Please :(")
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
                ],
                child: new Icon(Icons.more_vert)
              )
            ]
        ),
        floatingActionButton: (done && completer.isCompleted)?new FloatingActionButton(
            onPressed: (){
              search = null;
              filteredList.clear();
              completer = new Completer<Null>();
              completer.complete();
              Navigator.push(context,new MaterialPageRoute(builder: (context) => new CryptoList()));
            },
            child: new Icon(Icons.add)
        ):new Container(),
        body: new Container(
            child: new Center(
                child: new RefreshIndicator(
                  child: new ListView(
                      children: <Widget>[
                        new Column(
                          children: filteredList
                        )
                      ]
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
    int count = 0;
    //print(count);
    //print(itemCount);
    http.Response r;
    while(count<itemCount){
      //print(count);
      r = await http.get(
          Uri.encodeFull("https://api.coinmarketcap.com/v2/ticker/?start="+count.toString())
      );
      data = json.decode(r.body);
      //print(data);
      //print(data["data"]["1"]);
      //print(data["data"]);
      Map<String,dynamic> map = data["data"];
      //print(map);
      for(Map<String,dynamic> s in map.values){
        //print(s);
        //print(s["id"]);
        //(fullList[ids.indexOf(data["data"][i]["id"])] as Crypto).price = data["data"][i]["price"];
        //print(s["quotes"]["USD"]["price"]);
        (fullList[ids.indexOf(s["id"])] as Crypto).price = s["quotes"]["USD"]["price"]!=null?s["quotes"]["USD"]["price"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).oneHour = s["quotes"]["USD"]["percent_change_1h"]!=null?s["quotes"]["USD"]["percent_change_1h"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).twentyFourHours = s["quotes"]["USD"]["percent_change_24h"]!=null?s["quotes"]["USD"]["percent_change_24h"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).sevenDays = s["quotes"]["USD"]["percent_change_7d"]!=null?s["quotes"]["USD"]["percent_change_7d"]:-1.0;
        (fullList[ids.indexOf(s["id"])] as Crypto).mCap = s["quotes"]["USD"]["market_cap"]!=null?s["quotes"]["USD"]["market_cap"]:-1.0;
      }
      count+=100;
    }
    //print(count.toString()+" "+itemCount.toString());
    //print("Data Retrieved and Processed");
    //buildCount = 199;
    //print(data.toString());
    done = true;
    //print(fullList);
    setState((){});
    return new Future<String>((){return "0";});
  }

  bool done = true;

  String search = "";

  List<Widget> filteredList = new List<Widget>();

  ScrollController scrollController = new ScrollController();

  String selection;

  final List<String> options = ["Name Ascending","Name Descending", "Price Ascending", "Price Descending","Market Cap Ascending","Market Cap Descending","Default"].toList();

  void onChanged(String s){
    //print("meme");
    setState(() {
      scrollController.jumpTo(0.0);
      selection = s;
      if(s=="Name Ascending"){
        filteredList.sort((o1,o2){
          if((o1 as Crypto).name.compareTo((o2 as Crypto).name)!=0){
            return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
          }
          return ((o1 as Crypto).price-(o2 as Crypto).price).floor().toInt();
        });
      }else if(s=="Name Descending"){
        filteredList.sort((o1,o2){
          if((o1 as Crypto).name.compareTo((o2 as Crypto).name)!=0){
            return (o2 as Crypto).name.compareTo((o1 as Crypto).name);
          }
          return ((o1 as Crypto).price-(o2 as Crypto).price).floor().toInt();
        });
      }else if(s=="Price Ascending"){
        filteredList.sort((o1,o2){
          if(((o1 as Crypto).price!=(o2 as Crypto).price)){
            return ((o1 as Crypto).price*1000000000-(o2 as Crypto).price*1000000000).round();
          }
          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
        });
      }else if(s=="Price Descending"){
        filteredList.sort((o1,o2){
          if(((o1 as Crypto).price!=(o2 as Crypto).price)){
            return ((o2 as Crypto).price*1000000000-(o1 as Crypto).price*1000000000).round();
          }
          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
        });
      }else if(s=="Market Cap Ascending"){
        filteredList.sort((o1,o2){
          if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
            return ((o1 as Crypto).mCap*100-(o2 as Crypto).mCap*100).round();
          }
          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
        });
      }else if(s=="Market Cap Descending"){
        filteredList.sort((o1,o2){
          if(((o1 as Crypto).mCap!=(o2 as Crypto).mCap)){
            return ((o2 as Crypto).mCap*100-(o1 as Crypto).mCap*100).round();
          }
          return (o1 as Crypto).name.compareTo((o2 as Crypto).name);
        });
      }else if(s=="Default"){
        filteredList.sort((o1,o2) {
          return (o1 as Crypto).index - (o2 as Crypto).index;
        });
      }
    });
  }

  TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context){

    final dropdownMenuOptions = options
        .map((String item) =>
    new DropdownMenuItem<String>(value: item, child: new Text(item))
    ).toList();

    if(search==""){
      if(filteredList.length==0){
        filteredList.addAll(fullList);
      }
    }
    return new WillPopScope(
      child: new GestureDetector(
        onTap: (){FocusScope.of(context).requestFocus(new FocusNode());},
        child: new Scaffold(
            floatingActionButton: new FloatingActionButton(
              child: new Icon(Icons.arrow_upward),
              onPressed: (){
                scrollController.jumpTo(1.0);
              },
              backgroundColor: Colors.black26,
            ),
            appBar: new AppBar(
                title: new TextField(
                    controller: textController,
                    maxLength:20,
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
                        if((fullList[i] as Crypto).name.toUpperCase().contains(search.toUpperCase()) || (favList[i] as FavCrypto).shortName.toUpperCase().contains(search.toUpperCase())){
                          filteredList.add(fullList[i]);
                        }
                      }
                      setState(() {});
                    }
                ),
                backgroundColor: Colors.black54,
                bottom: new PreferredSize(
                    preferredSize: new Size(0.0,50.0),
                    child: new Column(
                        children: [
                          new Container(
                              padding: EdgeInsets.only(left:5.0,right:5.0),
                              color: Colors.white,
                              child: new DropdownButton(
                                  hint:new Text("Sort",style:new TextStyle(color:Colors.black)),
                                  value: selection,
                                  items: dropdownMenuOptions,
                                  onChanged: (s){
                                    FocusScope.of(context).requestFocus(new FocusNode());
                                    onChanged(s);
                                  }
                              )
                          ),
                          new Container(
                              padding: EdgeInsets.only(bottom:10.0)
                          )
                        ]
                    )
                ),
                actions: <Widget>[
                  new IconButton(
                      icon: (search!=null&&search.length>0)?new Icon(Icons.close):new Icon(Icons.edit),
                      onPressed: (){
                        if(search.length>0){
                          selection = null;
                          setState((){
                            search = null;
                          });
                          textController.text = "";
                          scrollController.jumpTo(1.0);
                          filteredList.clear();
                          filteredList.addAll(fullList);
                        }
                      }
                  )
                ]
            ),
            body: new Container(
                child: new Center(
                    child: new RefreshIndicator(
                        child: new ListView.builder(
                            controller: scrollController,
                            itemCount: filteredList.length,
                            itemBuilder: (BuildContext context,int index) => filteredList[index]
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
          return (completer.isCompleted && done)?new Future((){return true;}):new Future((){return false;});
        }
    );
  }
  bool kill = false;
}

Completer completer = new Completer<Null>()..complete();

class FavCrypto extends StatefulWidget{

  String shortName;

  Image image;

  double mCap;

  final String slug;

  String name;

  int id;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int index,friendIndex;

  ObjectKey key;

  FavCrypto(this.slug,this.index,this.friendIndex,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap,this.image,this.shortName);

  @override
  FavCryptoState createState() => new FavCryptoState();
}

int removed = 0;

class FavCryptoState extends State<FavCrypto>{

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    widget.key = new ObjectKey(widget.slug);
    return new Dismissible(
        direction: completer.isCompleted?DismissDirection.endToStart:null,
        key: widget.key,
        onDismissed: (direction){
          if(completer.isCompleted){
            widget.key = new ObjectKey("removed"+(removed++).toString());
            favList.removeAt(widget.index);
            (fullList[widget.friendIndex] as Crypto).favIndex = null;
            for(int i = 0;i<favList.length;i++){
              (favList[i] as FavCrypto).index = i;
              (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex = i;
              (favList[i] as FavCrypto).key = new ObjectKey((favList[i] as FavCrypto).slug);
            }
            (fullList[widget.friendIndex] as Crypto).color = Colors.black12;
            String dataBuild = "";
            for(int i = 0;i<favList.length;i++){
              dataBuild+=(favList[i] as FavCrypto).friendIndex.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
            }
            //setState((){});
            //print(dataBuild)
            storage.writeData(dataBuild);
          }
        },
        background: new Container(color:Colors.red),
        child: new Container(
            padding: EdgeInsets.only(top:10.0),
            child: new FlatButton(
                padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
                color:Colors.black12,
                child: new Row(
                  children: <Widget>[
                    // ignore: conflicting_dart_import
                    new Expanded(child: new Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          new Row(
                            children: [
                              new Text(widget.name,style: new TextStyle(fontSize:((6/widget.name.length)<1)?(22.0*6/widget.name.length):22.0))
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          new Text((widget.price!=-1?widget.price>=1?"\$"+widget.price.toStringAsFixed(2):"\$"+widget.price.toStringAsFixed(6):"N/A"),style: new TextStyle(fontSize:22.0)),
                          new Text((widget.mCap!=-1?widget.mCap>=1?"\$"+widget.mCap.toStringAsFixed(0):"\$"+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:Colors.black45,fontSize:12.0)),
                        ]
                    ),
                    new Expanded(
                        child: new Column(
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
                onPressed: (){if(completer.isCompleted){Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.slug,widget.price)));}}
            )
        )
    );
  }
}

class Crypto extends StatefulWidget{

  String shortName;

  Image image;

  double mCap;

  String slug;

  int id;

  Color color;

  String name;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int favIndex;

  int index;

  Crypto(this.slug,this.color,this.index,this.name,this.id,this.image,this.shortName);

  @override
  CryptoState createState() => new CryptoState();
}

class CryptoState extends State<Crypto>{

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    return new Container(
      key: new ObjectKey("full"+widget.slug),
        padding: EdgeInsets.only(top:10.0),
        child: new FlatButton(
            padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
            color: widget.color,
            child: new Row(
              children: <Widget>[
                // ignore: conflicting_dart_import
                new Expanded(child: new Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      new Row(
                          children: [
                            new Text(widget.name,style: new TextStyle(fontSize:((6/widget.name.length)<1)?(22.0*6/widget.name.length):22.0))
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    new Text((widget.price!=-1?widget.price>=1?"\$"+widget.price.toStringAsFixed(2):"\$"+widget.price.toStringAsFixed(6):"N/A"),style: new TextStyle(fontSize:22.0)),
                     new Text((widget.mCap!=-1?widget.mCap>=1?"\$"+widget.mCap.toStringAsFixed(0):"\$"+widget.mCap.toStringAsFixed(2):"N/A"),style: new TextStyle(color:Colors.black45,fontSize:12.0)),
                  ]
                ),
                new Expanded(
                  child: new Column(
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
                  favList.add(new FavCrypto(widget.slug,favList.length,widget.index,widget.name,widget.id,widget.oneHour,widget.twentyFourHours,widget.sevenDays,widget.price,widget.mCap,widget.image,widget.shortName));
                  widget.favIndex = favList.length-1;
                  String dataBuild = "";
                  for(int i = 0;i<favList.length;i++){
                    dataBuild+=(favList[i] as FavCrypto).friendIndex.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
                  }
                  //print(dataBuild);
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
                    dataBuild+=(favList[i] as FavCrypto).friendIndex.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
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

class ItemInfo extends StatelessWidget{

  String slug;

  double price;

  ItemInfo(this.slug,this.price);

  @override
  Widget build(BuildContext context){
    return new Scaffold(
        appBar:new AppBar(title:new Text(slug),backgroundColor: Colors.black54),
        body:new Container(
            child:new Center(
                child:new Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      new Text(slug,style:new TextStyle(fontSize: 25.0)),
                      new Text("\$"+(price!=-1?price>=1?price.toStringAsFixed(2):price.toStringAsFixed(6):"N/A"),style:new TextStyle(fontSize: 25.0))
                    ]
                )
            )
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