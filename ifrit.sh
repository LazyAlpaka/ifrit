#!/bin/bash
# IFRIT. Stands for: Incident Forensic Response In Terminal =)
# https://xakep.ru/2023/05/03/linux-incident-response/
# provided by Alex und Boris
# https://github.com/LazyAlpaka/ifrit
# Предпочтительно исполнение от рута (sudo)
# Использование: chmod a+x ./ifrit.sh && ./ifrit.sh
# Значком #! закомменчена часть команд, которые надо адаптировать под свои кейсы

echo " _________________ _____ _____ "
echo "|_   _|  ___| ___ \_   _|_   _|"
echo "  | | | |_  | |_/ / | |   | |  "
echo "  | | |  _| |    /  | |   | |  "
echo " _| |_| |   | |\ \ _| |_  | |  "
echo " \___/\_|   \_| \_|\___/  \_/  "
echo
echo "Incident Forensic Response In Terminal"
echo "build 27.05.2023"

# Разрешим скрипту продолжать выполняться с ошибками. Это необязательно, для острастки
set +e

# Задаём массивы переменных
#! Даты и время предполагаемого инцидента для поиска изменённых за это время файлов (потом ищем их в домашних каталогах)
startdate="2023-05-20 00:53:00"
enddate="2023-05-27 05:00:00" 

#! IP-адресов, ищем в логах приложений /usr /etc /var. Оставь пустым, если не нужно
#ips=("1.2.3.5" "6.7.8.9" )
ips=()

#! Терминов\слов для поиска в домашних каталогах и файлах
# terms=("терменвокс"  "1.2.3.4" )
terms=()

#! Папок и путей для поиска подозрительных мест залегания
# Сейчас - Shishiga и Rotajakiro
# iocfiles=()
iocfiles="/etc/rc2.d/S04syslogd
/etc/rc3.d/S04syslogd
/etc/rc4.d/S04syslogd
/etc/rc5.d/S04syslogd
/etc/init.d/syslogd
/bin/syslogd
/etc/cron.hourly/syslogd
/tmp/drop
/tmp/srv
$HOME/.local/ssh.txt
$HOME/.local/telnet.txt
$HOME/.local/nodes.cfg
$HOME/.local/check
$HOME/.local/script.bt
$HOME/.local/update.bt
$HOME/.local/server.bt
$HOME/.local/syslog
$HOME/.local/syslog.pid
$HOME/.dbus/sessions/session-dbus 
$HOME/.gvfsd/.profile/gvfsd-helper"

# Задаём цветную раскраску для консоли
# Set the color variable
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'
# Пример использования: 
# printf "The script was exePRINTcuted ${green}successfully${clear}!"
# echo -e "The script was execuECHOted ${green}successfully${clear}"

# Фиксируем текущую дату
start=$(date +%s)

# Проверка, что мы root
echo "Текущий пользователь:"
echo $(id -u -n)

# «Без root будет бедная форензика»
if (( $EUID != 0 )); then
    echo -e "${red}Пользователь не root${clear}"
fi  

# Делаем директорию для сохранения всех результатов (если не указан аргумент скрипта)
if [ -z $1 ]; then
    part1=$(hostname) # Имя хоста
    echo "Наш хост: $part1"
    time_stamp=$(date +%Y-%m-%d-%H.%M.%S) # Берем дату и время
    curruser=$(whoami) # Текущий юзер
    saveto="./${part1}_${curruser}_$time_stamp" # Имя директории
else
   saveto=$1
fi

# Создаем директорию и переходим в нее
mkdir -pv $saveto
cd $saveto

# Создаем вложенную директорию для триаж-файлов
mkdir -p ./artifacts

# Начинаем писать лог в файл
	# Кодировка файлов по умолчанию  UTF-8
    # Пример команды в формате:
	# echo "Название модуля"
	# Выводим текущий этап в профильный лог
	# echo "Название модуля" >> <тематический файл>
	# Выводим результат работы команды в профильный лог
    # <выполняемая команда> >> <тематический файл>
	# Вставляем пустую строку в профильный лог-файл для удобочитаемости и разделения результатов отдельных команд
	# echo -e "\n" >> <тематический файл>
	# UPDATE 27.05.2023
	# Формат тот же, но вместо бесконечных >> >> делаем красиво через {}>> (где это возможно)
	
