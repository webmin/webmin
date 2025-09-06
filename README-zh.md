## 内容
* [更新日志](https://github.com/webmin/webmin/blob/master/CHANGELOG.md)
* [关于](#关于)
* [安装](#安装)[<img src="https://github.com/webmin-devel/webmin/blob/master/media/download-23x14-stable.png?raw=true" title="稳定版">](http://webmin.com/download.html)[<img src="https://github.com/webmin-devel/webmin/blob/master/media/download-23x14-devel.png?raw=true" title="Development Versions">](http://webmin.com/devel.html)
* [文档](#文档)
* [致谢](#致谢)
* [许可](#许可)

## 关于

**Webmin** 是一个基于网页的类Unix服务器系统管理工具，全球安装超过 _1,000,000_ 次（没错，事宝藏！）。有了它，运维快人一步！比如用户，磁盘配额，服务或者配置文件，比如更改，控制开源应用，再比如 BIND DNS Server，管理 Apache HTTP Server， PHP， MySQL， 还有[许多许多好东西](https://doxfer.webmin.com/Webmin/Introduction)。

[![Quick UI overview 2021](https://user-images.githubusercontent.com/4426533/114315375-61a1c480-9b07-11eb-9aaf-4aa949a39ab7.png)](https://www.youtube.com/watch?v=daYG6O4AsEw)

可通过安装可定制的模块来扩展可用性。 除此之外，还有另外两个扩展其功能的项目：

* [Virtualmin](https://www.virtualmin.com) 是一个强大的，灵活的，最受欢迎的，最全面的 Linux 和 BSD 系统网络托管控制面板，在全球拥有超过 _150,000次_ 安装。它有开源社区支持的版本，以及功能更丰富的Premium版本；
* [Usermin](https://github.com/webmin/usermin) 顾名思义，呈现和控制以用户为中心的功能子集，而不是管理员级别的任务。

Webmin 包括 _116_ 个[标准模块](https://doxfer.webmin.com/Webmin/Webmin_Modules)，并且至少有同样多的第三方模块。


### 系统要求
Perl 5.10 或更高。

## 安装
Webmin 可以两种方法安装：

 1. 下载一个预编译包，可用于不同的发行版（CentOS, Fedora, SuSE, Mandriva, Debian, Ubuntu, Solaris 和 [其他发行版](http://www.webmin.com/support.html)）。[下载页面直达车](http://webmin.com/download.html);
  <kbd>注：非常建议[在你的系统添加源](https://doxfer.webmin.com/Webmin/Installation)，这样可以自动更新</kbd>

 2. 下载并解压[源码](https://prdownloads.sourceforge.net/webadmin/webmin-1.996.tar.gz)然后运行[_setup.sh_](http://www.webmin.com/tgz.html) 脚本，无需任何选项，也就是说会直接安装到当前目录。或者使用命令行参数，例如目标目录。
  <kbd>注：如果你正在安装 Webmin [到Windows](http://www.webmin.com/windows.html) 系统上，你必须运行 `perl setup.pl` 命令。Windows 版能否正常运行取决于许多程序，和可能不属于标准发行版的模块。你需要 _process.exe_ 命令， _sc.exe_ 命令，以及 _Win32::Daemon_ Perl 模块。</kbd>

## 文档
完整的 Webmin 还有它所有模块的详细配置都在[维基页面](https://doxfer.webmin.com/Webmin/Main_Page).

## 致谢

### 首席开发者

* [Jamie Cameron](http://www.webmin.com/about.html) [![](https://github.com/webmin-devel/webmin/blob/master/media/linkedin-15x15.png?raw=true)](https://www.linkedin.com/in/jamiecameron2)

### 贡献者

* [Joe Cooper](https://github.com/swelljoe)
* [Ilia Rostovtsev](https://github.com/iliaross)
* [Kay Marquardt](https://github.com/gnadelwartz)
* [Nawawi Jamili](https://github.com/nawawi) + [其他无偿奉献的开发者](https://github.com/webmin/webmin/graphs/contributors)

## 许可

Webmin 基于 [BSD 许可](https://github.com/webmin/webmin/blob/master/LICENCE)发布。
