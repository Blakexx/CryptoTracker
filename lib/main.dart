import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
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
      fullList.add(new Crypto(data["data"][i]["website_slug"],Colors.black12,i,data["data"][i]["name"],data["data"][i]["id"]));
      ids[i] = data["data"][i]["id"];
    }
    //print(fullList);
    buildCount=100;
    setState((){});
    return new Future<String>((){return "0";});
  }

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
    print("Data Retrieved and Processed");
    buildCount = 199;
    //print(data.toString());
    done = true;
    //print(fullList);
    setState((){});
    return new Future<String>((){return "0";});
  }

  bool done = false;

  void initState(){
    super.initState();
    if(buildCount==0){
      getData();
    }
    buildCount++;
  }

  @override
  Widget build(BuildContext context){
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
            favList[inds[i+1]]=(new FavCrypto(temp.slug,inds[i+1],inds[i],temp.name,temp.id,temp.oneHour,temp.twentyFourHours,temp.sevenDays,temp.price,temp.mCap));
            (fullList[inds[i]] as Crypto).color = Colors.black26;
            //print(favList);
          }
        }
        buildCount = 300;
        setState((){});
      });
    }
    return new Scaffold(
      appBar:new AppBar(title:new Text("Favorites"),backgroundColor: Colors.black54),
      floatingActionButton: done?new FloatingActionButton(
        onPressed: (){
          Navigator.push(context,new MaterialPageRoute(builder: (context) => new CryptoList()));
        },
        child: new Icon(Icons.add)
      ):new Container(),
      body: new Container(
        child: new Center(
          child: new ListView(
            children: <Widget>[
              new Column(
                children: favList
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
    return new Scaffold(
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
              scrollController.jumpTo(0.0);
              filteredList.clear();
              search = s;
              for(int i = 0; i<fullList.length;i++){
                if((fullList[i] as Crypto).name.toUpperCase().contains(search.toUpperCase())){
                  filteredList.add(fullList[i]);
                }
              }
              setState(() {

              });
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
            icon: search.length>0?new Icon(Icons.close):new Icon(Icons.edit),
            onPressed: (){
              if(search.length>0){
                selection = null;
                setState((){
                  search = "";
                });
                textController.text = "";
                scrollController.jumpTo(0.0);
                filteredList.clear();
                filteredList.addAll(fullList);
              }
            }
          )
        ]
      ),
      body: new Container(
        child: new Center(
          child: new ListView.builder(
            controller: scrollController,
            itemCount: filteredList.length,
            itemBuilder: (BuildContext context,int index) => filteredList[index]
          )
        )
      )
    );
  }
}

class FavCrypto extends StatefulWidget{

  double mCap;

  final String slug;

  String name;

  int id;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int index,friendIndex;

  FavCrypto(this.slug,this.index,this.friendIndex,this.name,this.id,this.oneHour,this.twentyFourHours,this.sevenDays,this.price,this.mCap);

  @override
  FavCryptoState createState() => new FavCryptoState();
}

class FavCryptoState extends State<FavCrypto>{

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    return new Dismissible(
      direction: DismissDirection.endToStart,
      key: new Key(widget.slug),
      onDismissed: (direction){
        favList.removeAt(widget.index);
        for(int i = 0;i <favList.length;i++){
          (favList[i] as FavCrypto).index = i;
          (fullList[(favList[i] as FavCrypto).friendIndex] as Crypto).favIndex = i;
        }
        (fullList[widget.friendIndex] as Crypto).color = Colors.black12;
        String dataBuild = "";
        for(int i = 0;i<favList.length;i++){
          dataBuild+=(favList[i] as FavCrypto).friendIndex.toString()+" "+(favList[i] as FavCrypto).index.toString()+" ";
        }
        //print(dataBuild);
        storage.writeData(dataBuild);
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
              new Expanded(child: new Text(widget.name,style: new TextStyle(fontSize:25.0))),
              new Expanded(child: new Text("\$"+(widget.price!=-1?widget.price.toStringAsFixed(3):"N/A"),style: new TextStyle(fontSize:25.0))),
              new Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  widget.oneHour!=-1?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString(),style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                  widget.twentyFourHours!=-1?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString(),style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                  widget.sevenDays!=-1?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString(),style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                ],
              )
            ],
          ),
          onPressed: (){Navigator.push(context,new MaterialPageRoute(builder: (context) => new ItemInfo(widget.slug)));}
        )
      )
    );
  }
}

class Crypto extends StatefulWidget{

  double mCap;

  String slug;

  int id;

  Color color;

  String name;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int favIndex;

  int index;

  Crypto(this.slug,this.color,this.index,this.name,this.id);

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
        padding: EdgeInsets.only(top:10.0),
        child: new FlatButton(
            padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
            color:widget.color,
            child: new Row(
              children: <Widget>[
                // ignore: conflicting_dart_import
                new Expanded(child: new Text(widget.name,style: new TextStyle(fontSize:25.0))),
                new Expanded(child: new Text("\$"+(widget.price!=-1?widget.price>=1?widget.price.toStringAsFixed(3):widget.price.toStringAsFixed(6):"N/A"),style: new TextStyle(fontSize:25.0))),
                new Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    widget.oneHour!=-1?new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString(),style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))):new Text("N/A"),
                    widget.twentyFourHours!=-1?new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString(),style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))):new Text("N/A"),
                    widget.sevenDays!=-1?new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString(),style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red))):new Text("N/A")
                  ],
                ),
                new Icon(widget.color==Colors.black12?Icons.add:Icons.check)
              ],
            ),
            onPressed: (){
              setState((){widget.color = widget.color==Colors.black12?Colors.black26:Colors.black12;});
              Scaffold.of(context).removeCurrentSnackBar();
              Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(widget.color==Colors.black26?"Added":"Removed"),duration: new Duration(milliseconds: 500)));
              if(widget.color==Colors.black26){
                favList.add(new FavCrypto(widget.slug, favList.length,widget.index,widget.name,widget.id,widget.oneHour,widget.twentyFourHours,widget.sevenDays,widget.price,widget.mCap));
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
        )
    );
  }
}

class ItemInfo extends StatelessWidget{

  String slug;

  ItemInfo(this.slug);

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
                      new Text("price",style:new TextStyle(fontSize: 25.0))
                    ]
                )
            )
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