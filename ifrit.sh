#!/bin/bash
# IFRIT. Stands for: Incident Forensic Response In Terminal =)
# Official release 3.0 (19.05.2024)
# https://xakep.ru/2023/05/03/linux-incident-response/
# provided by Alex und Boris
# https://github.com/LazyAlpaka/ifrit
# Предпочтительно исполнение от рута (sudo)
# Использование: chmod a+x ./ifrit.sh && ./ifrit.sh
# Проблемы концов строк (bad interpreter) лечим через:
# sed -i -e 's/\r$//' ifrit.sh
# Значком #! ниже закомменчена часть команд, которые надо адаптировать под свои кейсы

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

echo -e "${red} _________________ _____ _____ ${clear}"
echo -e "${red}|_   _|  ___| ___ \_   _|_   _|${clear}"
echo -e "${red}  | | | |_  | |_/ / | |   | |  ${clear}"
echo -e "${red}  | | |  _| | ${magenta}😈${clear}${red} /  | |   | |  ${clear}"
echo -e "${red} _| |_| |   | |\ \ _| |_  | |  ${clear}"
echo -e "${red} \___/\_|   \_| \_|\___/  \_/  ${clear}"
echo
echo -e "${yellow}Incident Forensic Response In Terminal ${clear}"
echo -e "${yellow}build 19.05.2024 ${clear}"

# Разрешим скрипту продолжать выполняться с ошибками. Это необязательно, для острастки
set +e

# Задаём массивы переменных
#! Даты и время предполагаемого инцидента для поиска изменённых за это время файлов (потом ищем их в домашних каталогах)
startdate="2024-05-09 00:53:00"
enddate="2024-05-10 05:00:00" 


#! Будем ли ля будущего принудительно выставлять HISTTIMEFORMAT - чтобы в следующий раз в истории были прописаны временные метки
# по умолчанию  - 0 
set_history=0

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

# Фиксируем текущую дату
start=$(date +%s)

# Проверка, что мы root
echo -e "${magenta}[Текущий пользователь:]${clear}"
echo $(id -u -n)

# «Без root будет бедная форензика»
if (( $EUID != 0 )); then
# if [ $(id -u) -ne 0 ]; then
    echo -e "${red}Пользователь не root${clear}"
fi  

# Делаем директорию для сохранения всех результатов (если не указан аргумент скрипта)
if [ -z $1 ]; then
    part1=$(hostname) # Имя хоста
    echo -e "${magenta}Наш хост: $part1 ${clear}"
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

#### Это было весело, но на практике никто не использовал, поэтому комментирую 10.05.2024
#### Сравниваем хеш данного скрипта, начиная с 135 строчки, и до конца с эталонным значением
#### from 135 line till end
###echo "Проверим свою целостность..."
###SCRIPTPATH=$(realpath -s "../$0")
###tail -n+135 $SCRIPTPATH > thsh.txt
###currhash=$(md5sum thsh.txt | awk '{print $1}')
#### чтобы посчитать tarhash, используй две верхних строчки на эталонном скрипте, или скопируй текущий хеш из вывода консоли
###tarhash="aa458f9ca0233151337faf9b7b63c16e" #! 27052023, 135 line+
###echo $currhash
###echo $tarhash
###if [ "$currhash" = "$tarhash" ]; then
###    echo -e "${green}Hashes are equal! Continue... ${clear} \n" 
###else
###    echo -e "${red}Invalid hashes! Be careful!${clear} \n" 
###fi
###rm thsh.txt

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

echo "[DNS/FQDN:]" 
dnsdomainname 2>/dev/null
echo -e "\n" 

# Сведения о релизе ОС, например из файла os-release
# Аналоги: cat /usr/lib/os-release или lsb_release
echo "[Доп информация о системе из etc/*(-release|_version)]" 
cat /proc/version 2>/dev/null
echo -e "\n" 
more /etc/*release | cat 
more /etc/*version | cat 
echo -e "\n" 

# Для справки:
#Вывести непустые и некомментарии строчки 
# grep -v '^#' /file | grep -P '\S'

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


} >> host_info

# Получим список живых пользователей. Зачастую мы хотим просто посмотреть реальных пользователей, у которых есть каталоги, чтобы в них порыться. Запишем имена в переменную для последующей эксплуатации

echo -e "${magenta}[Анализ базы]${clear}" 
{
echo "[Пользователи с /home/:]"  
ls /home 
# Исключаем папку lost+found
users=`ls /home -I lost*`
#echo $users
echo -e "\n" 

echo "[Залогиненные юзеры:" 
w 
echo -e "\n" 
who --all 2>/dev/null 
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

echo -e "${magenta}[Базовая информация о пользователях и правах, файлах]${clear}"

#echo -e "${magenta}[Пользовательские файлы]${clear}"

{

# Расширенный анализ пользователей:
# получаем инфу о LDAP-настройках
echo "[Расширенный анализ пользователей]"; 

echo "[AD_cfg_info]"; 
cat /etc/sssd/sssd.conf 2>/dev/null
echo -e "\n" 

echo "[/etc/passwd]"; 
cat /etc/passwd  ;
echo -e "\n" 

echo "[/etc/group]"; 
cat /etc/group ; 
echo -e "\n" 

echo "[/home/users & passwd]"; 
# Из папки home забираем живых доменных юзеров (с @), обычных локальных юзеров, и дополняем списком из /etc/passwd
for name in $( ls -d /home/*/ | grep -oP '(?<=/home/).*?(?=@)' || ls -d /home/*/ | grep -oP '(?<=/home/).*?(?=/)' | grep -v '@' &&  cat /etc/passwd | cut -d: -f1 | uniq | sort); do   
echo "[id_$name ]"; 
id $name 2>&1;
echo -e "\n" ;
echo "[last_$name ]" ; 
# последние входы
last $name;   
echo -e "\n" ;
echo "[sudo for $name ]" ;  
# может ли этот юзер в SUDO
sudo -l -U $name 2>&1;
echo -e "\n" ; 
done;


echo "[Пользовательские файлы из (Downloads,Documents, Desktop)]" 
ls -lta /home/*/Downloads 2>/dev/null 
echo -e "\n" 
ls -lta /home/*/Загрузки 2>/dev/null 
echo -e "\n" 
ls -lta /home/*/Documents 2>/dev/null 
echo -e "\n" 
ls -lta /home/*/Документы 2>/dev/null 
echo -e "\n" 
ls -lta /home/*/Desktop/ 2>/dev/null 
echo -e "\n" 
ls -lta /home/*/Рабочий\ стол/ 2>/dev/null 
echo -e "\n" 

# Составляем список файлов в корзине
echo "[Файлы в корзине из home]" 
ls -ltaR /home/*/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Для рута тоже на всякий случай
echo "[Файлы в корзине из root]" 
ls -ltaR /root/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Кешированные изображения могут помочь понять, какие программы использовались
echo "[Кешированные изображения программ из home]" 
ls -lta /home/*/.thumbnails/ 2>/dev/null 
echo -e "\n" 

} >> users_files

# Ищем в домашних пользовательских папках
#! grep -C2 -rn 'терменвокс' --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info

#! Ищем лакомые термины в домашних пользовательских папках
echo -e "${magenta}[Ищем ключевые слова... ]{$clear}"

for f in ${terms[@]};
do
    echo "Search $f" 
    echo -e "\n" >> ioc_word_info
    grep -C2 -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info
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
# ещё вариант для определённых директорий:
# find -newerct "10 May 2024 05:00:00" ! -newerct "10 May 2024 11:00:00" -ls | sort

echo -e "${green}[Таймлайн файлов в домашних каталогах (CSV)]${clear}"
{
echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" 
echo -n 
find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null 

# некоторые исследователи предпочитают вариант:
# find /home /root -xdev -print0 | xargs -0 stat --printf="%i,%h,%n,%x,%y,%z,%w,%U,%G,%A,%s\n" 2>/dev/null


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

# Получить список графических приложений (с учётом фильтрации астровских дефолтных приложений)
echo "[Installed apps with GUI]" 
ls /usr/share/applications | awk -F '.desktop' ' { print $1}' - | grep -v -e "fly" -e "org" -e "okularApplication"
echo -e "\n" 

# Для астры выводи список приложений, исключая системный мусор
echo "[Apps ls -lta /usr/share/applications]"
#ls -lta /usr/share/applications 
#ls -la /home/*/.local/share/applications/ 
ls /usr/share/applications | awk -F '.desktop' ' { print $1}' - | grep -v -e fly -e org -e okularApplication 
echo -e "\n" 


