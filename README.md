# Shadowsocks-iOS-Demo
Demo how to build an iOS project with shadowsocks buildin.


* Clone this project.
* Open project file in Finder.
* Drag the Shadowsocks-iOS-Demo/shadowsocks folder to XCode, confirm the dialog keep the default options.
* Click your project name in XCode, click the main target, switch to the Build Phases tab, open the Compile Sources section. Remove files excluding ev.c, interpose.c and encrypt.c in shadowsocks/libev.
* Remove file references excluding ev.c in shadowsocks/libev from the files tree in left sidebar.
* Copy the code from the method application:didFinishLaunchingWithOptions: in AppDelegate.m. Don't forget the imports.
* Replace the remote server configs with yours.
* You should wait about 1s after the app launched and then start network request.