{

# Сравниваем хеш данного скрипта, начиная с 135 строчки, и до конца с эталонным значением
# from 135 line till end
echo "Проверим свою целостность..."
SCRIPTPATH=$(realpath -s "../$0")
tail -n+135 $SCRIPTPATH > thsh.txt
currhash=$(md5sum thsh.txt | awk '{print $1}')
# чтобы посчитать tarhash, используй две верхних строчки на эталонном скрипте, или скопируй текущий хеш из вывода консоли
tarhash="aa458f9ca0233151337faf9b7b63c16e" #! 27052023, 135 line+
echo $currhash
echo $tarhash
if [ "$currhash" = "$tarhash" ]; then
    echo -e "${green}Hashes are equal! Continue... ${clear} \n" 
else
    echo -e "${red}Invalid hashes! Be careful!${clear} \n" 
fi
rm thsh.txt

# ----------------------------------
# ----------------------------------
# СБОР ДАННЫХ О ХОСТЕ

# Начинаем писать файл host_info >>>
#echo -n > host_info
echo -e "${magenta}[Сбор информации по хосту]${clear}" 
{
echo "[Текущий хост и время]"  
echo "Текущая дата и системное время:" 
date 
echo -e "\n" 

echo "[Имя хоста:]" 
hostname 
echo -e "\n" 

# Сведения о релизе ОС, например из файла os-release
# Аналоги: cat /usr/lib/os-release или lsb_release
echo "[Доп информация о системе из etc/*(-release|_version)]" 
more /etc/*release | cat 
more /etc/*version | cat 
echo -e "\n" 

echo "[Доп информация о системе из /etc/issue]" 
cat /etc/issue 
echo -e "\n" 

echo "[Идентификатор хоста (hostid)]" 
hostid 
echo -e "\n" 

echo "[Информация из hostnamectl]" 
hostnamectl 
echo -e "\n" 

echo "[IP адрес(а):]" 
ip addr  # Информация о текущем IP-адресе
echo -e "\n" 

echo "[Информация о системе]" 
uname -a 
echo -e "\n" 

echo "[Текущий пользователь:]" 
# whoami
who am i 
echo -e "\n" 

echo "[Информация об учетных записях и группах]"
for name in $(ls /home); do
    id $name  
done
echo -e "\n" 

# в астра 1.7 зависает
#echo "[Информация об учетных записях из getent (Astra)]" 
#if  uname -a | grep astra; then
#    eval getent passwd {$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)..$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)} | cut -d: -f1
#    echo -e "\n" 
#fi
# аналог 
# getent passwd {1000..60000} >/dev/null 2>&1
} >> host_info

# Получим список живых пользователей. Зачастую мы хотим просто посмотреть реальных пользователей, у которых есть каталоги, чтобы в них порыться. Запишем имена в переменную для последующей эксплуатации
echo "Пользователи с /home/:" 
{
echo "[Пользователи с /home/:]"  
ls /home 
# Исключаем папку lost+found
users=`ls /home -I lost*`
echo $users
echo -e "\n" 

echo "[Залогиненные юзеры:" 
w 
echo -e "\n" 
} >> host_info

# <<< Заканчиваем писать файл host_info
# ----------------------------------
# ----------------------------------

# Раскомментируй следующую строчку, чтобы сделать паузу и что-нибудь скушать. Затем нажми Enter, чтобы продолжить
# read -p "Press [Enter] key to continue fetch..."
# Пользовательские файлы

# ----------------------------------
# ----------------------------------
# Начинаем писать файл users_files >>>

echo -e "${magenta}[Пользовательские файлы]${clear}"

{
echo "[Пользовательские файлы из (Downloads,Documents, Desktop)]" 
ls -la /home/*/Downloads 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Загрузки 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Documents 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Документы 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Desktop/ 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Рабочий\ стол/ 2>/dev/null 
echo -e "\n" 

# Составляем список файлов в корзине
echo "[Файлы в корзине из home]" 
ls -laR /home/*/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Для рута тоже на всякий случай
echo "[Файлы в корзине из root]" 
ls -laR /root/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Кешированные изображения могут помочь понять, какие программы использовались
echo "[Кешированные изображения программ из home]" 
ls -la /home/*/.thumbnails/ 2>/dev/null 
echo -e "\n" 
} >> users_files

# Ищем в домашних пользовательских папках
#! grep -A2 -B2 -rn 'терменвокс' --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info

#! Ищем лакомые термины в домашних пользовательских папках
echo "[Ищем ключевые слова...]"

for f in ${terms[@]};
do
    echo "Search $f" 
    echo -e "\n" >> ioc_word_info
    grep -A2 -B2 -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info
done


#! echo "[Поиск интересных файловых расширений в папках home и root:]" >> users_files
#! find /root /home -type f -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml 2>/dev/null >> users_files
#! echo -e "\n" >> users_files

# Ищем логи приложений (но не в /var/log)
#! echo "[Возможные логи приложений (с именем или расширением *log*)]"
#! find /root /home /bin /etc /lib64 /opt /run /usr -type f -name \*log* 2>/dev/null >> int_files_info

# Ищем в домашнем каталоге файлы с изменениями (созданием) в определённый временной интервал
#! echo "[Ищем между датами от ${startdate} до ${enddate}]"
# пример запуска:
# find /home/* -type f -newermt "2023-02-24 00:00:11" \! -newermt "2023-02-24 00:53:00" -ls >> int_files_info
#! find /home/* -type f -newermt "${startdate}" \! -newermt "${enddate}" -ls >> int_files_info

echo "[Таймлайн файлов в домашних каталогах (CSV)]"
{
echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" 
echo -n 
find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null 
} >> users_files_timeline

# <<< Заканчиваем писать файл users_files
# ----------------------------------
# ----------------------------------

# Приложения

# ----------------------------------
# ----------------------------------
# Начинаем писать файл apps_file >>>

echo -e "${magenta}[Приложения в системе]${clear}"

{
echo "[Проверка браузеров]" 
# Firefox, артефакты: ~/.mozilla/firefox/*, ~/.mozilla/firefox/* и ~/.cache/mozilla/firefox/*
firefox --version 2>/dev/null 
# Firefox, альтернативная проверка
dpkg -l | grep firefox 
# Thunderbird. Можно при успехе просмотреть содержимое каталога командой ls -la ~/.thunderbird/*, поискать календарь, сохраненную переписку
thunderbird --version 2>/dev/null 
# Chromium. Артефакты:  ~/.config/chromium/*
chromium --version 2>/dev/null 
# Google Chrome. Артефакты можно брать из ~/.cache/google-chrome/* и ~/.cache/chrome-remote-desktop/chrome-profile/
chrome --version 2>/dev/null 
# Opera. Артефакты ~/.config/opera/*
opera --version 2>/dev/null 
# Brave. Артефакты: ~/.config/BraveSoftware/Brave-Browser/*
brave --version 2>/dev/null 
# Бета Яндекс-браузера для Linux. Артефакты: ~/.config/yandex-browser-beta/*
yandex-browser-beta --version 2>/dev/null 
echo -e "\n" 

# Мессенджеры и Ко
echo "[Проверка мессенджеров и других приложений]" 
signal-desktop --version 2>/dev/null 
viber --version 2>/dev/null 
whatsapp-desktop --version 2>/dev/null 
tdesktop --version 2>/dev/null 
# Также можно проверить каталог: ls -la ~/.zoom/*
zoom --version 2>/dev/null 
# Можешь проверить и каталог: ls -la ~/.steam
steam --version 2>/dev/null 
discord --version 2>/dev/null 
dropbox --version 2>/dev/null 
yandex-disk --version 2>/dev/null 
echo -e "\n" 
} >> apps_file

echo "[Сохранение профилей популярных браузеров в папку ./artifacts]"

{
echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
mkdir -p ./artifacts/gchrome
cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
mkdir -p ./artifacts/chromium
cp -r /home/*/.config/chromium ./artifacts/chromium

echo "[Проверка приложений торрента]"  
apt list --installed 2>/dev/null | grep torrent  
echo -e "\n" 

echo "[Все пакеты, установленные в системе]"  
# Список всех установленных пакетов APT; также попробуй dpkg -l
apt list --installed 2>/dev/null 
echo -e "\n" 
# Следующая команда позволяет получить список пакетов, установленных вручную
echo "[Все пакеты, установленные в системе (вручную)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 

echo "[Все пакеты, установленные в системе (вручную, вар. 2)]"  
apt list --manual-installed 2>/dev/null | grep -F \[installed\]
echo -e "\n" 

# Для астры выводи список приложений, исключая системный мусор
echo "[Альтернативный список программ (astra)]"  
echo "[Apps ls -la /usr/share/applications]"
ls /usr/share/applications | awk -F '.desktop' ' { print $1}' - | grep -v -e fly -e org -e okularApplication 
echo -e "\n" 

# Как вариант, можешь написать aptitude search '!~M ~i' или aptitude search -F %p '~i!~M'
# Для openSUSE, ALT, Mandriva, Fedora, Red Hat, CentOS
rpm -qa --qf "(%{INSTALLTIME:date}): %{NAME}-%{VERSION}\n" 2>/dev/null 
echo -e "\n" 
# Для Fedora, Red Hat, CentOS
yum list installed 2>/dev/null 
echo -e "\n" 
# Для Fedora
dnf list installed 2>/dev/null 
echo -e "\n" 
# Для Arch
pacman -Q 2>/dev/null 
echo -e "\n" 
# Для openSUSE
zypper info 2>/dev/null 
echo -e "\n" 
echo -e "\n" 

# Запущенные процессы с удалённым исполняемым файлом
# https://sandflysecurity.com/blog/how-to-recover-a-deleted-binary-from-active-linux-malware/
echo "[Processes with deleted executable]"  
find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
echo -e "\n" 
} >> apps_file


# <<< Заканчиваем писать файл apps_file
# ----------------------------------
# ----------------------------------

# Проверка виртуальных извратов и альтернатив мест залегания

# ----------------------------------
# ----------------------------------
# Начинаем писать файл virt_apps_file >>>

echo -e "${magenta}[Приложения виртуализации или эмуляции в системе и проверка GRUB]${clear}"

{
echo "[Проверка приложения Virtualbox]"  
apt list --installed  2>/dev/null | grep virtualbox 
echo -e "\n" 

echo "[Проверка KVM (guest OS)]"  
virsh list --all 2>/dev/null 
echo -e "\n" 

# А вот так можем посмотреть логи QEMU, в том числе и об активности виртуальных машин
echo "[Проверка логов QEMU]"  
more /home/*/.cache/libvirt/qemu/log/* 2>/dev/null | cat 
echo -e "\n" 

echo "[Проверка приложений Wine]"  
# иногда wine будет создавать здесь конфиг...
winetricks list-installed 2>/dev/null 
winetricks settings list 2>/dev/null 
ls -la /home/*/.wine/drive_c/program_files 2>/dev/null 
ls -la /home/*/.wine/drive_c/Program 2>/dev/null 
ls -la /home/*/.wine/drive_c/Program\ Files/ 2>/dev/null 
ls -la /home/*/.wine/drive_c/Program/ 2>/dev/null 
echo -e "\n" 

echo "[Проверка приложений контейнеризации]" 
# Артефакты Docker: /var/lib/docker/containers/*/
docker --version 2>/dev/null 
# Артефакты containerd : /etc/containerd/* и /var/lib/containerd/
containerd --version 2>/dev/null 
echo -e "\n" 

echo "[Вывод содержимого загрузочного меню, то есть список ОС (GRUB)]"  
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg 2>/dev/null 
echo -e "\n" 

echo "[Конфиг файл GRUB]"  
cat /boot/grub/grub.cfg 2>/dev/null 
echo -e "\n" 

echo "[Проверка на наличие загрузочных ОС]"  
os-prober  
echo -e "\n" 
} >> virt_apps_file

# <<< Заканчиваем писать файл virt_apps_file
# ----------------------------------
# ----------------------------------

# Активность в ретроспективе

# ----------------------------------
# ----------------------------------
# Начинаем писать файл history_info >>>

echo -e "${yellow}[Историческая информация]${clear}"

{
# Текущее время работы системы, количество залогиненных пользователей, средняя загрузка системы за 1, 5 и 15 мин
echo "[Время работы системы, количество залогиненных пользователей]" 
uptime 
echo -e "\n" 

echo "[Журнал перезагрузок (last -x reboot)]" 
last -x reboot 
echo -e "\n" 

echo "[Журнал выключений (last -x shutdown)]" 
last -x shutdown 
echo -e "\n" 

# Список последних входов в систему с указанием даты (/var/log/lastlog)
echo "[Список последних входов в систему (/var/log/lastlog)]" 
lastlog 
echo -e "\n" 

# Список последних залогиненных юзеров (/var/log/wtmp), их сессий, ребутов и включений и выключений
echo "[Список последних залогиненных юзеров с деталями (/var/log/wtmp)]" 
last -Faiwx 
echo -e "\n" 

echo "[Последние команды из fc текущего пользователя]" 
fc -li 1 2>/dev/null 
# history -a
echo -e "\n" 
# Аналог команды history, выводит список последних команд, выполненных текущим пользователем в терминале
echo "[Последние команды из fc текущего пользователя (вер. 2)]" 
fc -l 1 
echo -e "\n" 

if ls /root/.*_history >/dev/null 2>&1; then
    echo "[История пользоватея Root (/root/.*history)]" 
    more /root/.*history | cat 
	echo -e "\n" 
fi

for name in $(ls /home); do
	# Здесь же можно использовать и нашу переменную $users (но я не захотел)
    echo "[История пользоватея ${name} (.*history)]" 
    more /home/$name/.*history 2>/dev/null | cat    
    echo -e "\n" 
	echo "[История команд Python пользоватея ${name}]" 
	more /home/$name/.python_history 2>/dev/null | cat 
	echo -e "\n" 
done

# История установки пакетов. Также можно грепать в файлах /var/log/dpkg.log*, например
echo "[История установленных приложений из /var/log/dpkg.log]" 
grep "install " /var/log/dpkg.log 
echo -e "\n" 

# История установки пакетов в архивных логах. Для поиска во всех заархивированных системных логах исправь dpkg.log на *
echo "[Архив истории установленных приложений из /var/log/dpkg.log.gz ]" 
zcat /var/log/dpkg.log.gz | grep "install " 
echo -e "\n" 

echo "[История обновленных приложений из /var/log/dpkg.log]" 
grep "upgrade " /var/log/dpkg.log 
echo -e "\n" 

echo "[История удаленных приложений из /var/log/dpkg.log]" 
grep "remove " /var/log/dpkg.log 
echo -e "\n" 

echo "[История о последних apt-действиях (history.log)]" 
cat /var/log/apt/history.log 
echo -e "\n" 

# Доп файлы, которые мб имеет смысл посмотреть
#/var/log/dpkg.log*;
#/var/log/apt/history.log*;
#/var/log/apt/term.log*;
#/var/lib/dpkg/status.
} >> history_info 

# <<< Заканчиваем писать файл history_info
# ----------------------------------
# ----------------------------------

# Сетевичок (сетевая часть)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл network_info >>>

echo -e "${blue}[Проверка сетевой информации]${clear}"

{
# Информация о сетевых адаптерах. Аналоги: ip l и ifconfig -a
echo "[IP адрес(а):]" 
ip a 
echo -e "\n" 

echo "[Настройки сети]" 
ifconfig -a 2>/dev/null 
echo -e "\n" 

echo "[Сетевые интерфейсы (конфиги)]" 
cat /etc/network/interfaces 
echo -e "\n" 

echo "[Настройки DNS]" 
cat /etc/resolv.conf 
cat /etc/host.conf    2>/dev/null 
echo -e "\n" 

echo "[Сетевой менеджер (nmcli)]" 
nmcli 
echo -e "\n" 

echo "[Беспроводные сети (iwconfig)]" 
iwconfig 2>/dev/null 
echo -e "\n" 

echo "[Информация из hosts (local DNS)]" 
cat /etc/hosts 
echo -e "\n" 

echo "[Сетевое имя машины (hostname)]" 
cat /etc/hostname 
echo -e "\n" 

echo "[Сохраненные VPN ключи]" 
ip xfrm state list 
echo -e "\n" 

echo "[ARP таблица]" 
arp -e 2>/dev/null 
# ip n 2>/dev/null 
echo -e "\n" 

echo "[Таблица маршрутизации]" 
ip r 2>/dev/null 
# route 2>/dev/null 
echo -e "\n" 

echo "[Проверка настроенных прокси]" 
echo "$http_proxy" 
echo -e "\n" 
echo "$https_proxy"
echo -e "\n" 
env | grep proxy 
echo -e "\n" 

echo "[Проверяем наличие интернета и внешнего IP-адреса]" 
wget -T 2 -O- https://api.ipify.org 2>/dev/null | tee -a network_info
# Аналог:
curl ifconfig.co # https://xakep.ru/2016/09/08/19-shell-scripts/ 
echo -e "\n" 

# База аренд DHCP-сервера (файлы dhcpd.leases). Гламурный аналог — утилита dhcp-lease-list
echo "[Проверяем информацию из DHCP]" 
more /var/lib/dhcp/* 2>/dev/null | cat 
# Основные конфиги DHCP-сервера (можно сразу убрать из вывода все строки, начинающиеся с комментариев, и посмотреть именно актуальный конфиг, если тебе это надо, конечно)
more /etc/dhcp/* | cat | grep -vE ^ 2>/dev/null 
# В логах смотрим инфу о назначенном адресе по DHCP
journalctl |  grep  " lease" 
# При установленном NetworkManager
journalctl |  grep  "DHCP" 
echo -e "\n" 
# Информация о DHCP-действиях на хосте
journalctl | grep -i dhcpd 
echo -e "\n" 

echo "[Сетевые процессы и сокеты с адресами]" 
# Активные сетевые процессы и сокеты с адресами. Эти же ключи сработают для утилиты ss ниже
netstat -anp 2>/dev/null 
#netstat -anoptu
#netstat -rn
# Актуальная альтернатива netstat, выводит имена процессов (если запуск от суперпользователя) с текущими TCP/UDP-соединениями
ss -tupln 2>/dev/null 
echo -e "\n" 

echo "[Количество сетевых полуоткрытых соединений]" 
#netstat -tan | grep -i syn | wc -с
netstat -tan | grep -с -i syn 2>/dev/null 
echo -e "\n" 

echo "[Сетевые соединения (lsof -i)]" 
lsof -i 
echo -e "\n" 
} >> network_info 

{
# Незамысловатый карвинг из логов сетевых соединений
echo "[Network connections list - connection]" 
journalctl -u NetworkManager | grep -i "connection '" 
echo -e "\n" 
echo "[Network connections list - addresses]" 
journalctl -u NetworkManager | grep -i "address"  # адресов

echo -e "\n" 
echo "[Network connections wifi enabling]" 
journalctl -u NetworkManager | grep -i wi-fi  # подключений-отключений Wi-Fi
echo -e "\n" 

echo "[Network connections internet]" 
journalctl -u NetworkManager | grep -i global -A2 -B2  # подключений к интернету
echo -e "\n" 

# Сети Wi-Fi, к которым подключались
echo "[wifi networks info]"  
grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null 
echo -e "\n" 
# Альтернатива
cat /etc/NetworkManager/system-connections/* 2>/dev/null 
echo -e "\n" 

# collect "iptables" information
echo "[Firewall configuration iptables-save]"  
iptables-save 2>/dev/null 
echo -e "\n" 
iptables -n -L -v --line-numbers 
echo -e "\n" 

# Список правил файрвола nftables
echo "[Firewall configuration nftables]"  
nft list ruleset 
echo -e "\n" 
} >> network_add_info

{
# Ищем IP-адреса в логах и выводим список
#! journalctl | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]| sudo [01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' | sort |uniq
#! grep -r -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' /var/log | sort | uniq

# Ищем айпишник среди данных приложений
#! grep -A2 -B2 -rn '66.66.55.42' --exclude="*ifrit.sh" --exclude-dir=$saveto /usr /etc  2>/dev/null 

#! Ищем айпишник в логах или конфигах приложений, как вариант
echo "[Ищем IP-адреса в текстовых файлах...]"
for f in ${ips[@]};
do
    echo "Search $f" 
    echo -e "\n" 
    grep -A2 -B2 -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /usr /etc /var 2>/dev/null 
done
} >> IP_search_info


# <<< Заканчиваем писать файл network_info
# ----------------------------------
# ----------------------------------

# Активные демоны, процессы, задачи и их конфигурации
# (и типовые места закрепления вредоносов, часть 1)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл activity_info >>>

echo -e "${magenta}[Проверка активностей (процессы, планировщики ...) в системе]${clear}"

{
# Вывод информации о текущих альтернативных задачах в screen
echo "[Список текущих активных сессий (Screen)]"  
screen -ls 2>/dev/null 
echo -e "\n" 

echo "[Фоновые задачи (jobs)]"  
jobs 
echo -e "\n" 

echo "[Задачи в планировщике (Crontab)]" 
crontab -l 2>/dev/null 
echo -e "\n" 
} >> activity_info 

{
echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" 
more /etc/cron*/* | cat 
echo -e "\n" 

echo "[Вывод запланированных задач для всех юзеров (Crontab)]" 
for user in $(ls /home/); do echo $user; crontab -u $user -l;   echo -e "\n"  ; done
echo -e "\n" 

echo "[Лог планировщика (Crontab) в файлах /etc/cron*]" 
more /var/log/cron.log* | cat 
echo -e "\n" 
} >> cronconfigs_info

{
echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" 
cat /etc/crontab 
echo -e "\n" 

echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]"  
ls -la  /etc/xdg/autostart/* 2>/dev/null   
echo -e "\n" 

echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]"  
cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null   
echo -e "\n" 

echo "[Автозагрузка в GNOME и KDE]"  
more  /home/*/.config/autostart/*.desktop 2>/dev/null | cat  
echo -e "\n" 

echo "[Задачи из systemctl list-timers (предстоящие задачи)]" >> host_info
systemctl list-timers 
echo -e "\n" 

# Список всех запущенных процессов, лучше класть в отдельный файлик
echo "[Список процессов (ROOT)]" 
ps -l 
echo -e "\n" 

echo "[Список процессов (все)]" 
ps aux 
#ps -eaf
echo -e "\n" 
} >> activity_info

{
# Гламурный вывод дерева процессов
echo "[Дерево процессов]" 
#pstree -Aup 
pstree -aups
echo -e "\n" 
} >> pstree_file

{
echo "[Файлы с выводом в /dev/null]" 
lsof -w /dev/null 
echo -e "\n" 
} >> lsof_file

{
# Текстовый вывод аналога виндового диспетчера задач
echo "[Инфа о процессах через top]" 
top -bcn1 -w512  
echo -e "\n" 

echo "[Вывод задач в бэкграунде atjobs]" 
ls -la /var/spool/cron/atjobs 2>/dev/null 
echo -e "\n" 

echo "[Вывод jobs из var/spool/at/]" 
more /var/spool/at/* 2>/dev/null | cat 
echo -e "\n" 

echo "[Файлы deny|allow со списками юзеров, которым разрешено в cron или jobs]" 
more /etc/at.* 2>/dev/null | cat 
echo -e "\n" 

echo "[Вывод задач Anacron]" 
more /var/spool/anacron/cron.* 2>/dev/null | cat 
echo -e "\n" 

echo "[Пользовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" 
more /etc/rc*/* 2>/dev/null | cat 
more /etc/rc.d/* 2>/dev/null | cat 
echo -e "\n" 
} >> activity_info 
# Package files
echo -e "${green}[Пакуем LOG-файлы (/var/log/)...]${clear}"
echo "[Пакуем LOG-файлы...]" >> activity_info 


# /var/log/
tar -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null

# Шпора:
#/var/log/auth.log Аутентификация
#/var/log/cron.log Cron задачи
#/ var / log / maillog Почта
#/ var / log / httpd Apache
# Подробнее: https://www.securitylab.ru/analytics/520469.php


# <<< Заканчиваем писать файл activity_info
# ----------------------------------
# ----------------------------------

# Активные службы и их конфиги
# (и типовые места закрепления вредоносов, часть 2)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл services_info >>>

echo -e "${cyan}[Проверка сервисов в системе]${clear}"

{
echo "[Список активных служб systemd]"  
systemctl list-units  
echo -e "\n" 

echo "[Список всех служб]"  
# можно отдельно посмотреть модули ядра: cat /etc/modules.conf и cat /etc/modprobe.d/*
systemctl list-unit-files --type=service 
echo -e "\n" 

echo "[Статус работы всех служб (командой service)]"  
service --status-all 2>/dev/null 
echo -e "\n" 
} >> services_info 

{
echo "[Вывод конфигураций всех сервисов]"  
more /etc/systemd/system/*.service | cat 
echo -e "\n" 
} >> services_configs

{
echo "[Список запускаемых сервисов (init)]"  
ls -la /etc/init  2>/dev/null 
echo -e "\n" 

echo "[Сценарии запуска и остановки демонов (init.d)]"  
ls -la /etc/init.d  2>/dev/null 
echo -e "\n" 
} >> services_info

# <<< Заканчиваем писать файл services_info
# ----------------------------------
# ----------------------------------

# ----------------------------------
# ----------------------------------
# Начинаем писать файл devices_info >>>

echo -e "${magenta}[Информация об устройствах]${clear}"
{
# Вывод инфо о PCI-шине
echo "[Информация об устройствах (lspci)]" 
lspci 
echo -e "\n" 

echo "[Устройства USB (lsusb)]" 
lsusb 
echo -e "\n" 

echo "[Блочные устройства (lsblk)]" 
lsblk 
echo -e "\n" 
# more /sys/bus/pci/devices/*/* | cat 

echo "[Список примонтированных файловых систем (findmnt)]" 
findmnt 
echo -e "\n" 

echo "[Bluetooth устройства (bt-device -l)]" 
bt-device -l 2>/dev/null 
echo -e "\n" 

echo "[Bluetooth устройства (hcitool dev)]" 
hcitool dev 2>/dev/null 
echo -e "\n" 

echo "[Bluetooth устройства (/var/lib/bluetooth)]" 
ls -laR /var/lib/bluetooth/ 2>/dev/null 
echo -e "\n" 

# Пример usbrip, если он установлен
# https://github.com/snovvcrash/usbrip
echo "[Устройства USB (usbrip)]" 
usbrip events history 2>/dev/null 
echo -e "\n" 

# Подключенные в текущей сессии USB-устройства — у Linux аптайм обычно большой, может, прокатит
echo "[Устройства USB из dmesg]" 
dmesg | grep -i usb 2>/dev/null 
echo -e "\n" 

# Usbrip делает то же самое, но потом обрабатывает данные и делает красиво
echo "[Устройства USB из journalctl]" 
journalctl | grep -i usb 
# journalctl -o short-iso-precise | grep -iw usb
echo -e "\n" 

echo "[Устройства USB из syslog]" 
cat /var/log/syslog* | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 

echo "[Устройства USB из (log messages)]" 
cat /var/log/messages* | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null 
echo -e "\n" 
} >> devices_info 