echo "[Проверка браузеров]" 
# Firefox, артефакты: ~/.mozilla/firefox/*, ~/.mozilla/firefox/* и ~/.cache/mozilla/firefox/*
firefox --version 2>/dev/null 
# Firefox, альтернативная проверка
dpkg -l | grep firefox 
# Thunderbird. Можно при успехе просмотреть содержимое каталога командой ls -lta ~/.thunderbird/*, поискать календарь, сохраненную переписку
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


# Проверка стандартных приложений для открытия файлов
# xdg-mime query default application/xml 2>/dev/null
# Get part of registered apps, associated with mime types
#grep 'MimeType' /usr/share/applications/*.desktop | tr ';' '\n'
echo "[Desktop files props (short)]"
for dfile in $(ls /usr/share/applications/*.desktop); do
	echo $dfile
	cat $dfile | grep Name=
	cat $dfile | grep GenericName=
	cat $dfile | grep Comment=
	cat $dfile | grep Exec=
	cat $dfile | grep MimeType=
	echo -e "\n"  
done



# Мессенджеры и Ко
echo "[Проверка мессенджеров и других приложений]" 
signal-desktop --version 2>/dev/null 
viber --version 2>/dev/null 
whatsapp-desktop --version 2>/dev/null 
tdesktop --version 2>/dev/null 
# Также можно проверить каталог: ls -lta ~/.zoom/*
zoom --version 2>/dev/null 
# Можешь проверить и каталог: ls -lta ~/.steam
steam --version 2>/dev/null 
discord --version 2>/dev/null 
dropbox --version 2>/dev/null 
yandex-disk --version 2>/dev/null 
echo -e "\n" 

# Посмотрим расширения для приложений
# get browsers plugins/extensions
echo "[Get list of browsers extensions per user]"

# ! you can add your best favorite browser Extension path
browser_ext_paths="
.config/google-chrome/*/Extensions
.config/yandex-browser/Default/Extensions
.config/chromium/Default/Extensions
.config/BraveSoftware/Brave-Browser/Defaults/Extensions
.config/opera/Default/Extensions/
"

# check browser extensions
for usa in $(ls /home); do
for ext_p in $browser_ext_paths; do
for i in $(find /home/$usa/$ext_p -name 'manifest.json' 2>/dev/null); do
  n=$(grep -hIr name $i| cut -f4 -d '"'| sort)
  update=$(jq ".update_url" $i)
  ue=$(basename $(dirname $(dirname $i)))
  au=$(grep -hIr author $i| cut -f4 -d '"'| sort)
  echo -e "[$usa $(echo $ext_p | cut -d "/" -f 2) extensions:]\n"
  echo -e "Name: $n"
  echo -e "Author: $au"
  echo -e "ID: $ue"
  echo -e "Update URL: $update"
  echo -e "\n" 
done
done
done


# python packages
echo "[Python packages]"
pip list 2>/dev/null
echo -e "\n" 

# pip3 packages
pip3 list 2>/dev/null
echo -e "\n" 


} >> apps_file

echo -e "${magenta}[Сохранение профилей популярных браузеров в папку ./artifacts]${clear}"

