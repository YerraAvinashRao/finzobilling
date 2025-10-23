'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "4535687d4cca09ca6bd32c15f55d6310",
".git/config": "920a11de313bfb8d93d81f4a3a5b71b6",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "a7c59dd272eadbe981e3b47a47390de3",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "a7d7f617e6c41ad025e993c642093e81",
".git/logs/refs/heads/gh-pages": "c6835d73cb7dc0f0473588336ce6cd16",
".git/objects/02/1d4f3579879a4ac147edbbd8ac2d91e2bc7323": "9e9721befbee4797263ad5370cd904ff",
".git/objects/03/2cdbca897bce7c472b34818962875d8d4b606a": "73bdd12f8001bff229f01fe4b92ff738",
".git/objects/1c/f8e81303852d3d1b961723a3e00f7a2889e066": "5b3d1f618847f4b976d9a332cc16b99b",
".git/objects/20/3a3ff5cc524ede7e585dff54454bd63a1b0f36": "4b23a88a964550066839c18c1b5c461e",
".git/objects/24/290f4d5c96c421b6dd07d85000360a72dd0a51": "b5c3113d8663d63a24a97b04d1232f44",
".git/objects/24/51ea083a57f343755df415223a99599c3f03b4": "e60631ad27969692d318aa66156ba55b",
".git/objects/29/67bfcad554c8442673013008dc12bc1ca45d74": "4a706f443e917609af68133e77f4e0b6",
".git/objects/29/f22f56f0c9903bf90b2a78ef505b36d89a9725": "e85914d97d264694217ae7558d414e81",
".git/objects/2e/f639bbb25b1780f6cb29cd1be098da19b392a6": "28d2e2289828822d351211397324dea4",
".git/objects/37/ddd2dae7d18ae06c4d10315027e53a745f84fa": "3cdc99ec1363eabea71ebe55787f7952",
".git/objects/38/0bfe3598996161f54aad4ec7cf5f75bcc4347c": "556b1a2ccd9d9f3ed53cfdf8cfc0b8a0",
".git/objects/4a/3f0d152e9e802ba86c79a171d6bf2e989e308c": "224d38d84051a360dd6a1f2ecbee3ade",
".git/objects/4d/bf9da7bcce5387354fe394985b98ebae39df43": "534c022f4a0845274cbd61ff6c9c9c33",
".git/objects/4f/fbe6ec4693664cb4ff395edf3d949bd4607391": "2beb9ca6c799e0ff64e0ad79f9e55e69",
".git/objects/50/9f21c87159bff6b59c2a54caddd77bdf38d769": "aef91bddd7291b5988a3ab71a1687ad2",
".git/objects/5f/8ec39b780f87bcd080897c616f75d037c07119": "2f01e56f9e36a6773cb748905a8e566c",
".git/objects/64/8f836c3f57106f98201d704543e9c6ea74ca7a": "1158ffd8114845e75b36e87f993fed26",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/6f/6ae74a54a9c9fa619a1df8974919b3d4b0ca02": "21ed752cca83717d45eb8e5a2d2fe43d",
".git/objects/73/e4d4304fe1e4966f2ae2e324c182049cc9fcc2": "40ebdf859628d9335d588f4df6bbbe0b",
".git/objects/7a/6c1911dddaea52e2dbffc15e45e428ec9a9915": "f1dee6885dc6f71f357a8e825bda0286",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/8b/8ac8fc83182fba1d60222b4b96f26af409a8ee": "847cded2eb98dff32661325383df539c",
".git/objects/95/30d84d564033577d4e985b703e5df42e1884ca": "1298e80928d09609b301daac6bb7f676",
".git/objects/98/0d49437042d93ffa850a60d02cef584a35a85c": "8e18e4c1b6c83800103ff097cc222444",
".git/objects/9b/3ef5f169177a64f91eafe11e52b58c60db3df2": "91d370e4f73d42e0a622f3e44af9e7b1",
".git/objects/9d/a719a63804c85cbcab7eb0ad081246b1e2cbfe": "cdd454fa17d0fa6ea565a7aa08794d4b",
".git/objects/9e/3b4630b3b8461ff43c272714e00bb47942263e": "accf36d08c0545fa02199021e5902d52",
".git/objects/a6/2094fc0a62c79e68420fdf7f949cb103b19cce": "1362b7a09c0ed8ac68b2df75841ed48a",
".git/objects/b1/d5db560323ba2dcf320bf10201fd9fcdd440da": "18fef0e85176da24582ae52e91f087a1",
".git/objects/b6/b8806f5f9d33389d53c2868e6ea1aca7445229": "b14016efdbcda10804235f3a45562bbf",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b8/4a335249946b628875b2fa1eea69c2677ec28b": "8e8bc74bac2d2986d1321192910f454e",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/bf/0b03e1ed5a9997386cc50aa1cb9cbc86ada32f": "f1898a2007234f227feb4dee8895981a",
".git/objects/c1/535384035076827e0d1fb638f8b8ee5bd5c7be": "5bf44c8dba9f7b8a15ab619bc239bfd0",
".git/objects/c4/016f7d68c0d70816a0c784867168ffa8f419e1": "fdf8b8a8484741e7a3a558ed9d22f21d",
".git/objects/ca/3bba02c77c467ef18cffe2d4c857e003ad6d5d": "316e3d817e75cf7b1fd9b0226c088a43",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/e3/e9ee754c75ae07cc3d19f9b8c1e656cc4946a1": "14066365125dcce5aec8eb1454f0d127",
".git/objects/e4/d11bf9cc59f393cedd20e94bc8116e0feceaf9": "4d845b9048bd3fe23cac3bfee75cc034",
".git/objects/e4/fa81ef7e3c8a97147e0c96c54b1a1c0963dcaf": "eb1f1362547bb77237d3883b77eb3fe4",
".git/objects/e7/6d2622886b75e048991d644f8c630011c7ef82": "d59250c7138f7280527472af13692e83",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/eb/f66ec2a0a1a1dd2ff0849f39f7e8deb29d9f52": "0397741302fc8382a227d6cc41540e12",
".git/objects/ec/180737d1a451f3cd2e905483bc81727a4e2313": "be53946b2e0e96c9ba4ab914b18341b7",
".git/objects/ed/b55d4deb8363b6afa65df71d1f9fd8c7787f22": "886ebb77561ff26a755e09883903891d",
".git/objects/ef/7e6eef1bd38cc460e034640fac8a390df71480": "bedc76980036f3f72e2190070f36e8c4",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f2/a609b3f81552452cfb5f78786b2f055df002bc": "e5598c4ccc18a075827c25c09d2b6cd4",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/fb/c54f1dbcc48d08589fbd9e32bc206be0230bb3": "910c2f5ca72253df6aece6240948646b",
".git/objects/fe/3b987e61ed346808d9aa023ce3073530ad7426": "dc7db10bf25046b27091222383ede515",
".git/objects/fe/dcc3eb72680076e673f3a402e47375fdd816ba": "df1ab47f0af0f10c86d4237251d68d8e",
".git/refs/heads/gh-pages": "c8d4494df2ff5f50ba6b9b0e564b4acf",
"assets/AssetManifest.bin": "c5d192f5f60954a7550b84b1c0364b64",
"assets/AssetManifest.bin.json": "0ca6903c6d64afb150505a658e930f56",
"assets/AssetManifest.json": "b4c19a414f2ef0f9ad8c6ee3dc386b73",
"assets/assets/images/accountant_avatar.png": "4c4cc6e7f7e074ee2371b05fbc211664",
"assets/assets/images/app_logo.png": "ef0b9eb559cf789d0bd151f61f0546fb",
"assets/assets/images/google_logo.png": "0dd54f853a1bffb0e9979f8146268af3",
"assets/assets/images/splash_image.png": "e228e335d0491cb32a314a00517ce809",
"assets/assets/images/splash_screen.png": "08f4ec8093200f767a53dde31010ed70",
"assets/FontManifest.json": "7e9433d5386f1e47ab22f0afd8e7a4f9",
"assets/fonts/MaterialIcons-Regular.otf": "4ecd1c73dc40682fab0b11e45ce1c716",
"assets/fonts/NotoSans-Regular.ttf": "b72e420edb95cdf06e6e0a27bc0d964d",
"assets/NOTICES": "6c9bf27ee80f8d3aebeb54a680375694",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "6da4a31c993e2bbf906fbb95bd7630e0",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "0ecac944de8ef18b40a21d6a5e636908",
"icons/Icon-192.png": "e85a02562699aa79875ac1e5cc851881",
"icons/Icon-512.png": "0ffd887ad5c9a217a52419de752a2236",
"icons/Icon-maskable-192.png": "e85a02562699aa79875ac1e5cc851881",
"icons/Icon-maskable-512.png": "0ffd887ad5c9a217a52419de752a2236",
"index.html": "4ea1896c4d972d59ea82188636a257fa",
"/": "4ea1896c4d972d59ea82188636a257fa",
"main.dart.js": "8f9bee625669eb1ec75cd5aed686a572",
"manifest.json": "91c75743b8719e715a3003663d93e505",
"splash/img/dark-1x.png": "6351cf98f433d9eef3f9f40d84e95e36",
"splash/img/dark-2x.png": "17d8ceeaaf7acb7683803041e0f2e3ed",
"splash/img/dark-3x.png": "12caf199993a16607d6b24d2b11e30e8",
"splash/img/dark-4x.png": "c70294db311098b0d9f31e230f116597",
"splash/img/light-1x.png": "6351cf98f433d9eef3f9f40d84e95e36",
"splash/img/light-2x.png": "17d8ceeaaf7acb7683803041e0f2e3ed",
"splash/img/light-3x.png": "12caf199993a16607d6b24d2b11e30e8",
"splash/img/light-4x.png": "c70294db311098b0d9f31e230f116597",
"version.json": "6d865479881e0284856d65458dc49ec7"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