{
# Как ты понимаешь, устройства в текущей сессии имеет смысл собирать, только если система давно не перезагружалась
echo "[Устройства USB (самогреп dmesg)]" 
dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 
echo "[Устройства USB (самогреп journalctl)]" 
journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 
} >> usb_list_file

{
echo "[Другие устройства из journalctl]" 
journalctl| grep -i 'PCI|ACPI|Plug' 2>/dev/null 
echo -e "\n" 

echo "[Подключение/отключение сетевого кабеля (адаптера) из journalctl]" 
journalctl | grep "NIC Link is" 2>/dev/null 
echo -e "\n" 

# Открытие/закрытие крышки ноутбука
echo "[LID open-downs:]"  
journalctl | grep "Lid"  2>/dev/null  
echo -e "\n" 
} >> devices_info

# <<< Заканчиваем писать файл devices_info
# ----------------------------------
# ----------------------------------

# Закрепы вредоносов
# собираем инфу и конфиги для последующего анализа

# ----------------------------------
# ----------------------------------
# Начинаем писать файл env_profile_info >>>

echo -e "${cyan}[Информация о переменных системы, шелле и профилях пользователей]${clear}"
{
echo "[Глобальные переменные среды ОС (env)]" 
env 
echo -e "\n" 

echo "[Все текущие переменные среды]" 
printenv 
echo -e "\n" 

echo "[Переменные шелла]" 
set 
echo -e "\n" 

echo "[Расположнеие исполняемых файлов доступных шеллов:]" 
cat /etc/shells 2>/dev/null 
echo -e "\n" 

if [ -e "/etc/profile" ] ; then
    echo "[Содержимое из /etc/profile]" 
    cat /etc/profile 2>/dev/null 
    echo -e "\n" 
fi
} >> env_profile_info

