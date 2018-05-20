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

Future<String> getData() async{
  http.Response r = await http.get(
    Uri.encodeFull("https://api.coinmarketcap.com/v2/listings")
  );
  data = json.decode(r.body);
  //print(data.toString());
  int runs = data["metadata"]["num_cryptocurrencies"];
  itemCount = runs;
  for(int i = 0; i<runs;i++){
    fullList.add(new Crypto(data["data"][i]["website_slug"],Colors.black12,i,data["data"][i]["name"]));
  }
}

int itemCount;

Map<String, dynamic> data;

String response;

void main() {
  getData();
  runApp(new MaterialApp(
    home: new HomePage()
  ));
}

class HomePage extends StatefulWidget{

  @override
  HomePageState createState() => new HomePageState();
}

class HomePageState extends State<HomePage>{

  @override
  Widget build(BuildContext context){
    return new Scaffold(
      appBar:new AppBar(title:new Text("Favorites"),backgroundColor: Colors.black54),
      floatingActionButton: new FloatingActionButton(
        onPressed: (){
          Navigator.push(context,new MaterialPageRoute(builder: (context) => new CryptoList()));
        },
        child: new Icon(Icons.add)
      ),
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
  CryproListState createState() => new CryproListState();
}

class CryproListState extends State<CryptoList>{

  String search = "";

  List<Widget> filteredList = new List<Widget>();

  @override
  Widget build(BuildContext context){
    if(search==""){
      if(filteredList.length==0){
        filteredList.addAll(fullList);
      }
    }
    return new Scaffold(
      appBar: new AppBar(
        title: new TextField(
            maxLength:20,
            autocorrect: false,
            decoration: new InputDecoration(
              hintText: "Search",
              // ignore: conflicting_dart_import
              hintStyle: new TextStyle(color:Colors.white),
              prefixIcon: new Icon(Icons.search)
            ),
          style:new TextStyle(color:Colors.white),
          onSubmitted: (s){
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
      ),
      body: new Container(
        child: new Center(
          child: new ListView.builder(
            itemCount: itemCount,
            itemBuilder: (BuildContext context,int index) => filteredList[index]
          )
        )
      )
    );
  }
}

class FavCrypto extends StatefulWidget{

  final String slug;

  String name;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int index,friendIndex;

  FavCrypto(this.slug,this.index,this.friendIndex,this.name);

  @override
  FavCryptoState createState() => new FavCryptoState();
}

class FavCryptoState extends State<FavCrypto>{

  @override
  void initState(){
    super.initState();
    //get info
    widget.oneHour = 10.0;
    widget.twentyFourHours = 9.0;
    widget.sevenDays = -8.0;
    widget.price = 15.00;
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
        }
        (fullList[widget.friendIndex] as Crypto).color = Colors.black12;
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
              new Expanded(child: new Text("\$10",style: new TextStyle(fontSize:25.0))),
              new Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString(),style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))),
                  new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString(),style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))),
                  new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString(),style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red)))
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

  String slug;

  Color color;

  String name;

  double price;

  double oneHour,twentyFourHours,sevenDays;

  int favIndex;

  int index;

  Crypto(this.slug,this.color,this.index,this.name);

  @override
  CryptoState createState() => new CryptoState();
}

class CryptoState extends State<Crypto>{

  @override
  void initState(){
    super.initState();
    //get info
    widget.oneHour = 10.0;
    widget.twentyFourHours = 9.0;
    widget.sevenDays = -8.0;
    widget.price = 15.00;
  }

  @override
  Widget build(BuildContext context){
    widget.oneHour = 10.0;
    widget.twentyFourHours = 9.0;
    widget.sevenDays = -8.0;
    widget.price = 15.00;
    return new Container(
        padding: EdgeInsets.only(top:10.0),
        child: new FlatButton(
            padding: EdgeInsets.only(top:15.0,bottom:15.0,left:5.0,right:5.0),
            color:widget.color,
            child: new Row(
              children: <Widget>[
                // ignore: conflicting_dart_import
                new Expanded(child: new Text(widget.name,style: new TextStyle(fontSize:25.0))),
                new Expanded(child: new Text("\$"+widget.price.toStringAsFixed(2),style: new TextStyle(fontSize:25.0))),
                new Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    new Text(((widget.oneHour>=0)?"+":"")+widget.oneHour.toString(),style:new TextStyle(color:((widget.oneHour>=0)?Colors.green:Colors.red))),
                    new Text(((widget.twentyFourHours>=0)?"+":"")+widget.twentyFourHours.toString(),style:new TextStyle(color:((widget.twentyFourHours>=0)?Colors.green:Colors.red))),
                    new Text(((widget.sevenDays>=0)?"+":"")+widget.sevenDays.toString(),style:new TextStyle(color:((widget.sevenDays>=0)?Colors.green:Colors.red)))
                  ],
                ),
                new Icon(widget.color==Colors.black12?Icons.add_circle_outline:Icons.check)
              ],
            ),
            onPressed: (){
              setState((){widget.color = widget.color==Colors.black12?Colors.black26:Colors.black12;});
              Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(widget.color==Colors.black26?"Added":"Removed"),duration: new Duration(seconds:1)));
              if(widget.color==Colors.black26){
                favList.add(new FavCrypto(widget.slug, favList.length,widget.index,widget.name));
                widget.favIndex = favList.length-1;
              }else{
                favList.removeAt(widget.favIndex);
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