{
echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla 2>/dev/null
mkdir -p ./artifacts/gchrome
cp -r /home/*/.config/google-chrome* ./artifacts/gchrome 2>/dev/null
mkdir -p ./artifacts/chromium
cp -r /home/*/.config/chromium ./artifacts/chromium 2>/dev/null
mkdir -p ./artifacts/brave
# maybe ~/.local/share/brave/Brave-browser
cp -r /home/*/.config/Brave* ./artifacts/brave 2>/dev/null
mkdir -p ./artifacts/opera
cp -r /home/*/.config/opera* ./artifacts/opera 2>/dev/null
mkdir -p ./artifacts/yandex
cp -r /home/*/.config/yandex* ./artifacts/yandex 2>/dev/null

# remove empty folders
find ./artifacts/ -maxdepth 1 -empty -type d -delete


echo "[Проверка приложений торрента]"  
apt list --installed 2>/dev/null | grep torrent  
echo -e "\n" 


echo "[Все пакеты, установленные в системе]"  
# Список всех установленных пакетов APT; также попробуй dpkg -l
apt list --installed 2>/dev/null 
echo -e "\n" 


# Список установленных пакетов через dpkg
echo "[dpkg - installed apps]" 2>/dev/null 
dpkg --get-selections 
echo -e "\n" 

# Следующая команда позволяет получить список пакетов, установленных вручную
echo "[Все пакеты, установленные в системе (вручную)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 

echo "[Все пакеты, установленные в системе (вручную, вар. 2)]"  
# fixed for Russ'ian language
apt list --manual-installed 2>/dev/null | grep -F -e \[установлен\] -e \[installed\]

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

# Поставил в конец, чтобы не мусорило
# get firefox extensions list
echo "[Firefox browser extensions for all ]"
more /home/*/.mozilla/firefox/*.default-release/extensions.json 2>/dev/null | cat
echo -e "\n" 

# get thunderbird extensions list
echo "[Thunderbird extensions for all users]"
more /home/*/.thunderbird/*.default-release/extensions.json 2>/dev/null| cat
echo -e "\n" 



} >> apps_file


# <<< Заканчиваем писать файл apps_file
# ----------------------------------
# ----------------------------------


# Проверка некоторых конфигов по безопасности (аудит, SELinux, AppArmor и Kerberos)
echo -e "${magenta}[Проверки по безопасности]${clear}"
# ----------------------------------
# ----------------------------------
# Начинаем писать файл secur_cfg >>>
{

# Базовые проверки для LDAP/Kerberos-синхронизаций
echo "[Kerberos check]" 
klist 2>/dev/null
echo -e "\n" 
klist -k -Ke 2>/dev/null
echo -e "\n" 
cat /etc/krbr5.* 2>/dev/null
echo -e "\n" 
ls /tmp | grep krb 2>/dev/null
echo -e "\n" 

# Проверка конфига SSH
echo "[SSH config check]"
cat /etc/ssh/sshd_config 2>/dev/null
echo -e "\n" 


# Конфигурация syslog-ng, rsyslog, syslogd,audispd
echo "[Syslog-ng conf]"  
more /etc/syslog-ng/*.conf 2>/dev/null | cat
echo -e "\n" 
echo "[Syslog conf]" 
cat /etc/syslog.conf 2>/dev/null
echo -e "\n" 
echo "[rsyslog conf]" 
cat /etc/rsyslog.conf 2>/dev/null
echo -e "\n" 
more /etc/rsyslog.d/*.conf 2>/dev/null | cat
echo -e "\n" 
echo "[audispd conf]" 
cat /etc/audit/plugins.d/syslog.conf 2>/dev/null 
echo -e "\n" 
cat /etc/audisp/plugins.d/syslog.conf 2>/dev/null 
echo -e "\n" 

# Проверка правил аудита - сам конфиг и правила аудита? + посмотрим что по факту
echo "[auditd conf]" 
cat /etc/audit/auditd.conf 2>/dev/null
echo -e "\n" 
more /etc/audit/rules.d/* 2>/dev/null | cat
echo -e "\n" 
cat /etc/audit/audit.rules 2>/dev/null
echo -e "\n" 
echo "[auditd loaded rules]" 
auditctl -l 2>/dev/null
echo -e "\n" 

# SE linux проверки
echo "[SE linux status check]"  
sestatus 2>/dev/null
echo -e "\n" 
getenforce 2>/dev/null
echo -e "\n" 
cat /etc/selinux/config 2>/dev/null
echo -e "\n" 
sudo semodule –l 2>/dev/null
echo -e "\n" 
getsebool -a 2>/dev/null
echo -e "\n" 
semanage boolean –l 2>/dev/null
echo -e "\n" 



echo "[Apparmor checks]"  
# APP armor checks
apparmor_status 2>/dev/null
echo -e "\n" 
aa-status 2>/dev/null
echo -e "\n" 
ls -d /etc/apparmor* 2>/dev/null
echo -e "\n" 
more /etc/apparmor.d/*  2>/dev/null | cat
echo -e "\n" 

echo "[Netstat and ps with extended security attributes (try)]"  
netstat –anpZ 2>/dev/null
echo -e "\n"
ps auxZe 2>/dev/null
echo -e "\n"

} >> secur_cfg


# <<< Заканчиваем писать файл secur_cfg
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
ls -lta /home/*/.wine/drive_c/program_files 2>/dev/null 
ls -lta /home/*/.wine/drive_c/Program 2>/dev/null 
ls -lta /home/*/.wine/drive_c/Program\ Files/ 2>/dev/null 
ls -lta /home/*/.wine/drive_c/Program/ 2>/dev/null 
echo -e "\n" 

echo "[Проверка приложений контейнеризации]" 
# Артефакты Docker: /var/lib/docker/containers/*/
docker --version 2>/dev/null 

# на всякий случай возьмем список контейнеров
docker list 2>/dev/null 
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
os-prober  2>/dev/null
echo -e "\n" 

echo "[Проверка доступных сборок ядра]"
ls /boot | grep vmlinuz-
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

# Красивый вывод истории команд В нужном нам формате.
# сработает, если в файле history прописывается метка времени
# Настройки HISTTIMEFORMAT затем возвращаем.
# Однако, данные команды сработают в интерактивной сесии, но не в данном скрипте.
#echo "[Glory history get]" 
#echo "HISTTIMEFORMAT: $HISTTIMEFORMAT"
#echo -e "\n" 
#hist_before=$HISTTIMEFORMAT && export HISTTIMEFORMAT="[%s %d-%m-%Y %H:%M:%S %Z] " && history && unset HISTTIMEFORMAT && HISTTIMEFORMAT=$hist_before
#echo -e "\n" 


# Например, .nano_history,mysql_history итд
if ls /root/.*_history >/dev/null 2>&1; then
    echo "[История пользоватея Root (/root/.*history)]" 
    more /root/.*history | cat 
	echo -e "\n" 
	# Для любителей повершелла - история команд powershell
	more /root/.local/share/powershell/PSReadline/* 2>/dev/null | cat
	echo -e "\n" 
fi

for name in $(ls /home); do
	# Здесь же можно использовать и нашу переменную $users (но я не захотел)
	echo "[Информация о учётной записи пользоватея ${name} (chage)]"
	chage –l $name 2>/dev/null
	echo -e "\n" 
    echo "[История пользоватея ${name} (.*history)]" 
    more /home/$name/.*history 2>/dev/null | cat    
    echo -e "\n" 
	#echo "[История команд Python пользоватея ${name}]" 
	#more /home/$name/.python_history 2>/dev/null | cat 
	#echo -e "\n" 
	# Для любителей повершелла - история команд powershell
	more /home/$name/.local/share/powershell/PSReadline/* 2>/dev/null | cat
	echo -e "\n" 
done

# История установки пакетов. Также можно грепать в файлах /var/log/dpkg.log*, например
echo "[История установленных приложений из /var/log/dpkg.log]" 
grep "install " /var/log/dpkg.log 
echo -e "\n" 

# История установки пакетов в архивных логах. Для поиска во всех заархивированных системных логах исправь dpkg.log на *
echo "[Архив истории установленных приложений из /var/log/dpkg.log.gz ]" 
zcat /var/log/dpkg.log.gz 2>/dev/null | grep "install " 
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

echo "[Маршруты и правила IPv4/v6]" 
# routing tables and rules
ip -4 route ls 2>/dev/null 
ip -4 rule ls 2>/dev/null 
echo -e "\n" 
ip -6 route ls 2>/dev/null 
ip -6 rule ls 2>/dev/null 
echo -e "\n" 


echo "[Сетевые интерфейсы (конфиги)]" 
cat /etc/network/interfaces 2>/dev/null
echo -e "\n" 
more /etc/network/interfaces.d/* 2>/dev/null| cat
echo -e "\n" 
cat /etc/sysconfig/network 2>/dev/null
echo -e "\n" 

echo "[Настройки DNS]" 
cat /etc/resolv.conf 
cat /etc/host.conf    2>/dev/null 
echo -e "\n" 

echo "[Сети:]" 
cat /etc/networks 2>/dev/null
echo -e "\n" 


echo "[Сетевой менеджер (nmcli)]" 
nmcli 2>/dev/null
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

echo "[Проверяем наличие интернета]" 
ping -c2 google.com
echo -e "\n" 
echo "[Внешний IP-адрес]" 
wget -T 2 -O- https://api.ipify.org 2>/dev/null 
#| tee -a network_info
echo -e "\n" 
# Аналог:
curl ifconfig.co 2>/dev/null
# https://xakep.ru/2016/09/08/19-shell-scripts/ 
echo -e "\n" 

# База аренд DHCP-сервера (файлы dhcpd.leases). Гламурный аналог — утилита dhcp-lease-list
echo "[Проверяем информацию из DHCP]" 
more /var/lib/dhcp/* 2>/dev/null | cat 
echo -e "\n" 
# Основные конфиги DHCP-сервера (можно сразу убрать из вывода все строки, начинающиеся с комментариев, и посмотреть именно актуальный конфиг, если тебе это надо, конечно)
more /etc/dhcp/* | cat | grep -vE ^ 2>/dev/null 
echo -e "\n" 
# В логах смотрим инфу о назначенном адресе по DHCP
echo "[DHCP in logs]" 
journalctl |  grep  " lease" 
echo -e "\n" 
# При установленном NetworkManager
journalctl |  grep  "DHCP" 
echo -e "\n" 
# Информация о DHCP-действиях на хосте
journalctl | grep -i dhcpd 
echo -e "\n" 

echo "[Сетевые процессы и сокеты с адресами]" 
# Активные сетевые процессы и сокеты с адресами. Эти же ключи сработают для утилиты ss ниже
netstat -anlp 2>/dev/null 
echo -e "\n" 
#netstat -anoptu
#netstat -rn
# netstat –abefoqrstx
# Актуальная альтернатива netstat, выводит имена процессов (если запуск от суперпользователя) с текущими TCP/UDP-соединениями
ss -tuplna 2>/dev/null 
echo -e "\n" 

echo "[Количество сетевых полуоткрытых соединений]" 
#netstat -tan | grep -i syn | wc -с
netstat -tan | grep -с -i syn 2>/dev/null 
echo -e "\n" 

echo "[Сетевые соединения (lsof -Pi)]" 
lsof -Pi 2>/dev/null
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
journalctl -u NetworkManager | grep -i global -C2  # подключений к интернету
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
iptables -n -L -v --line-numbers 2>/dev/null
echo -e "\n" 
iptables -S 2>/dev/null
echo -e "\n" 

# collect "ip6tables" information
echo "[Firewall configuration ipt6ables-save]"  
ip6tables-save 2>/dev/null 
echo -e "\n" 
ip6tables -n -L -v --line-numbers 2>/dev/null
echo -e "\n" 
# ip6tables -L 
ip6tables -S 2>/dev/null
echo -e "\n" 

# Список правил файрвола nftables
echo "[Firewall configuration nftables]"  
nft list ruleset 2>/dev/null
# alt:  /usr/sbin/nft list ruleset 2>/dev/null
echo -e "\n" 

# ufw status
echo "[UFW rules]"
ufw status verbose 2>/dev/null
echo -e "\n" 
# UFW show rules
echo "[UFW rules]"
ufw show added 2>/dev/null
echo -e "\n" 

# firewalld
# list firewalld zones
echo "[Firewalld]"
firewall-cmd --list-all-zones 2>/dev/null
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
    grep -C2 -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /usr /etc /var 2>/dev/null 
done

# Как вариант подсчёта встречаемости для accesslogs
# https://www.jaiminton.com/cheatsheet/DFIR/#size-of-file-bytes
# cut -d " " -f 1 access.log | sort -u | wc -l

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


# Вывод запущенных графических приложений
# можно вывести и всё, что привязано к дисплею:
# xlsclients | sort | uniq
echo "[Running GUI apps]"
xlsclients 2>/dev/null | awk {'print $2'} |sort | uniq
echo -e "\n" 
echo "[Running GUI apps from xwininfo]"
# alt: xwininfo -root -tree 
xwininfo -root -children 2>/dev/null
echo -e "\n" 


# debug and unused commands. Maybe another linux distro?
#wmctrl -lp
#pstree 
#xrestop 
#xrestop -b
#xlsclients 
#xlsclients -l
#xprop -id
#xwininfo
#wmctrl  -lp | awk  '{ print $3 }' | sort | uniq
# enddebug



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

echo -e "${magenta}[Анализ планировщиков]${clear}"
{
echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" 
more /etc/cron*/* | cat 
echo -e "\n" 

echo "[Вывод запланированных задач для всех юзеров (Crontab)]" 
for user in $(ls /home/); do echo "[Crontabs for $user]"; crontab -u $user -l;   echo -e "\n"  ; done
echo -e "\n" 

echo "[Лог планировщика (Crontab) в файлах /etc/cron*]" 
more /var/log/cron.log* 2>/dev/null | cat 
echo -e "\n" 

echo "[Общедоступный крон:]" 
find /etc/cron* -type f -perm -o+w -exec ls -l {} \;
echo -e "\n" 

} >> cronconfigs_info

