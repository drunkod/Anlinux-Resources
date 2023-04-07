#!/data/data/com.termux/files/usr/bin/bash
folder=alpine-fs
# проверить, существует ли уже папка
if [ -d "$folder" ]; then
	first=1 
	# установить флаг для пропуска загрузки
	echo "skipping downloading"
fi

# Этот раздел скрипта загружает архивный файл, содержащий корневую файловую систему Alpine Linux,
# если для переменной first не установлено значение 1, что означает, что каталог «alpine-fs»
# не существует. Он проверяет, существует ли файл tarball в текущем рабочем каталоге, и, если нет,
# загружает его на основе архитектуры текущего устройства с помощью команды «wget».


tarball="alpine-rootfs.tar.gz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "Download Rootfs, this may take a while base on your internet speed."
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		x86_64)
			archurl="amd64" ;;	
		i*86)
			archurl="i386" ;;
		x86)
			archurl="i386" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
		cat ~/storage/downloads/alpine-rootfs-${archurl}.tar.gz > $tarball
	fi
	cur=`pwd`
	mkdir -p "$folder"
	cd "$folder"
	echo "Decompressing Rootfs, please be patient."
	proot --link2symlink tar -xf ${cur}/${tarball} --exclude='dev' 2> /dev/null||:
	cd "$cur"
fi

# создание папки alpine-binds и скрипта запуска start-alpine.sh

mkdir -p alpine-binds
bin=start-alpine.sh
echo "writing launch script"

cat > $bin <<- EOM
#!/bin/bash
# сменить каталог на каталог, содержащий этот скрипт
cd \$(dirname \$0)

pulseaudio --start
## For rooted user: pulseaudio --start --system
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD

# установить команду proot с опциями и аргументами
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"

# Включить любые монтирования привязки, указанные в каталоге alpine-binds
if [ -n "\$(ls -A alpine-binds)" ]; then
    for f in alpine-binds/* ;do
      . \$f
    done
fi
# Настройте связывающее монтирование для /dev, /proc и /dev/shm
command+=" -b /dev"
command+=" -b /proc"
command+=" -b alpine-fs/root:/dev/shm"

## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to / 
#command+=" -b /sdcard"
# установите рабочий каталог в /root
command+=" -w /root"
# начните с пустых переменных окружения
command+=" /usr/bin/env -i"
# установите переменную окружения HOME
command+=" HOME=/root"
command+=" PATH=PATH=/bin:/usr/bin:/sbin:/usr/sbin"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
# начать с оболочки входа в систему
command+=" /bin/sh --login"

# выполнить команду proot с аргументами, переданными скрипту
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

echo "Setting up pulseaudio so you can have music in distro."

pkg install pulseaudio -y

if grep -q "anonymous" ~/../usr/etc/pulse/default.pa;then
    echo "module already present"
else
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
fi

echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
echo "Modified pulseaudio timeout to infinite"
echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
echo "Disabled pulseaudio autospawn"
echo "export PULSE_SERVER=127.0.0.1" >> alpine-fs/etc/profile
echo "Setting Pulseaudio server to 127.0.0.1"


echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "removing image for some space"
rm $tarball
echo "Preparing additional component for the first time, please wait..."
rm alpine-fs/etc/resolv.conf
wget "https://raw.githubusercontent.com/drunkod/AnLinux-Resources/master/Scripts/Installer/Alpine/resolv.conf" -P alpine-fs/etc
echo "You can now launch Alpine with the ./${bin} script"