{
echo "[Содержимое из файлов /home/users/.*]" 
for name in $(ls /home); do
    #more /home/$name/.*_profile 2>/dev/null | cat 
	echo Hidden config-files for: $name 
	more /home/$name/.* 2>/dev/null | cat  
    echo -e "\n" 
done
} >> usrs_cfgs

{
# Нижеследующие команды (пять блоков if) можно успешно заменить на эту:
echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
more /root/.* 2>/dev/null | cat 
echo -e "\n" 
} >> root_cfg

{
# убрать при review кода:
#if ls /root/.*_profile >/dev/null 2>&1; then
#    echo "[Содержимое из /root/.*_profile]" 
#    cat /root/.*_profile 2>/dev/null 
#    echo -e "\n" 
#fi

#if ls /root/.*_login >/dev/null 2>&1;then
#    echo "[Содержимое из /root/.*_login]" 
#    cat /root/.*_login 
#    echo -e "\n" 
#fi

#if [ -e "/root/.profile" ]; then
#    echo "[Содержимое из /root/.profile]" 
#    cat /root/.profile 2>/dev/null 
#    echo -e "\n" 
#fi

#if ls /root/.*rc >/dev/null 2>&1;then
#    echo "[Содержимое из /root/.*rc]" 
#    cat /root/.*rc 
#    echo -e "\n" 
#fi

#if ls /root/.*_logout >/dev/null 2>&1; then 
#    echo "[Содержимое из /root/.*_logout]" 
#    cat /root/.*_logout 
#    echo -e "\n" 
#fi

# Список файлов, пример
#.*_profile (.profile)
#.*_login
#.*_logout
#.*rc
#.*history 

echo "[Пользователи SUDO]" 
cat /etc/sudoers 2>/dev/null 
echo -e "\n" 
} >> env_profile_info