{
echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" 
cat /etc/crontab 
echo -e "\n" 

echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]"  
ls -lta  /etc/xdg/autostart/* 2>/dev/null   
echo -e "\n" 

echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]"  
cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null   
echo -e "\n" 

echo "[Автозагрузка в GNOME и KDE]"  
more  /home/*/.config/autostart/*.desktop 2>/dev/null | cat  
echo -e "\n" 

echo "[Задачи из systemctl list-timers (предстоящие задачи)]" >> host_info
systemctl list-timers --all
echo -e "\n" 

# Список всех запущенных процессов, лучше класть в отдельный файлик
echo "[Список процессов (ROOT)]" 
ps -l 
echo -e "\n" 

} >> activity_info


{
# Гламурный вывод дерева процессов
echo "[Дерево процессов]" 
#pstree -Aup 
pstree -aups 2>/dev/null
echo -e "\n" 


# Текстовый вывод аналога виндового диспетчера задач
echo "[Инфа о процессах через top]" 
top -bcn1 -w512  
echo -e "\n" 

echo "[Список процессов (все)]" 
ps -auxw
#ps aux 
#ps -eaf
echo -e "\n" 

echo "[Список процессов (дерево)]" 
ps auxwf
echo -e "\n" 

} >> pstree_file


echo -e "${magenta}[Анализ активности]${clear}"
{
# Проверка почтовых правил - часто используется для скрытого мониторинга почты злоумышленниками
for usa in $(ls /home); do
# R7-office mail rules get
echo -e "[R7-organizer mail rules]"
more /home/$usa/.r7organizer/*.default-default/*Mail/*/*msgFilterRules.dat 2>/dev/null | cat
echo -e "\n" 
more /home/$usa/.r7organizer/*.default/*Mail/*/*msgFilterRules.dat 2>/dev/null| cat
echo -e "\n" 

