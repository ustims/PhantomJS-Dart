var webpage = require('webpage');
var server = require('webserver').create();
var system = require('system');

var host, port;

var debug = true;

if (typeof String.prototype.parseFunction != 'function') {
  String.prototype.parseFunction = function () {
    var funcReg = /function *\(([^()]*)\)[ \n\t]*{(.*)}/gmi;
    var match = funcReg.exec(this.replace(/\n/g, ' '));

    if (match) {
      return new Function(match[1].split(','), match[2]);
    }

    return null;
  };
}

var log = function(){
  if(!debug){
    return;
  }
  for(var i=0;i<arguments.length;i++){
    if(typeof arguments[i] == 'object'){
      console.log('[PhantomJS Log] ' + JSON.stringify(arguments[i], null, 2));
    } else {
      console.log('[PhantomJS Log] ' + arguments[i]);
    }
  }
};

/**
 * Global array with all created pages.
 * @type {Array}
 */
var openedPages = [];

var methods = {
  'page.create': function (cb) {
    var page = webpage.create();
    log('Page created:', page);

    openedPages.push(page);

    setTimeout(function () {
      cb(openedPages.length - 1);
    }, 1);
  },
  'page.open': function (pageId, url, cb) {
    log('Opening url: ' + url);
    log('On page:', openedPages[pageId]);
    openedPages[pageId].open(url, function (status) {
      log('Opened with status:' + status);
      cb(status);
    });
  },
  'page.evaluate': function (pageId, code, cb) {
    var fn = code.parseFunction();
    log('Executing func:', fn);
    var result = openedPages[pageId].evaluate(fn);
    log('Result:', result);
    setTimeout(function () {
      cb(result);
    }, 1);
  },
  'page.render': function(pageId, path, cb){
    log('Rendering page to: ' + path);
    openedPages[pageId].render(path);
    log('Rendering page complete: ' + path);
    cb(true)
  },
  'page.close': function(pageId, cb){
    openedPages[pageId].close();
    openedPages[pageId] = null;
    cb(true);
  }
};

if (system.args.length < 2) {
  console.log('Usage: server.js <some port> <debug>');
  phantom.exit(1);
} else {
  port = system.args[1];
  //if(system.args.length > 3){
  //  debug = false;
  //}

  var controlPage = webpage.create();

  var listening = server.listen(port, function (request, response) {
    response.headers = {"Cache": "no-cache", "Content-Type": "text/html"};

    log("GOT HTTP REQUEST", request);

    var rawData = decodeURI(request.url.replace('/?data=', ''));
    var requestData = JSON.parse(rawData);

    log('Request data:', requestData);

    if (methods[requestData.method]) {
      if (requestData.arguments == null) {
        requestData.arguments = [];
      }
      log('Executing method: ' + requestData.method);
      var arguments = requestData.arguments.concat([function callback(result) {
        log('Finished method: ' + requestData.method);
        response.statusCode = 200;
        response.write(JSON.stringify(result));
        response.close();
        log('Response: ' + JSON.stringify(result));
      }]);
      log('With arguments: ', arguments);
      methods[requestData.method].apply(null, arguments);
    } else {
      response.statusCode = 400;
      console.error('Undefined method.');
      response.close();
    }
  });
  console.log('started');
  if (!listening) {
    console.log("could not create web server listening on port " + port);
    phantom.exit();
  }
}