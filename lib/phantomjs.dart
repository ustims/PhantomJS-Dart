library phantomjs;

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:mirrors';
import 'package:path/path.dart' as PathLib;

class PhantomJS {
  static Process _process = null;
  static String _port = null;
  static bool _debug = false;

  static Future start([String port='9000', bool debug=false]) {
    bool firstResponse = true;
    _port = port;
    _debug = debug;

    Completer completer = new Completer();
    String webserverFilePath = PathLib.dirname(PathLib.current) + '/packages/phantomjs/webserver.js';
    Process.start('phantomjs', [webserverFilePath, '$_port'])
    .then((Process process) {
      _process = process;
      process.stdout
      .transform(UTF8.decoder)
      .listen((data) {
        if(data.contains('[PhantomJS Log]') && _debug){
          print(data);
        }

        if (firstResponse) {
          firstResponse = false;
          if (data == 'started\n') {
            print('PhantomJS Started');
            completer.complete();
          } else if (data.contains('could not create web server')) {
            throw new Exception('PhantomJS can not be started on port ${_port}');
          } else {
            throw new Exception(data);
          }
        }
      });
      process.stderr
      .transform(UTF8.decoder)
      .listen((data) {
        print('PhantomJS Error: ' + data);
      });
    })
    .catchError((err) {
      throw err;
    });

    return completer.future;
  }

  static stop() {
    _process.kill(ProcessSignal.SIGTERM);
    print('PhantomJS closed');
  }

  static Future makeRequest(String methodName, List arguments) {
    Completer completer = new Completer();

    var uriRaw = 'http://localhost:${_port}?' + 'data=' + JSON.encode(
        {
            'method': methodName,
            'arguments': arguments
        });
    var uriEncoded = Uri.encodeFull(uriRaw);
    http.get(uriEncoded)
    .then((response) {
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      try {
        var decoded = JSON.decode(response.body);
        completer.complete(decoded);
      } on Exception catch (e) {
        completer.complete(response.body);
      }
    });

    return completer.future;
  }
}

class Page {
  int id = null;

  Future open(String url) async {
    String status = await PhantomJS.makeRequest('page.open', [this.id, url]);
    return status;
  }

  Future evaluate(String jsCode) async {
    var results = await PhantomJS.makeRequest('page.evaluate', [this.id, jsCode]);
    return results;
  }

  Future close() async {
    var result = await PhantomJS.makeRequest('page.close', [this.id]);
    return result;
  }

  static Future create() async {
    int pageId = await PhantomJS.makeRequest('page.create', []);
    var newPage = new Page();
    newPage.id = pageId;
    return newPage;
  }

  Future render(String path) async {
    var p = PathLib.join(PathLib.current, path);
    await PhantomJS.makeRequest('page.render', [this.id, p]);
    return true;
  }

  Future querySelector(String selector) async {
    var _element = await PhantomJS.makeRequest(
        'page.querySelector', [selector]);

    Element element = new Element(this);
  }
}

class Element {
  Page page;

  Element(Page this.page);
}

class ElementAttribute {
  String _name;
  String _value;
  Element _element;

  ElementAttribute(Element this._element);

  String get name => this._name;

  String get value => this._value;

  Future<dynamic> set value(newValue) async {
    this._value = newValue;

  }
}