# Get thunderbird extensions and rules
echo -e "[Thunderbird mail rules]"
more /home/$usa/.thunderbird/*.default-release/*Mail/*/msgFilterRules.dat 2>/dev/null | cat
echo -e "\n" 
more /home/$usa/.thunderbird/*.default/*Mail/*/msgFilterRules.dat 2>/dev/null| cat
echo -e "\n" 
done


echo "[Вывод задач в бэкграунде atjobs]" 
ls -lta /var/spool/cron/atjobs 2>/dev/null 
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

} >> activity_info 

{
echo "[Пользовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" 
more /etc/rc*/* 2>/dev/null | cat 
echo -e "\n" 
more /etc/rc.d/* 2>/dev/null | cat 
echo -e "\n" 
} >> rc_scripts

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
# systemctl list-unit-files
systemctl list-unit-files --type=service 
echo -e "\n" 

echo "[Статус работы всех служб (командой service)]"  
service --status-all 2>/dev/null 
echo -e "\n" 

# To list software from a terminal 
echo "[systemctl -a]" 
# systemctl --full --all
systemctl -a 2>/dev/null 
echo -e "\n" 


# Units
echo "[systemctl status]" 
systemctl status  2>/dev/null 
echo -e "\n" 


} >> services_info 

{

echo "[systemctl status]" 
echo "[systemctl units pathh for system]" 
systemd-analyze unit-paths  2>/dev/null 
echo -e "\n" 
echo "[systemctl units pathh for user]" 
systemd-analyze unit-paths --user 2>/dev/null 
echo -e "\n" 

echo "[Вывод конфигураций всех доступных сервисов]"  
more /etc/systemd/system/*.service | cat 
echo -e "\n" 
} >> services_configs

{
echo "[Список запускаемых сервисов (init)]"  
ls -lta /etc/init  2>/dev/null 
echo -e "\n" 

echo "[Сценарии запуска и остановки демонов (init.d)]"  
ls -lta /etc/init.d  2>/dev/null 
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

# printers check
echo "[Any printers?]"
lpstat -a 2>/dev/null #Printers info
echo -e "\n" 

echo "[Устройства USB (lsusb)]" 
lsusb 
echo -e "\n" 

echo "[Блочные устройства (lsblk)]" 
lsblk 2>/dev/null
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
ls -ltaR /var/lib/bluetooth/ 2>/dev/null 
echo -e "\n" 

} >> devices_info 

{

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
cat /var/log/syslog* 2>/dev/null | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 

echo "[Устройства USB из (log messages)]" 
cat /var/log/messages* 2>/dev/null | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null 
echo -e "\n" 

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

if [ -e "/etc/bashrc" ] ; then
    echo "[Содержимое из /etc/bashrc]" 
    cat /etc/bashrc 2>/dev/null 
    echo -e "\n" 
fi

if [ -e "/etc/bash.bashrc" ] ; then
    echo "[Содержимое из /etc/bash.bashrc]" 
    cat /etc/bash.bashrc 2>/dev/null 
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

echo "[Лимиты:]" 
# user limits
ulimit -a 

} >> users_cfgs

{

echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
# Список файлов, пример
#.*_profile (.profile)
#.*_login
#.*_logout
#.*rc
#.*history 
more /root/.* 2>/dev/null | cat 
echo -e "\n" 
} >> root_cfg

{

echo "[Пользователи SUDO]" 
cat /etc/sudoers 2>/dev/null 
echo -e "\n" 
more /etc/sudoers.d/* 2>/dev/null | cat
echo -e "\n" 

} >> env_profile_info

# <<< Заканчиваем писать файл env_profile_info
# ----------------------------------
# ----------------------------------


# ----------------------------------
# ----------------------------------
# Начинаем писать файл susp_chk >>>

echo -e "${cyan}[Анализ мест для закрепления]${clear}"
{
# Проверяем популярные места для закрепления и некоторые распространённые техники злодеев (кто-то скажет: коллеги)

# 1. Ключевые файлы для определения активности перенаправлены в /dev/null
# check HIGHLY suspicious /dev/null links
# used by attackers to disable logs and history
echo "[Check for /dev/null link set as critical files!]"
ls -lar /var/log/ 2>/dev/null | grep "/dev/null"
echo -e "\n" 
ls -lar /root/ 2>/dev/null | grep "/dev/null"
echo -e "\n" 
# history etc.
ls -lar /home/*/.* 2>/dev/null | grep "/dev/null"
echo -e "\n" 

# 1.1 Файлы пишут в /dev/null

echo "[Файлы с выводом в /dev/null]" 
lsof -w /dev/null 2>/dev/null
echo -e "\n" 


# 2. Ключевые файлы для определения активности больше не пишутся, так как находятся в Immutable режиме
# Inspired by https://forumsoc.ru/reports/file/73/
# check HIGHLY suspicious immutable bit set
# used by attackers to disable logs and history
echo "[Check for immutable bit set on critical files]"
lsattr -R /var/log/ 2>/dev/null | grep -- "-i-"
echo -e "\n" 
lsattr -R /root/ 2>/dev/null | grep -- "-i-"
echo -e "\n" 
# history etc.
lsattr -R /home/*/.* 2>/dev/null | grep -- "-i-"
echo -e "\n" 

# 3.  Потенциальное место для закрепления - запуск команд при подключении устройств
echo "[Device connection  scripts]"
more /etc/udev/rules.d/* 2>/dev/null | cat
echo -e "\n" 

# 4. Смотрим процессы, путь к исполняемым файлам которых скрыт, или само имя исполняемого файла скрыто, или используются аргументы со скрытымии фрагментами в path
# show processes with executable in HIDDEN location or with HIDDEN name:
echo "[SUSPICIOUS process started or named hidden, or with hidden path in args]"
ps ax -o pid,user,cmd | grep "/\."
echo -e "\n" 


# 5. Пытаемся выявить процессы, которые маскируются под потоки ядра
 # Suspucious imposters ~Linux Kernel Process Masquerading 
 # by https://sandflysecurity.com/blog/detecting-linux-kernel-process-masquerading-with-command-line-forensics/
 # ps auxww | grep \\[ | awk '{print $2}' | xargs -I % sh -c 'echo PID: %; cat /proc/%/maps' 2> /dev/null
 # Modifyed by me - shows PIDs, user and CMD, then uniq suspicious pathes of its:
 echo "[Suspicious map process pathes and their stats - to manual analysis:]" 
 #ps auxww | grep \\[ | awk '{print $1 " " $2 " " $11}' | xargs -I % sh -c 'echo % && echo $(echo % | cut -d " " -f 2 | xargs -I @ rev /proc/@/maps 2>/dev/null | cut -d " " -f1 | rev | sort | uniq) ' | sort | uniq
 ps auxww | grep \\[ | awk '{print $2}' | xargs -I % sh -c 'rev /proc/%/maps 2>/dev/null | cut -d " " -f1 | rev  | sort | uniq | xargs -0 --no-run-if-empty echo -e "$(ps -p % -o pid=,user=,cmd=)\n"' | sort | uniq
# realpath /proc/22429/exe
 echo -e "\n" 
 
# 6. Запущенные процессы с удалённым исполняемым файлом
# https://sandflysecurity.com/blog/how-to-recover-a-deleted-binary-from-active-linux-malware/
echo "[Processes with deleted executable]"  
find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
echo -e "\n" 

# 7. Processes runned from memory via memfd_create():
echo "[Processes runned from memory via memfd_create]" 
 ls -alR /proc/*/exe 2> /dev/null | grep memfd:.*\(deleted\)
echo -e "\n" 

# 8. Неудачные попытки входа - мб был брутик
if [ -e /var/log/btmp ]
	then 
	echo "[Last LOGIN fails: lastb]" 
	lastb 2>/dev/null 
	echo -e "\n" 
fi

 
} >> susp_chk