# <<< Заканчиваем писать файл env_profile_info
# ----------------------------------
# ----------------------------------

# Сюда помещаем крайне специфичные случаи, которые можно по-хорошему и удалить 
# Быть может, кому-то поможет в части избыточной информации
#! - начало для файла junk_info

# ----------------------------------
# ----------------------------------
# Начинаем писать файл junk_info >>>

echo -e "${cyan}[Рандомные вещи....]${clear}"
{
# Проверимся на руткиты, иногда помогает
echo "[Проверка на rootkits командой chkrootkit]" 
chkrootkit 2>/dev/null 
echo -e "\n" 
} >> junk_info

echo -e "${yellow}[Файловые IOC?]${clear}"
echo "[IOC-paths?]" >> junk_info
echo -e "\n" >> junk_info
# https://www.welivesecurity.com/2017/04/25/linux-shishiga-malware-using-lua-scripts/

counter=0;
for f in $iocfiles
do
if [ -e $f ]
then 
	#$counter=$counter +1;
	counter=$((counter+1)) # thanks duodai
	echo -e "${red}IOC-path found: ${clear}" $f
	echo "IOC-path found: " $f >> junk_info
	echo -e "\n" >> junk_info
fi
done

if [ $counter -gt 0 ]
then 
	echo -e "${red}IOC Markers found!!${clear}" 
	echo "IOC Markers found!!" >> junk_info
	echo -e "\n" >> junk_info
