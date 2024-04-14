#!/bin/bash
if [ -z "$1" ]; then
	echo "Provide C++ (Qt) source project folder as argument"
	exit 1
fi
if [ ! -d "$1" ]; then
	echo "Argument is not a directory."
	echo "Provide C++ (Qt) source project folder as argument"
	exit 1
fi

g++ "$1"/*.cpp -o "$1"/mylibrary.so -fPIC -lluajit-5.1 -lQt5Core -O2 \
-I/usr/include/aarch64-linux-gnu/qt5 -I/usr/include/aarch64-linux-gnu/qt5/QtCore -shared -I/usr/include/lua5.3/ -Ilibs/StorageSrc/ \
-Wl,-rpath,/home/jmactf/server5.8/games/jma-capturetheflag/libs -Llibs/ $2