# <<< Заканчиваем писать файл susp_chk
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

# Вдруг в буфере что-то интересненькое))
# clipboard check by https://book.hacktricks.xyz/linux-hardening/privilege-escalation
echo "[Clibboard smth?]"
if [ `which xclip 2>/dev/null` ]; then
    echo "Clipboard: "`xclip -o -selection clipboard 2>/dev/null`
    echo "Highlighted text: "`xclip -o 2>/dev/null`
  elif [ `which xsel 2>/dev/null` ]; then
    echo "Clipboard: "`xsel -ob 2>/dev/null`
    echo "Highlighted text: "`xsel -o 2>/dev/null`
  else echo "No applicable clipboard =(. Not found xsel and xclip"
  fi
 echo -e "\n"  


# inter-process communication status (active message queues, semaphore sets, shared memory segments)
echo "[Inter-proc communication stats"
ipcs -a  2>/dev/null
echo -e "\n" 

# Проверимся на руткиты, иногда помогает
echo "[Проверка на rootkits командой chkrootkit]" 
chkrootkit 2>/dev/null 
echo -e "\n" 


# systemd dumps listing
echo "[Перечень крашдампов]" 
coredumpctl list  2>/dev/null
echo -e "\n" 
ls -la /var/lib/systemd/coredump
echo -e "\n" 


# OS specific

if [ -f /sys/digsig/elf_mode ]; then
	# Astra Linux Closed Software Environment mode
	echo "[AstraLinux - protected software mode]" 
	cat /sys/digsig/elf_mode 2>/dev/null
	echo -e "\n" 
	cat /sys/digsig/xattr_mode 2>/dev/null
	echo -e "\n" 
fi


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
echo "[PRIVILEGE passwd - all users /etc/passwd]]" 
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
echo "[SSH-files for: $name]"
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
echo "[Loaded core modules - lsmod]" 
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
echo "[Currently open files: lsof -n]" 
lsof -n 2>/dev/null
echo -e "\n" 

echo "[Verbose open files: lsof -V ]"  #open ports
lsof -V  2>/dev/null
# lsof 
echo -e "\n" 
} >> lsof_file

{
echo "[Query journal: journalctl]"  
# super errors mode:
# journalctl -o verbose -p 4 
journalctl 
##journalctl -o export > journal-exp.txt
echo -e "\n" 
} >> journalctlq