fi

# ниже идут команды, которые применялись в самой первой версии скрипта, который представлял собой безумную компиляцию из кучи команд без особого понимания в их необходимости. но в части ресурсов, книг и других скриптов они, возможно, были...
# ...а теперь мне просто западло их убирать

echo -e "${yellow}[i am alive, just processing...]${clear}"

{
# time information diff maybe?
echo "[BIOS TIME]" 
hwclock -r 2>/dev/null 
echo -e "\n" 
echo "[SYSTEM TIME]" 
date 
echo -e "\n" 

# privilege information
echo "[PRIVILEGE passwd - all users]" 
cat /etc/passwd 2>/dev/null 
echo -e "\n" 

# ssh keys
echo "[Additional info cat ssh (root) keys and hosts]" 
cat /root/.ssh/authorized_keys 2>/dev/null 
cat /root/.ssh/known_hosts 2>/dev/null 
echo -e "\n" 

#for users:
echo "[Additional info cat ssh (users) keys and hosts]" 
for name in $(ls /home)
do
echo SSH-files for: $name 
cat /home/$name/.ssh/authorized_keys 2>/dev/null 
echo -e "\n" 
cat /home/$name/.ssh/known_hosts 2>/dev/null 
done
echo -e "\n" 

# VM - detection
echo "[Virtual Machine Detection]" 
dmidecode -s system-manufacturer 2>/dev/null 
echo -e "\n" 
dmidecode  2>/dev/null 
echo -e "\n" 

# HTTP server inforamtion collection
# Nginx collection
echo "[Nginx Info]" 
echo -e "\n" 
# tar default directory
if [ -e "/usr/local/nginx" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
	echo "Grab NGINX files!" 
	echo -e "\n" 
fi

# Apache2 collection
echo "[Apache Info]" 
echo -e "\n" 
# tar default directory
if [ -e "/etc/apache2" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/apache2 2>/dev/null
	echo "Grab APACHE files!" 
	echo -e "\n" 
fi

# Install files
echo "[Core modules - lsmod]" 
lsmod 
echo -e "\n" 

echo "[Пустые пароли ?]" 
cat /etc/shadow | awk -F: '($2==""){print $1}' 
echo -e "\n" 

# Malware collection
# .bin
#echo "[BIN FILETYPE]" 
#find / -name \*.bin 
#echo -e "\n" 

# .exe
#echo "[BIN FILETYPE]" 
#find / -name \*.exe 
#echo -e "\n" 

#find copied
# Find nouser or nogroup  data
echo "[NOUSER files]" 
find /root /home -nouser 2>/dev/null 
echo -e "\n" 

# check for files without holder
# find / -xdev \( -nouser -o -nogroup \) -print
# check for files without holder
# find / \( -perm -4000 -o -perm -2000 \) -print

echo "[NOGROUP files]" 
find /root /home -nogroup 2>/dev/null 
echo -e "\n" 

} >> junk_info

{
echo "[lsof -n]" 
lsof -n 2>/dev/null
echo -e "\n" 

echo "[Verbose open files: lsof -V ]"  #open ports
lsof -V  
# lsof 
echo -e "\n" 
} >> lsof_file

{
if [ -e /var/log/btmp ]
	then 
	echo "[Last LOGIN fails: lastb]" 
	lastb 2>/dev/null 
	echo -e "\n" 
fi

if [ -e /var/log/wtmp ]
	then 
	echo "[Login logs and reboot: last -f /var/log/wtmp]" 
	last -f /var/log/wtmp 
	echo -e "\n" 
fi

if [ -e /etc/inetd.conf ]
then
	echo "[inetd.conf]" 
	cat /etc/inetd.conf 
	echo -e "\n" 
fi

echo "[File system info: df -k in blocks]" 
df -k 
echo -e "\n" 

echo "[File system info: df -Th in human format]" 
df -Th 
echo -e "\n" 

echo "[List of mounted filesystems: mount]" 
mount 
echo -e "\n" 

echo "[kernel messages: dmesg]" 
dmesg 2>/dev/null 
echo -e "\n" 

echo "[Repo info: cat /etc/apt/sources.list]"  
cat /etc/apt/sources.list 
echo -e "\n" 

echo "[Static file system info: cat /etc/fstab]"  
cat /etc/fstab 2>/dev/null 
echo -e "\n" 

# echo "Begin Additional Sequence Now *********************************"

# Vurtual memory statistics
echo "[Virtual memory state: vmstat]"  
vmstat 
echo -e "\n" 

# Check for hardware events
echo "[HD devices check: dmesg | grep hd]"  
dmesg | grep -i hd 2>/dev/null 
echo -e "\n" 

# Show activity log
echo "[Get log messages: cat /var/log/messages]"  
cat /var/log/messages 2>/dev/null 
echo -e "\n" 

echo "[USB check 3 Try: cat /var/log/messages]"  
cat /var/log/messages | grep -i usb 2>/dev/null 
echo -e "\n" 

# List all mounted files and drives
echo "[List all mounted files and drives: ls -lat /mnt]"  
ls -lat /mnt 
echo -e "\n" 

echo "[Disk usage: du -sh]"  
du -sh 
echo -e "\n" 

echo "[Disk partition info: fdisk -l]"  
fdisk -l 2>/dev/null 
echo -e "\n" 

echo "[Additional info - OS version cat /proc/version]" 
cat /proc/version 
echo -e "\n" 

echo "[Additional info lsb_release (distribution info)]" 
lsb_release 2>/dev/null 
echo -e "\n" 

echo "[Query journal: journalctl]"  
journalctl 
##journalctl -o export > journal-exp.txt
echo -e "\n" 

echo "[Memory free]"  
free 
echo -e "\n" 

echo "[Hardware: lshw]"  
lshw 2>/dev/null 
echo -e "\n" 

echo "[Hardware info: cat /proc/(cpuinfo|meminfo)]"  
cat /proc/cpuinfo 
echo -e "\n" 
cat /proc/meminfo 
echo -e "\n" 

echo "[/sbin/sysctl -a (core parameters list)]"  
/sbin/sysctl -a 2>/dev/null 
echo -e "\n" 

echo "[Profile parameters: cat /etc/profile.d/*]"  
cat /etc/profile.d/* 2>/dev/null 
echo -e "\n" 

echo "[Language locale]"  
locale  2>/dev/null 
echo -e "\n" 

#manual installed
echo "[Get manually installed packages apt-mark showmanual (TOP)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 

echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]"  
apt list --manual-installed 2>/dev/null | grep -F \[installed\]  
echo -e "\n" 
#aptitude search '!~M ~i'
#aptitude search -F %p '~i!~M'

mkdir -p ./artifacts/config_root
#desktop icons and other_stuff
cp -r /root/.config ./artifacts/config_root 2>/dev/null 
#saved desktop sessions of users
cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

echo "[VMware clipboard (root)!]" 
ls -laR /root/.cache/vmware/drag_and_drop/ 2>/dev/null 
echo -e "\n" 

echo "[Mails of root]" 
cat /var/mail/root 2>/dev/null 
echo -e "\n" 

#cp -R ~/.config/ 2>/dev/null 

#ls -la /usr/share/applications
echo "[Apps ls -la /usr/share/applications]"  
ls -la /usr/share/applications 
#ls -la /home/*/.local/share/applications/ 
echo -e "\n" 

#recent 
echo "[Recently-Used]"  
more  /home/*/.local/share/recently-used.xbel 2>/dev/null | cat 
echo -e "\n"  

#get mail for each user:
#echo "[Recently-Used]"  
#cat /var/mail/username$ 2>/dev/null 

#mini list of apps
echo "[Var-LIBS directories - like program list]"  
ls -la /var/lib 2>/dev/null  
echo -e "\n" 

# crypto stuff
echo "[Some encypted data?]"  
cat /etc/crypttab 2>/dev/null  
echo -e "\n" 

# Default settings for user directories
echo "[User dirs default configs]"  
cat /etc/xdg/user-dirs.defaults  2>/dev/null  
echo -e "\n"       

#os info
echo "[OS-release:]"  
cat /etc/os-release 2>/dev/null  
echo -e "\n" 

#list boots 
echo "[List of boots]"  
journalctl --list-boots  2>/dev/null  
echo -e "\n" 

#machine ID
echo "[Machine-ID:]"  
cat /etc/machine-id 2>/dev/null 
echo -e "\n" 

#analyze ssl certs and keys
echo "[SSL files:]"  
ls -laR /etc/ssl    2>/dev/null  
echo -e "\n" 

#GPG info
echo "[GnuPG contains:]"  
ls -laR /home/*/.gnupg/* 2>/dev/null  
echo -e "\n" 

# Здесь можно встретить информацию в виде dat-файлов о состоянии батареи ноутбука, включая процент зарядки, расход и состояние отключения батарейки и ее заряда
#battery info for laptops
#history­charge­*.dat — log of percentage charged
# history­rate­*.dat — log of energy consumption rate
#history­time­empty­*.dat — when unplugged, log of time (in seconds) until empty
# history­time­full­*.dat — when charging, log of time (in seconds) until full
echo "[Battery logs]"  
more /var/lib/upower/* 2>/dev/null | cat  
echo -e "\n"  

echo "Get UUID of partitions: blkid" 
blkid 2>/dev/null 
echo -e "\n" 

echo "[Volumes: vol*]" 
more /media/data/vol* 2>/dev/null | cat 
echo -e "\n" 
} >> junk_info

#COPY ALL WEB PROFILES FOR THE GOD!
echo "[Web collection]"
{
echo "[Web collection start...]" 
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla 

#HISTORY OF BROWSERS: places.sqlite
#firefox^
#file ~/.mozilla/firefox/*.default/places.sqlite
#~/.mozilla/firefox/*.default/places.sqlite: SQLite 3.x database, user version 26

#chrome^
#$ file ~/.config/google-chrome-beta/Default/History           
#.config/google-chrome-beta/Default/History: SQLite 3.x database

#Bookmarks
#~/.config/google-chrome/Default/Bookmarks
#~/.config/chromium/Default/Bookmarks

echo "[Look through (SSH) service logs for errors]" 
journalctl _SYSTEMD_UNIT=sshd.service | grep “error” 2>/dev/null 
echo -e "\n" 
} >> junk_info

echo "Get users Recent and personalize collection"
echo "Get users Recent and personalize collection (without Trash files)" >> junk_info

for usa in $users
do
	mkdir -p ./artifacts/share_user/$usa
	cp -r /home/$usa/.local/share ./artifacts/share_user/$usa 2>/dev/null 
done
# because probably too large directory
rm -r ./artifacts/share_user/$usa/Trash 2>/dev/null 
rm -r ./artifacts/share_user/$usa/share/Trash/files 2>/dev/null 

mkdir -p ./artifacts/share_root
cp -r /root/.local/share ./artifacts/share_root 2>/dev/null 
rm -r ./artifacts/share_root/Trash 2>/dev/null 
rm -r ./artifacts/share_root/share/Trash/files 2>/dev/null 
#ls -la /home/*/.local/share/applications/ 

mkdir -p ./artifacts/config_user
#cp -r /home/*/.config ./config_user
for usa in $users
do
	mkdir -p ./artifacts/config_user/$usa
	#desktop icons and other_stuff
	cp -r /home/$usa/.config ./artifacts/config_user/$usa 2>/dev/null 

	#saved desktop sessions of users
	cp -R /home/$usa/.cache/sessions ./artifacts/config_user/$usa 2>/dev/null 
	
	{
	#check mail:
	echo "[Mails of $usa:]" 
	cat /var/mail/$usa 2>/dev/null 
	echo -e "\n" 

	echo "[VMware clipboard (maybe)!]" 
	ls -laR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
	echo -e "\n" 
	} >> junk_info
done

# <<< Заканчиваем писать файл junk_info
# ----------------------------------
# ----------------------------------
#! - конец для записи файла junk_info

# ----------------------------------
# ----------------------------------

# Архивируем собранные артефакты
echo "Packing artifacts..."
tar --remove-files -zc -f ./artifacts.tar.gz artifacts 2>/dev/null

{  
echo "Завершили сбор данных!" 
date 
echo -e "\n" 
} >> host_info

# Завершающая часть после выполнения необходимых команд
# Для выходной директории даем права всем на чтение и удаление
 chmod -R ugo+rwx ./../$saveto
 end=`date +%s`
 echo -e "\n" 
 echo ENDED! Execution time was $(expr $end - $start) seconds.
 echo -e "${magenta}Проверяй директорию ${saveto}! ${clear}"
 pathe=$(readlink -f $saveto)
 echo -e "${yellow}Полный путь: ${pathe}! ${clear}"
# Открываем директорию в файловом менеджере — работает не во всех дистрибутивах. В Astra также можно использовать команду fly-fm
# xdg-open .
# лучше графон открывать не от рута, а от текущего юзера:
# namer=$(logname)
# sudo -u $namer xdg-open .
#! однако без sudo или при работе в терминале, оставь так или убери вообще:
xdg-open . 2>/dev/null
 } |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log) # Наш лог-файл, фильтруем цветовые формантанты