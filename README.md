# WGLM3U8Processing
This a m3u8 processing tool


                iOS集成FFmpeg

一、准备文件：
1、gas-preprocessor文件
https://github.com/libav/gas-preprocessor
2、yasm文件
https://github.com/yasm/yasm
3、FFmpeg-iOS-build-script脚本文件
https://github.com/kewlbear/FFmpeg-iOS-build-script

二、gas-preprocessor处理
1、复制gas-preprocessor.pl到/usr/local/bin下
2、chmod 777 /usr/local/bin/gas-preprocessor.pl

三、yasm处理
1、现在进入下载后的yasm文件夹，通过编译安装命令yasm
./configure && make -j 4 && sudo make install

2、如果上一步失败，换Homebrew包管理器，进行安装
如果brew没有安装（终端输入brew可以验证是否已安装brew），则执行下面命令进行安装
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
安装好brew后，执行brew install yasm安装brew

四、FFmpeg-iOS-build-script处理
1、进入FFmpeg-iOS-build-script文件夹内
2、解压后，找到build-ffmpeg.sh
3、执行脚本文件（耗时操作，等待十几分钟）
./build-ffmpeg.sh（编译所有的版本arm64、armv7、x86_64的静态库）
./build-ffmpeg.sh arm64（编译支持arm64架构的静态库）
./build-ffmpeg.sh armv7 x86_64（编译适用于armv7和x86_64(64-bit simulator)的静态库）
./build-ffmpeg.sh lipo（编译合并的版本）

五、iOS工程配置
1、添加ffmpeg的静态库.a和头文件：
找到ffmpeg-iOS文件（包括了include/头文件、lib/静态库.a），将其加入到iOS工程中
2、添加系统依赖库：
libiconv.tbd、libbz2.1.0.tbd、libz.tbd
3、静态库添加配置路径
Library Search Paths —> $(PROJECT_DIR)/FFmpeg-iOS/lib
Header Search Paths —> $(PROJECT_DIR)/FFmpeg-iOS/include


                  Mac配置FFmpeg环境

一、安装homebrew
"homebrew"是Mac平台的一个包管理工具，提供了许多Mac下没有的Linux工具等，而且安装过程很简单。
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

二、安装FFmpeg

1、利用上面的homebrew安装FFmpeg：
brew install ffmpeg
2、查看你的安装ffmpeg的信息：
brew info ffmpeg
3、非必要操作：
brew upgrade ffmpeg（更新ffmpeg）

三、Mac通过终端使用FFmpeg命令
视频转换：
下载一个.flv格式的视频，并将这个视频转换成mp4格式，并将码率设置成640kbps。
ffmpeg  -i  /Users/lixiangyang/Desktop/脱口秀.flv  -b:v  640k  脱口秀.mp4


四、注意事项

1、ffmpeg 转码指令，如果outputPath文件是存在的，会crash ？

