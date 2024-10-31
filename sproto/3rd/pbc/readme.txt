当前目录

make
cd ./binding/lua53
make
cp protobuf.lua ../../../../mylualib/
cp  ../../../protobuf.so ../../../../luaclib/



在Ubuntu 22.04下安装 protoc：
sudo apt update  
sudo apt install protobuf-compiler  
protoc --version  
