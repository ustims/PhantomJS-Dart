import 'package:phantomjs/phantomjs.dart';
import 'dart:async';
import 'dart:io';

Future<dynamic> example() async {
  await PhantomJS.start('9898');

  Page page = await Page.create();
  await page.open('http://google.com');
  String title = await page.evaluate('function(){ return document.title; }');
  print('Page title is "${title}"');
  page.close();

  PhantomJS.stop();
}

void main(){
  example().then((result){
    exit(0);
  })
  .catchError((err) {
    throw err;
  });
}