{

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


echo "[Repo info: cat /etc/apt/sources.list and subconfigs]"  
#cat /etc/apt/sources.list 
more /etc/apt/sources.list* 2>/dev/null | cat 
echo -e "\n" 
more /etc/apt/sources.list*/* 2>/dev/null | cat 
echo -e "\n" 

echo "[Static file system info: cat /etc/fstab]"  
cat /etc/fstab 2>/dev/null 
echo -e "\n" 

# echo "Begin Additional Sequence Now *********************************"

# Vurtual memory statistics
echo "[Virtual memory state: vmstat]"  
vmstat 
echo -e "\n" 
echo "[Virtual memory state: vmstat disks]"  
# disk statistics
vmstat -D  2>/dev/null
echo -e "\n" 
echo "[Virtual memory state: vmstat memory]"  
# memory statistics
vmstat -s 2>/dev/null
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
cat /var/log/messages 2>/dev/null | grep -i usb 2>/dev/null 
echo -e "\n" 

# List all mounted files and drives
echo "[List all mounted files and drives: ls -lat /mnt]"  
ls -lat /mnt 
echo -e "\n" 

echo "[Logind  config]"
# systemd configuration options
cat  /etc/systemd/logind.conf 2>/dev/null
echo -e "\n" 

# System config info junk
cat /etc/mtab 2>/dev/null 
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

echo "[Memory free]"  
free -h
echo -e "\n" 

echo "[Hardware: lshw]"  
lshw 2>/dev/null 
echo -e "\n" 

echo "[Hardware info: cat /proc/(cpuinfo|meminfo), lscpu]"  
cat /proc/cpuinfo 
echo -e "\n" 
lscpu 2>/dev/null
echo -e "\n" 
cat /proc/meminfo 
echo -e "\n" 


echo "[Profile parameters: cat /etc/profile.d/*]"  
more /etc/profile.d/* 2>/dev/null | cat
echo -e "\n" 

echo "[Language locale]"  
locale  2>/dev/null 
echo -e "\n" 

#manual installed
echo "[Get manually installed packages apt-mark showmanual (TOP)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 


#echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]"  
#aptitude search '!~M ~i'
#aptitude search -F %p '~i!~M'

mkdir -p ./artifacts/config_root
#desktop icons and other_stuff
cp -r /root/.config ./artifacts/config_root 2>/dev/null 
#saved desktop sessions of users
cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

echo "[VMware clipboard (root)!]" 
ls -ltaR /root/.cache/vmware/drag_and_drop/ 2>/dev/null 
echo -e "\n" 

echo "[Mails of root]" 
# alt: ls -l /var/mail/root 2>/dev/null
cat /var/mail/root 2>/dev/null 
echo -e "\n" 
echo "[Spool mails]" 
# add mail check
cat /var/spool/mail/* 2>/dev/null 
echo -e "\n" 


#cp -R ~/.config/ 2>/dev/null 

#recent 
echo "[Recently-Used]"  
more  /home/*/.local/share/recently-used.xbel 2>/dev/null | cat 
echo -e "\n"  

#get mail for each user:
#echo "[Recently-Used]"  
#cat /var/mail/username$ 2>/dev/null 

#mini list of apps
echo "[Var-LIBS directories - like program list]"  
ls -lta /var/lib 2>/dev/null  
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

#GPG info
echo "[GnuPG contains:]"  
ls -ltaR /home/*/.gnupg/* 2>/dev/null  
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

{
echo "[kernel messages: dmesg]" 
# as table
dmesg -T 2>/dev/null 
echo -e "\n" 
} >> dmesg

echo -e "${yellow}[Сбор информации о службах...]${clear}" 
{
echo "[/sbin/sysctl -a (core parameters list)]"  
/sbin/sysctl -a 2>/dev/null 
echo -e "\n" 


# Modules
echo "[Modules listing]" 
find /lib/modules -printf "%M\t%u\t%g\t%s\t%AY-%Am-%Ad-%AH:%AM\t%CY-%Cm-%Cd-%CH:%CM\t%TY-%Tm-%Td-%TH:%TM\t%P\n" 
echo -e "\n" 

} >> kernel_params

#COPY ALL WEB PROFILES FOR THE GOD!
echo -e "${magenta}[Web collection]${clear}"
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

#echo "Get users Recent and personalize collection"
echo -e "${yellow}[Сбор информации о конфигурации пользователей...]${clear}" 
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
	# alt: for x in "/var/mail"; do ls -lh "$x"; done
	cat /var/mail/$usa 2>/dev/null 
	echo -e "\n" 

	echo "[VMware clipboard (maybe)!]" 
	ls -ltaR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
	echo -e "\n" 
	

	
	} >> junk_info
done


{
# Check for misonfiguration from Cheatsheet
echo "[Popular config check]"
# samba
cat /etc/samba/smb.conf 2>/dev/null
echo -e "\n" 
# Samba config
testparm -s 2>/dev/null
echo -e "\n" 

cat /etc/chttp.conf 2>/dev/null
echo -e "\n" 
cat /etc/lighttpd.conf 2>/dev/null
echo -e "\n" 
cat /etc/cups/cupsd.conf  2>/dev/null
echo -e "\n" 
cat /etc/inetd.conf 2>/dev/null
echo -e "\n" 
cat /etc/apache2/apache2.conf 2>/dev/null
echo -e "\n" 
cat /etc/my.conf 2>/dev/null
echo -e "\n" 
cat /etc/httpd/conf/httpd.conf 2>/dev/null
echo -e "\n" 
cat /opt/lampp/etc/httpd.conf 2>/dev/null
echo -e "\n" 

cat /opt/lampp/etc/httpd.conf 2>/dev/null
echo -e "\n" 
# get sendmail configuration files
more /etc/mail/* 2>/dev/null | cat
echo -e "\n" 

# get exim configuration files
more /etc/exim4/* 2>/dev/null | cat
echo -e "\n" 

# get postfix configuration files
cat /etc/postfix/*.cf 2>/dev/null
echo -e "\n" 


# NOT incldable checks by kaspers'ky
# get listing of system directories
#ls -la / /tmp /opt /var /etc /usr 2>/dev/null
# get listing of system libs
#ls -la / /usr | grep lib 2>/dev/null
#ls -laL /lib*  2>/dev/null
#ls -laL /usr/lib* 2>/dev/null


#analyze ssl certs and keys
echo "[SSL files:]"  
ls -ltaR /etc/ssl    2>/dev/null  
echo -e "\n" 



} >> junk_info

# <<< Заканчиваем писать файл junk_info
# ----------------------------------
# ----------------------------------


# ----------------------------------
# ----------------------------------
# Начинаем писать файл junk_k_info >>>
echo -e "${yellow}[Сбор потенциальных конфигураций для закрепления...]${clear}" 
{
# kasper best practices
# Antimalware report
# System autorun
echo "[X11 files:]" 
cat /etc/X11/xinit/xinitrc 2>/dev/null
echo -e "\n" 
cat /etc/X11/xinit/xserverrc 2>/dev/null
echo -e "\n" 
echo "[Anacrontab:]" 
cat /etc/anacrontab 2>/dev/null
echo -e "\n" 
echo "[Bash files:]" 
cat /etc/bash.bash_logout 2>/dev/null
echo -e "\n" 
cat /etc/bash.bashrc 2>/dev/null
echo -e "\n" 
cat /etc/bash.bashrc 2>/dev/null
echo -e "\n" 
echo "[incron files:]" 
more /etc/incron.d/* 2>/dev/null | cat
echo -e "\n" 
echo "[init files:]" 
more /etc/init.d/* 2>/dev/null | cat
echo -e "\n" 
cat /etc/inittab 2>/dev/null
echo -e "\n" 
echo "[ld.so files:]" 
cat /etc/ld.so.conf 2>/dev/null
echo -e "\n" 
more /etc/ld.so.conf.d/* 2>/dev/null | cat
echo -e "\n" 
cat /etc/ld.so.preload 2>/dev/null
echo -e "\n" 
echo "[modules files:]" 
cat /etc/modules 2>/dev/null
echo -e "\n" 
more /etc/modules-load.d/* 2>/dev/null | cat
echo -e "\n" 
echo "[Profile files:]" 
cat /etc/profile 2>/dev/null
echo -e "\n" 
more /etc/profile.d/* 2>/dev/null
echo -e "\n" 
echo "[RC files:]" 
cat /etc/rc.boot 2>/dev/null
echo -e "\n" 
cat /etc/rc.local 2>/dev/null
echo -e "\n" 
echo "[Systemd files:]" 
more /etc/systemd/system/* 2>/dev/null | cat
echo -e "\n" 
cat /etc/systemd/system.conf 2>/dev/null
echo -e "\n" 
more /lib/systemd/system/* 2>/dev/null | cat
echo -e "\n" 
echo "[Udev files:]" 
more /etc/udev/rules.d/* 2>/dev/null | cat
echo -e "\n" 
echo "[Update files:]" 
more /etc/update-motd.d/* 2>/dev/null | cat
echo -e "\n" 
more /etc/update.d/* 2>/dev/null | cat
echo -e "\n" 
echo "[XDG files:]" 
more /etc/xdg/autostart/* 2>/dev/null | cat
echo -e "\n" 
cat /etc/xdg/lxsession/LXDE/autostart 2>/dev/null
echo -e "\n" 
echo "[VAR files:]" 
more /var/run/motd.d/* 2>/dev/null | cat
echo -e "\n" 
more /var/spool/anacron/* 2>/dev/null | cat
echo -e "\n" 
cat /var/spool/cron/atjobs 2>/dev/null
echo -e "\n" 
more /var/spool/cron/crontabs/* 2>/dev/null | cat
echo -e "\n" 
more /var/spool/incron/* 2>/dev/null | cat
echo -e "\n" 
} >> junk_k_info

# <<< Заканчиваем писать файл junk_k_info
# ----------------------------------
# ----------------------------------

#! - конец для записи основных текстовых файлов

# ----------------------------------
# ----------------------------------

# Архивируем собранные артефакты

echo -e "${yellow}[Packing artifacts...]${clear}"
tar --remove-files -zc -f ./artifacts.tar.gz artifacts 2>/dev/null
# additional clearing for artifacts folder
rm -rf artifacts 2>/dev/null

#! облегчим себе задачу в будушем, и добавим запись таймстампов во все файлы history
if [[ "$set_history" -gt 0 ]]; then
echo "${yellow}[Change HISTTIMEFORMAT to world-best value IMHO]${clear}"
echo "CURRENT HISTTIMEFORMAT: $HISTTIMEFORMAT"
# format:
# seq. number | unix epoch | dd-mm-YYYY | HH:MM:SS | Zone <space>
# 191  1715338321 10-05-2024 13:52:01 MSK history
hist_format="[%s %d-%m-%Y %H:%M:%S %Z] "

#! alt. locations are: ~/.bash_profile, ~/.bashrc ... 
hist_persist="/etc/profile"
if $(grep -q "^HISTTIMEFORMAT=" $hist_persist); then
sed -i "s/^HISTTIMEFORMAT=.*/HISTTIMEFORMAT=\"$hist_format\"/" $hist_persist;
else
sed "$ a\HISTTIMEFORMAT=\"$hist_format\"" -i $hist_persist
fi
echo "Changed HISTTIMEFORMAT to <$hist_format> in $hist_persist !"
fi

{  
echo -e "\n" 
echo "Завершили сбор данных!" 
date 
echo -e "\n" 
} >> host_info



 } |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log) # Наш лог-файл, фильтруем цветовые формантанты
 
 
# Завершающая часть после выполнения необходимых команд
# Для выходной директории даем права всем на чтение и удаление

echo -e "${blue}[Формируем архив...]${clear}"
cd ..
tar czf "$saveto.tar.gz" $saveto/

if [ -f "$saveto.tar.gz" ]; then
	echo -n "packed size: "
	du -sh "$saveto.tar.gz" | awk '{print $1}'
	
	echo -e "${cyan}[Clearance (temp files)...]${clear}"
	rm -rf  $saveto

else
echo "Some arhive error! See dir $saveto!"

fi

chmod -R ugo+rwx "./$saveto.tar.gz"
 
 end=`date +%s`
 echo -e "\n" 
 echo "ENDED! Execution time was $(expr $end - $start) seconds."
 #echo -e "${magenta}Проверяй директорию ${saveto}! ${clear}"
 echo -e "${magenta}Забирай файл $saveto.tar.gz! ${clear}"
 echo -e "${red}Не забудь удалить меня, ifrit.sh !! ${clear}"
 pathe=$(readlink -f $saveto.tar.gz)
 echo -e "${yellow}Полный путь: ${pathe}! ${clear}"
# Открываем директорию в файловом менеджере — работает не во всех дистрибутивах. В Astra также можно использовать команду fly-fm
# xdg-open .
# лучше графон открывать не от рута, а от текущего юзера:
# namer=$(logname)
# sudo -u $namer xdg-open .
# однако без sudo или при работе в терминале, оставь так или убери вообще:
# xdg-open . 2>/dev/null
# новый вариант:
#! Если работаете только в терминале - можно убрать
if (( $EUID != 0 )); then
# Not root - execute GUI to open folder
xdg-open . 2>/dev/null &
else
# decrease privs and open as current user
sudo -u $(logname) xdg-open . 2>/dev/null  &
fi  

# } |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log) # Наш лог-файл, фильтруем цветовые формантанты
 

# Справочно: список выводимых файлов:
	#activity_info - пользовательская активность
	#apps_file - приложения, история 
	#console_log - лог работы скрипта
	#cronconfigs_info - запланированные задачи
	#devices_info - инфа по железу
	#env_profile_info - инфа по конфигам профиля
	#history_info - ключевые действия на хосте 
	#host_info - основной файл с базовой информацией о хосте
	#ioc_word_info - список файлов и строк из них, где встречаются искомые термины
	#IP-search_info - файл с результатами грепа IP-адресов в файлах
	#junk_info - мегомусорный файл с результатами выполнения всех команд, которые были пожеланы быть выполнеными
	#lsof_file - файл для хранения вывода lsof
	#network_add_info - результаты грепа логов (сетевые артефакты)
	#network_info - инфа по сетевым конфигам
	#pstree_file - гламурный вывод дерева процессов
	#root_cfg - текстовка конфигураций профиля рута
	#services_configs - конфиги всех служб
	#services_info - инфа по службам
	#usb_list_file - история подключения USB-носителей
	#users_files - инфа по пользовательским файлам, мини-листинг файловой системы
	#users_files_timeline - священный таймлайн изменения файлов в пользовательских каталогах
	#users_cfgs - текстовка конфигураций профилей пользователей
	#virt_apps_file - инфа по виртуалкам или вайнам, альтернативным ОС в системе
	#secur_cfg - проверка некоторых конфигов по безопасности (аудит, отправка логов, SELinux, AppArmor)
	#susp_chk - проверка на некоторые очень подозрительные техники атакующих в системе
	#junk_k_info - выгрузки конфигов на популярные места для закрепления от популярного ИБ-вендора
	#dmesg - вывод dmesg
	#kernel_params - параметры ядра и модули
	#rc_scripts - листинг скриптов из автозаруска в /etc/rc*
	#journalctlq - выгрузка journalctl
