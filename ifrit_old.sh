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
echo "build 10.05.2023"

# Разрешим скрипту продолжать выполняться с ошибками. Это необязательно, для острастки
set +e

# Фиксируем текущую дату
start=$(date +%s)

# Проверка, что мы root
echo "Текущий пользователь:"
echo $(id -u -n)

# «Без root будет бедная форензика»
if (( $EUID != 0 )); then
    echo "Пользователь не root"
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
	
{
# ----------------------------------
# ----------------------------------
# СБОР ДАННЫХ О ХОСТЕ

# Начинаем писать файл host_info >>>
echo -n > host_info
echo "[Сбор информации по хосту]" 
echo "[Текущий хост и время]" >> host_info 
echo "Текущая дата и системное время:" >> host_info 
date >> host_info
echo -e "\n" >> host_info

echo "[Имя хоста:]" >> host_info 
hostname >> host_info
echo -e "\n" >> host_info

# Сведения о релизе ОС, например из файла os-release
# Аналоги: cat /usr/lib/os-release или lsb_release
echo "[Доп информация о системе из etc/*(-release|_version)]" >> host_info
cat /etc/*release >> host_info
cat /etc/*version  >> host_info
echo -e "\n" >> host_info

echo "[Доп информация о системе из /etc/issue]" >> host_info
cat /etc/issue >> host_info
echo -e "\n" >> host_info

echo "[Идентификатор хоста (hostid)]" >> host_info
hostid >> host_info
echo -e "\n" >> host_info

echo "[Информация из hostnamectl]" >> host_info
hostnamectl >> host_info
echo -e "\n" >> host_info

echo "[IP адрес(а):]" >> host_info 
ip addr >> host_info # Информация о текущем IP-адресе
echo -e "\n" >> host_info

echo "[Информация о системе]" >> host_info
uname -a >> host_info
echo -e "\n" >> host_info

echo "[Текущий пользователь:]" >> host_info 
# whoami
who am i >> host_info
echo -e "\n" >> host_info

echo "[Информация об учетных записях и группах]" >> host_info
for name in $(ls /home); do
    id $name >> host_info
done
echo -e "\n" >> host_info

echo "[Информация об учетных записях из getent (Astra)]" >> host_info
if  uname -a | grep astra; then
    eval getent passwd {$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)..$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)} | cut -d: -f1 >> host_info
    echo -e "\n" >> host_info
fi

# Получим список живых пользователей. Зачастую мы хотим просто посмотреть реальных пользователей, у которых есть каталоги, чтобы в них порыться. Запишем имена в переменную для последующей эксплуатации
echo "Пользователи с /home/:" 
echo "[Пользователи с /home/:]"  >> host_info
ls /home >> host_info
# Исключаем папку lost+found
users=`ls /home -I lost*`
echo $users
echo -e "\n" >> host_info

echo "[Залогиненные юзеры:" >> host_info
w >> host_info
echo -e "\n" >> host_info

# <<< Заканчиваем писать файл host_info
# ----------------------------------
# ----------------------------------

# Раскомментируй следующую строчку, чтобы сделать паузу и что-нибудь скушать. Затем нажми Enter, чтобы продолжить
# read -p "Press [Enter] key to continue fetch..."
# Пользовательские файлы

# ----------------------------------
# ----------------------------------
# Начинаем писать файл users_files >>>

echo "[Пользовательские файлы]"

echo "[Пользовательские файлы из (Downloads,Documents, Desktop)]" >> users_files
ls -la /home/*/Downloads 2>/dev/null >> users_files
echo -e "\n" >> users_files
ls -la /home/*/Загрузки 2>/dev/null >> users_files
echo -e "\n" >> users_files
ls -la /home/*/Documents 2>/dev/null >> users_files
echo -e "\n" >> users_files
ls -la /home/*/Документы 2>/dev/null >> users_files
echo -e "\n" >> users_files
ls -la /home/*/Desktop/ 2>/dev/null
echo -e "\n" >> users_files
ls -la /home/*/Рабочий\ стол/ 2>/dev/null
echo -e "\n" >> users_files

# Составляем список файлов в корзине
echo "[Файлы в корзине из home]" >> users_files
ls -laR /home/*/.local/share/Trash/files 2>/dev/null >> users_files
echo -e "\n" >> users_files

# Для рута тоже на всякий случай
echo "[Файлы в корзине из root]" >> users_files
ls -laR /root/.local/share/Trash/files 2>/dev/null >> users_files
echo -e "\n" >> users_files

# Кешированные изображения могут помочь понять, какие программы использовались
echo "[Кешированные изображения программ из home]" >> users_files
ls -la /home/*/.thumbnails/ 2>/dev/null >> users_files
echo -e "\n" >> users_files

# Ищем в домашних пользовательских папках
#! grep -A2 -B2 -rn 'терменвокс' --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info

#! echo "[Поиск интересных файловых расширений в папках home и root:]" >> users_files
#! find /root /home -type f -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml 2>/dev/null >> users_files
#! echo -e "\n" >> users_files

echo "[Таймлайн файлов в домашних каталогах (CSV)]"
echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" >> users_files_timeline
echo -n >> users_files_timeline
find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null >> users_files_timeline

# <<< Заканчиваем писать файл users_files
# ----------------------------------
# ----------------------------------

# Приложения

# ----------------------------------
# ----------------------------------
# Начинаем писать файл apps_file >>>

echo "[Приложения в системе]"

echo "[Проверка браузеров]" >> apps_file
# Firefox, артефакты: ~/.mozilla/firefox/*, ~/.mozilla/firefox/* и ~/.cache/mozilla/firefox/*
firefox --version 2>/dev/null >> apps_file
# Firefox, альтернативная проверка
dpkg -l | grep firefox >> apps_file
# Thunderbird. Можно при успехе просмотреть содержимое каталога командой ls -la ~/.thunderbird/*, поискать календарь, сохраненную переписку
thunderbird --version 2>/dev/null >> apps_file
# Chromium. Артефакты:  ~/.config/chromium/*
chromium --version 2>/dev/null >> apps_file
# Google Chrome. Артефакты можно брать из ~/.cache/google-chrome/* и ~/.cache/chrome-remote-desktop/chrome-profile/
chrome --version 2>/dev/null >> apps_file
# Opera. Артефакты ~/.config/opera/*
opera --version 2>/dev/null >> apps_file
# Brave. Артефакты: ~/.config/BraveSoftware/Brave-Browser/*
brave --version 2>/dev/null >> apps_file
# Бета Яндекс-браузера для Linux. Артефакты: ~/.config/yandex-browser-beta/*
yandex-browser-beta --version 2>/dev/null >> apps_file
echo -e "\n" >> apps_file

# Мессенджеры и Ко
echo "[Проверка мессенджеров и других приложений]" >> apps_file
signal-desktop --version 2>/dev/null >> apps_file
viber --version 2>/dev/null >> apps_file
whatsapp-desktop --version 2>/dev/null >> apps_file
tdesktop --version 2>/dev/null >> apps_file
# Также можно проверить каталог: ls -la ~/.zoom/*
zoom --version 2>/dev/null >> apps_file
# Можешь проверить и каталог: ls -la ~/.steam
steam --version 2>/dev/null >> apps_file
discord --version 2>/dev/null >> apps_file
dropbox --version 2>/dev/null >> apps_file
yandex-disk --version 2>/dev/null >> apps_file
echo -e "\n" >> apps_file

echo "[Сохранение профилей популярных браузеров в папку ./artifacts]"
echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" >> apps_file
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
mkdir -p ./artifacts/gchrome
cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
mkdir -p ./artifacts/chromium
cp -r /home/*/.config/chromium ./artifacts/chromium

echo "[Проверка приложений торрента]" >> apps_file 
apt list --installed | grep torrent 2>/dev/null >> apps_file
echo -e "\n" >> apps_file

echo "[Все пакеты, установленные в системе]" >> apps_file 
# Список всех установленных пакетов APT; также попробуй dpkg -l
apt list --installed 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
# Следующая команда позволяет получить список пакетов, установленных вручную
echo "[Все пакеты, установленные в системе (вручную)]" >> apps_file 
apt-mark showmanual 2>/dev/null >> apps_file
echo -e "\n" >> apps_file

echo "[Все пакеты, установленные в системе (вручную, вар. 2)]" >> apps_file 
apt list --manual-installed | grep -F \[installed\] 2>/dev/null >> apps_file
echo -e "\n" >> apps_file

# Как вариант, можешь написать aptitude search '!~M ~i' или aptitude search -F %p '~i!~M'
# Для openSUSE, ALT, Mandriva, Fedora, Red Hat, CentOS
rpm -qa --qf "(%{INSTALLTIME:date}): %{NAME}-%{VERSION}\n" 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
# Для Fedora, Red Hat, CentOS
yum list installed 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
# Для Fedora
dnf list installed 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
# Для Arch
pacman -Q 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
# Для openSUSE
zypper info 2>/dev/null >> apps_file
echo -e "\n" >> apps_file
echo -e "\n" >> apps_file

# <<< Заканчиваем писать файл apps_file
# ----------------------------------
# ----------------------------------

# Проверка виртуальных извратов и альтернатив мест залегания

# ----------------------------------
# ----------------------------------
# Начинаем писать файл virt_apps_file >>>

echo "[Приложения виртуализации или эмуляции в системе и проверка GRUB]"
echo "[Проверка приложения Virtualbox]" >> virt_apps_file 
apt list --installed  | grep virtualbox 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

echo "[Проверка приложения KVM]" >> virt_apps_file 
cat ~/.cache/libvirt/qemu/log/* 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

# А вот так можем посмотреть логи QEMU, в том числе и об активности виртуальных машин
echo "[Проверка логов QEMU]" >> virt_apps_file 
cat /home/*/.cache/libvirt/qemu/log/* 2>/dev/null
echo -e "\n" >> virt_apps_file

echo "[Проверка приложений Wine]" >> virt_apps_file 
winetricks list-installed 2>/dev/null >> virt_apps_file
winetricks settings list 2>/dev/null >> virt_apps_file
ls -la /home/*/.wine/drive_c/program_files 2>/dev/null >> virt_apps_file
ls -la /home/*/.wine/drive_c/Program 2>/dev/null >> virt_apps_file
ls -la /home/*/.wine/drive_c/Program\ Files/ 2>/dev/null >> virt_apps_file
ls -la /home/*/.wine/drive_c/Program/ 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

echo "[Проверка приложений контейнеризации]" >> virt_apps_file
# Артефакты Docker: /var/lib/docker/containers/*/
docker --version 2>/dev/null >> virt_apps_file
# Артефакты containerd : /etc/containerd/* и /var/lib/containerd/
containerd --version 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

echo "[Вывод содержимого загрузочного меню, то есть список ОС (GRUB)]" >> virt_apps_file 
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

echo "[Конфиг файл GRUB]" >> virt_apps_file 
cat /boot/grub/grub.cfg 2>/dev/null >> virt_apps_file
echo -e "\n" >> virt_apps_file

echo "[Проверка на наличие загрузочных ОС]" >> virt_apps_file 
os-prober  >> virt_apps_file
echo -e "\n" >> virt_apps_file

# <<< Заканчиваем писать файл virt_apps_file
# ----------------------------------
# ----------------------------------

# Активность в ретроспективе

# ----------------------------------
# ----------------------------------
# Начинаем писать файл history_info >>>

echo "[Историческая информация]"

# Текущее время работы системы, количество залогиненных пользователей, средняя загрузка системы за 1, 5 и 15 мин
echo "[Время работы системы, количество залогиненных пользователей]" >> history_info 
uptime >> history_info
echo -e "\n" >> history_info

echo "[Журнал перезагрузок (last -x reboot)]" >> history_info 
last -x reboot >> history_info
echo -e "\n" >> history_info

echo "[Журнал выключений (last -x shutdown)]" >> history_info 
last -x shutdown >> history_info
echo -e "\n" >> history_info

# Список последних входов в систему с указанием даты (/var/log/lastlog)
echo "[Список последних входов в систему (/var/log/lastlog)]" >> history_info
lastlog >> history_info
echo -e "\n" >> history_info

# Список последних залогиненных юзеров (/var/log/wtmp), их сессий, ребутов и включений и выключений
echo "[Список последних залогиненных юзеров с деталями (/var/log/wtmp)]" >> history_info
last -Faiwx >> history_info
echo -e "\n" >> history_info

echo "[Последние команды из fc текущего пользователя]" >> history_info
fc -li 1 2>/dev/null >> history_info
# history -a
echo -e "\n" >> history_info
# Аналог команды history, выводит список последних команд, выполненных текущим пользователем в терминале
fc -l 1 >> history_info
echo -e "\n" >> history_info

if ls /root/.*_history >/dev/null 2>&1; then
    echo "[История пользоватея Root (/root/.*history)]" >> history_info
    cat /root/.*history >> history_info
	echo -e "\n" >> history_info
fi

for name in $(ls /home); do
	# Здесь же можно использовать и нашу переменную $users (но я не захотел)
    echo "[История пользоватея ${name} (.*history)]" >> history_info
    cat /home/$name/.*history >> history_info    
    echo -e "\n" >> history_info
	echo "[История команд Python пользоватея ${name}]" >> history_info
	cat /home/$name/.python_history 2>/dev/null >> history_info
	echo -e "\n" >> history_info
done

# История установки пакетов. Также можно грепать в файлах /var/log/dpkg.log*, например
echo "[История установленных приложений из /var/log/dpkg.log]" >> history_info 
grep "install " /var/log/dpkg.log >> history_info
echo -e "\n" >> history_info

# История установки пакетов в архивных логах. Для поиска во всех заархивированных системных логах исправь dpkg.log на *
echo "[Архив истории установленных приложений из /var/log/dpkg.log.gz ]" >> history_info 
zcat /var/log/dpkg.log.gz | grep "install " >> history_info
echo -e "\n" >> history_info

echo "[История обновленных приложений из /var/log/dpkg.log]" >> history_info 
grep "upgrade " /var/log/dpkg.log >> history_info
echo -e "\n" >> history_info

echo "[История удаленных приложений из /var/log/dpkg.log]" >> history_info 
grep "remove " /var/log/dpkg.log >> history_info
echo -e "\n" >> history_info

echo "[История о последних apt-действиях (history.log)]" >> history_info 
cat /var/log/apt/history.log >> history_info
echo -e "\n" >> history_info

# Доп файлы, которые мб имеет смысл посмотреть
#/var/log/dpkg.log*;
#/var/log/apt/history.log*;
#/var/log/apt/term.log*;
#/var/lib/dpkg/status.

# <<< Заканчиваем писать файл history_info
# ----------------------------------
# ----------------------------------

# Сетевичок (сетевая часть)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл network_info >>>

echo "[Проверка сетевой информации]"

# Информация о сетевых адаптерах. Аналоги: ip l и ifconfig -a
echo "[IP адрес(а):]" >> network_info 
ip a >> network_info
echo -e "\n" >> network_info

echo "[Настройки сети]" >> network_info
ifconfig -a 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Сетевые интерфейсы (конфиги)]" >> network_info
cat /etc/network/interfaces >> network_info
echo -e "\n" >> network_info

echo "[Настройки DNS]" >> network_info
cat /etc/resolv.conf >> network_info
cat /etc/host.conf    2>/dev/null >> network_info 
echo -e "\n" >> network_info

echo "[Сетевой менеджер (nmcli)]" >> network_info
nmcli >> network_info
echo -e "\n" >> network_info

echo "[Беспроводные сети (iwconfig)]" >> network_info
iwconfig 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Информация из hosts (local DNS)]" >> network_info
cat /etc/hosts >> network_info
echo -e "\n" >> network_info

echo "[Сетевое имя машины (hostname)]" >> network_info
cat /etc/hostname >> network_info
echo -e "\n" >> network_info

echo "[Сохраненные VPN ключи]" >> network_info
ip xfrm state list >> network_info
echo -e "\n" >> network_info

echo "[ARP таблица]" >> network_info
arp -e 2>/dev/null >> network_info
# ip n 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Таблица маршрутизации]" >> network_info
ip r 2>/dev/null >> network_info
# route 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Проверка настроенных прокси]" >> network_info
echo "$http_proxy" >> network_info
echo -e "\n" >> network_info
echo "$https_proxy">> network_info
echo -e "\n" >> network_info
env | grep proxy >> network_info
echo -e "\n" >> network_info

echo "[Проверяем наличие интернета и внешнего IP-адреса]" >> network_info
wget -T 2 -O- https://api.ipify.org 2>/dev/null | tee -a network_info
# Аналог:
curl ifconfig.co >> network_info # https://xakep.ru/2016/09/08/19-shell-scripts/ 
echo -e "\n" >> network_info

# База аренд DHCP-сервера (файлы dhcpd.leases). Гламурный аналог — утилита dhcp-lease-list
echo "[Проверяем информацию из DHCP]" >> network_info
cat /var/lib/dhcp/* 2>/dev/null >> network_info
# Основные конфиги DHCP-сервера (можно сразу убрать из вывода все строки, начинающиеся с комментариев, и посмотреть именно актуальный конфиг, если тебе это надо, конечно)
cat /etc/dhcp/* | grep -vE ^ 2>/dev/null >> network_info
# В логах смотрим инфу о назначенном адресе по DHCP
journalctl |  grep  " lease" >> network_info
# При установленном NetworkManager
journalctl |  grep  "DHCP" >> network_info
echo -e "\n" >> network_info
# Информация о DHCP-действиях на хосте
journalctl | grep -i dhcpd >> network_info
echo -e "\n" >> network_info

echo "[Сетевые процессы и сокеты с адресами]" >> network_info
# Активные сетевые процессы и сокеты с адресами. Эти же ключи сработают для утилиты ss ниже
netstat -anp 2>/dev/null >> network_info
#netstat -anoptu
#netstat -rn
# Актуальная альтернатива netstat, выводит имена процессов (если запуск от суперпользователя) с текущими TCP/UDP-соединениями
ss -tupln 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Количество сетевых полуоткрытых соединений]" >> network_info
#netstat -tan | grep -i syn | wc -с
netstat -tan | grep -с -i syn 2>/dev/null >> network_info
echo -e "\n" >> network_info

echo "[Сетевые соединения (lsof -i)]" >> network_info
lsof -i >> network_info
echo -e "\n" >> network_info

# Незамысловатый карвинг из логов сетевых соединений
echo "[Network connections list - connection]" >> network_add_info
journalctl -u NetworkManager | grep -i "connection '" >> network_add_info
echo -e "\n" >> network_add_info
echo "[Network connections list - addresses]" >> network_add_info
journalctl -u NetworkManager | grep -i "address" >> network_add_info # адресов

echo -e "\n" >> network_add_info
echo "[Network connections wifi enabling]" >> network_add_info
journalctl -u NetworkManager | grep -i wi-fi >> network_add_info # подключений-отключений Wi-Fi
echo -e "\n" >> network_add_info

echo "[Network connections internet]" >> network_add_info
journalctl -u NetworkManager | grep -i global -A2 -B2 >> network_add_info # подключений к интернету
echo -e "\n" >> network_add_info

# Сети Wi-Fi, к которым подключались
echo "[wifi networks info]" >> network_add_info 
grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null >> network_add_info
echo -e "\n" >> network_add_info
# Альтернатива
cat /etc/NetworkManager/system-connections/* 2>/dev/null >> network_add_info
echo -e "\n" >> network_add_info

# collect "iptables" information
echo "[Firewall configuration iptables-save]" >> network_add_info 
iptables-save 2>/dev/null >> network_add_info
echo -e "\n" >> network_add_info
iptables -n -L -v --line-numbers >> network_add_info
echo -e "\n" >> network_add_info

# Список правил файрвола nftables
echo "[Firewall configuration nftables]" >> network_add_info 
nft list ruleset >> network_add_info
echo -e "\n" >> network_add_info

# Ищем IP-адреса в логах и выводим список
#! journalctl | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]| sudo [01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' | sort |uniq
#! grep -r -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' /var/log | sort | uniq

# Ищем айпишник среди данных приложений
#! grep -A2 -B2 -rn '66.66.55.42' --exclude="*ifrit.sh" --exclude-dir=$saveto /usr /etc  2>/dev/null >> IP_search_info

# Ищем логи приложений (но не в /var/log)
#! find /root /home /bin /etc /lib64 /opt /run /usr -type f -name \*log* 2>/dev/null >> int_files_info

# Ищем в жомашнем каталоге файлы с изменениями (созданием) в определённый временной интервал
#! find ~/ -type f -newermt "2023-02-24 00:00:11" \! -newermt "2023-02-24 00:53:00" –ls


# <<< Заканчиваем писать файл network_info
# ----------------------------------
# ----------------------------------

# Активные демоны, процессы, задачи и их конфигурации
# (и типовые места закрепления вредоносов, часть 1)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл activity_info >>>

echo "[Проверка активностей (процессы, планировщики ...) в системе]"

# Вывод информации о текущих альтернативных задачах в screen
echo "[Список текущих активных сессий (Screen)]" >> activity_info 
screen -ls 2>/dev/null >> activity_info
echo -e "\n" >> activity_info

echo "[Фоновые задачи (jobs)]" >> activity_info 
jobs >> activity_info
echo -e "\n" >> activity_info

echo "[Задачи в планировщике (Crontab)]" >> host_info
crontab -l 2>/dev/null >> activity_info
echo -e "\n" >> activity_info

echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" >> cronconfigs_info
cat /etc/cron*/* >> cronconfigs_info
echo -e "\n" >> cronconfigs_info

echo "[Вывод запланированных задач для всех юзеров (Crontab)]" >> cronconfigs_info
for user in $(ls /home/); do echo $user; crontab -u $user -l;   echo -e "\n" >> cronconfigs_info >> cronconfigs_info; done
echo -e "\n" >> cronconfigs_info

echo "[Лог планировщика (Crontab) в файлах /etc/cron*]" >> cronconfigs_info
cat /var/log/cron.log* >> cronconfigs_info
echo -e "\n" >> cronconfigs_info

echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" >> activity_info
cat /etc/crontab >> activity_info
echo -e "\n" >> activity_info

echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]" >> activity_info 
ls -la  /etc/xdg/autostart/* 2>/dev/null  >> activity_info 
echo -e "\n" >> activity_info

echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]" >> activity_info 
cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null  >> activity_info 
echo -e "\n" >> activity_info

echo "[Автозагрузка в GNOME и KDE]" >> activity_info 
cat  /home/*/.config/autostart/*.desktop 2>/dev/null  >> activity_info 
echo -e "\n" >> activity_info

echo "[Задачи из systemctl list-timers (предстоящие задачи)]" >> host_info
systemctl list-timers >> activity_info
echo -e "\n" >> activity_info

# Список всех запущенных процессов, лучше класть в отдельный файлик
echo "[Список процессов (ROOT)]" >> activity_info
ps -l >> activity_info
echo -e "\n" >> activity_info

echo "[Список процессов (все)]" >> activity_info
ps aux >> activity_info
#ps -eaf
echo -e "\n" >> activity_info

# Гламурный вывод дерева процессов
echo "[Дерево процессов]" >> pstree_file
pstree -Aup >> pstree_file
echo -e "\n" >> pstree_file

echo "[Файлы с выводом в /dev/null]" >> lsof_file
lsof -w /dev/null >> activity_info
echo -e "\n" >> activity_info

# Текстовый вывод аналога виндового диспетчера задач
echo "[Инфа о процессах через top]" >> activity_info 
top -bcn1 -w512  >> activity_info
echo -e "\n" >> activity_info

echo "[Вывод задач в бэкграунде atjobs]" >> activity_info 
ls -la /var/spool/cron/atjobs 2>/dev/null >> activity_info 
echo -e "\n" >> activity_info

echo "[Вывод jobs из var/spool/at/]" >> activity_info 
cat  /var/spool/at/* 2>/dev/null >> activity_info 
echo -e "\n" >> activity_info

echo "[Файлы deny|allow со списками юзеров, которым разрешено в cron или jobs]" >> activity_info 
lcat /etc/at.* 2>/dev/null >> activity_info 
echo -e "\n" >> activity_info

echo "[Вывод задач Anacron]" >> activity_info 
cat /var/spool/anacron/cron.* 2>/dev/null >> activity_info 
echo -e "\n" >> activity_info

echo "[Поль­зовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" >> activity_info 
cat /etc/rc*/* 2>/dev/null >> activity_info
cat /etc/rc.d/* 2>/dev/null >> activity_info
echo -e "\n" >> activity_info

# Package files
echo "[Пакуем LOG-файлы (/var/log/)...]"
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

echo "[Проверка сервисов в системе]"

echo "[Список активных служб systemd]" >> services_info 
systemctl list-units  >> services_info
echo -e "\n" >> services_info

echo "[Список всех служб]" >> services_info 
# можно отдельно посмотреть модули ядра: cat /etc/modules.conf и cat /etc/modprobe.d/*
systemctl list-unit-files --type=service >> services_info
echo -e "\n" >> services_info

echo "[Статус работы всех служб (командой service)]" >> services_info 
service --status-all 2>/dev/null >> services_info
echo -e "\n" >> services_info

echo "[Вывод конфигураций всех сервисов]" >> services_configs 
cat /etc/systemd/system/*.service >> services_configs
echo -e "\n" >> services_configs

echo "[Список запускаемых сервисов (init)]" >> services_info 
ls -la /etc/init  2>/dev/null >> services_info
echo -e "\n" >> services_info

echo "[Сценарии запуска и остановки демонов (init.d)]" >> services_info 
ls -la /etc/init.d  2>/dev/null >> services_info
echo -e "\n" >> services_info

# <<< Заканчиваем писать файл services_info
# ----------------------------------
# ----------------------------------

# ----------------------------------
# ----------------------------------
# Начинаем писать файл devices_info >>>

echo "[Информация об устройствах]"

# Вывод инфо о PCI-шине
echo "[Информация об устройствах (lspci)]" >> devices_info 
lspci >> devices_info
echo -e "\n" >> devices_info

echo "[Устройства USB (lsusb)]" >> devices_info 
lsusb >> devices_info
echo -e "\n" >> devices_info

echo "[Блочные устройства (lsblk)]" >> devices_info 
lsblk >> devices_info
echo -e "\n" >> devices_info
# cat /sys/bus/pci/devices/*/*

echo "[Список примонтированных файловых систем (findmnt)]" >> devices_info 
findmnt >> devices_info
echo -e "\n" >> devices_info

echo "[Bluetooth устройства (bt-device -l)]" >> devices_info 
bt-device -l 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

echo "[Bluetooth устройства (hcitool dev)]" >> devices_info 
hcitool dev 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

echo "[Bluetooth устройства (/var/lib/bluetooth)]" >> devices_info 
ls -laR /var/lib/bluetooth/ 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

# Пример usbrip, если он установлен
# https://github.com/snovvcrash/usbrip
echo "[Устройства USB (usbrip)]" >> devices_info 
usbrip events history 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

# Подключенные в текущей сессии USB-устройства — у Linux аптайм обычно большой, может, прокатит
echo "[Устройства USB из dmesg]" >> devices_info 
dmesg | grep -i usb 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

# Usbrip делает то же самое, но потом обрабатывает данные и делает красиво
echo "[Устройства USB из journalctl]" >> devices_info 
journalctl | grep -i usb >> devices_info
# journalctl -o short-iso-precise | grep -iw usb
echo -e "\n" >> devices_info

echo "[Устройства USB из syslog]" >> devices_info
cat /var/log/syslog* | grep -i usb | grep -A1 -B2 -i SerialNumber: >> devices_info
echo -e "\n" >> devices_info

echo "[Устройства USB из (log messages)]" >> devices_info
cat /var/log/messages* | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

# Как ты понимаешь, устройства в текущей сессии имеет смысл собирать, только если система давно не перезагружалась
echo "[Устройства USB (самогреп dmesg)]" >> usb_list_file
dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber: >> usb_list_file
echo -e "\n" >> usb_list_file
echo "[Устройства USB (самогреп journalctl)]" >> usb_list_file
journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber: >> usb_list_file
echo -e "\n" >> usb_list_file

echo "[Другие устройства из journalctl]" >> devices_info
journalctl| grep -i 'PCI|ACPI|Plug' 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

echo "[Подключение/отключение сетевого кабеля (адаптера) из journalctl]" >> devices_info
journalctl | grep "NIC Link is" 2>/dev/null >> devices_info
echo -e "\n" >> devices_info

# Открытие/закрытие крышки ноутбука
echo "[LID open-downs:]" >> devices_info 
journalctl | grep "Lid"  2>/dev/null  >> devices_info
echo -e "\n" >> devices_info

# <<< Заканчиваем писать файл devices_info
# ----------------------------------
# ----------------------------------

# Закрепы вредоносов
# собираем инфу и конфиги для последующего анализа

# ----------------------------------
# ----------------------------------
# Начинаем писать файл env_profile_info >>>

echo "[Информация переменных системы, шелле и профилях пользователей]"
echo "[Глобальные переменные среды ОС (env)]" >> env_profile_info
env >> env_profile_info
echo -e "\n" >> env_profile_info

echo "[Все текущие переменные среды]" >> env_profile_info
printenv >> env_profile_info
echo -e "\n" >> env_profile_info

echo "[Переменные шелла]" >> env_profile_info
set >> env_profile_info
echo -e "\n" >> env_profile_info

echo "[Расположнеие исполняемых файлов доступных шеллов:]" >> env_profile_info
cat /etc/shells 2>/dev/null >> env_profile_info
echo -e "\n" >> env_profile_info

if [ -e "/etc/profile" ] ; then
    echo "[Содержимое из /etc/profile]" >> env_profile_info
    cat /etc/profile 2>/dev/null >> env_profile_info
    echo -e "\n" >> env_profile_info
fi



echo "[Содержимое из файлов /home/users/.*]" >> usrs_cfgs
for name in $(ls /home); do
    #cat /home/$name/.*_profile 2>/dev/null >> env_profile_info
	echo Hidden config-files for: $name >> usrs_cfgs
	cat /home/$name/.* 2>/dev/null  >> usrs_cfgs
    echo -e "\n" >> usrs_cfgs
done

# Нижеследующие команды (пять блоков if) можно успешно заменить на эту:
echo "[Содержимое скрытых конфигов рута - cat ROOT ~/.* (homie directory content + history)]" >> root_cfg
cat /root/.* 2>/dev/null >> root_cfg
echo -e "\n" >> root_cfg

# убрать при review кода:
#if ls /root/.*_profile >/dev/null 2>&1; then
#    echo "[Содержимое из /root/.*_profile]" >> env_profile_info
#    cat /root/.*_profile 2>/dev/null >> env_profile_info
#    echo -e "\n" >> env_profile_info
#fi

#if ls /root/.*_login >/dev/null 2>&1;then
#    echo "[Содержимое из /root/.*_login]" >> env_profile_info
#    cat /root/.*_login >> env_profile_info
#    echo -e "\n" >> env_profile_info
#fi

#if [ -e "/root/.profile" ]; then
#    echo "[Содержимое из /root/.profile]" >> env_profile_info
#    cat /root/.profile 2>/dev/null >> env_profile_info
#    echo -e "\n" >> env_profile_info
#fi

#if ls /root/.*rc >/dev/null 2>&1;then
#    echo "[Содержимое из /root/.*rc]" >> env_profile_info
#    cat /root/.*rc >> env_profile_info
#    echo -e "\n" >> env_profile_info
#fi

#if ls /root/.*_logout >/dev/null 2>&1; then 
#    echo "[Содержимое из /root/.*_logout]" >> env_profile_info
#    cat /root/.*_logout >> env_profile_info
#    echo -e "\n" >> env_profile_info
#fi

# Список файлов, пример
#.*_profile (.profile)
#.*_login
#.*_logout
#.*rc
#.*history 

echo "[Пользователи SUDO]" >> env_profile_info
cat /etc/sudoers 2>/dev/null >> env_profile_info
echo -e "\n" >> env_profile_info



# <<< Заканчиваем писать файл env_profile_info
# ----------------------------------
# ----------------------------------

# Сюда помещаем крайне специфичные случаи, которые можно по-хорошему и удалить 
# Быть может, кому-то поможет в части избыточной информации
#! - начало для файла junk_info

# ----------------------------------
# ----------------------------------
# Начинаем писать файл junk_info >>>

# Проверимся на руткиты, иногда помогает
echo "[Проверка на rootkits командой chkrootkit]" >> junk_info
chkrootkit 2>/dev/null >> junk_info
echo -e "\n" >> junk_info


echo "[Shishiga or RotaJakiro Markers?]"
echo "[Shishiga or RotaJakiro Markers?]" >> junk_info
echo -e "\n" >> junk_info
# https://www.welivesecurity.com/2017/04/25/linux-shishiga-malware-using-lua-scripts/
FILES="/etc/rc2.d/S04syslogd
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
counter=0;
for f in $FILES
do
if [ -e $f ]
then 
	#$counter=$counter +1;
	counter=$((counter+1)) # thanks duodai
	echo "Shishiga or RotaJakiro Marker-file found: " $f >> junk_info
	echo -e "\n" >> junk_info
fi

done

if [ $counter -gt 0 ]
then 
	echo "Shishiga Markers found!!" 
	echo "Shishiga Markers found!!" >> junk_info
	echo -e "\n" >> junk_info
fi

# ниже идут команды, которые применялись в самой первой версии скрипта, который представлял собой безумную компиляцию из кучи команд без особого понимания в их необходимости. но в части ресурсов, книг и других скриптов они, возможно, были...
# ...а теперь мне просто западло их убирать

echo "[i am alive, just processing...]"

# time information diff maybe?
echo "[BIOS TIME]" >> junk_info
hwclock -r 2>/dev/null >> junk_info
echo -e "\n" >> junk_info
echo "[SYSTEM TIME]" >> junk_info
date >> junk_info
echo -e "\n" >> junk_info

# privilege information
echo "[PRIVILEGE passwd - all users]" >> junk_info
cat /etc/passwd 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

# ssh keys
echo "[Additional info cat ssh (root) keys and hosts]" >> junk_info
cat /root/.ssh/authorized_keys 2>/dev/null >> junk_info
cat /root/.ssh/known_hosts 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

#for users:
echo "[Additional info cat ssh (users) keys and hosts]" >> junk_info
for name in $(ls /home)
do
echo SSH-files for: $name >> junk_info
cat /home/$name/.ssh/authorized_keys 2>/dev/null >> junk_info
echo -e "\n" >> junk_info
cat /home/$name/.ssh/known_hosts 2>/dev/null >> junk_info
done
echo -e "\n" >> junk_info

# VM - detection
echo "[Virtual Machine Detection]" >> junk_info
dmidecode -s system-manufacturer 2>/dev/null >> junk_info
echo -e "\n" >> junk_info
dmidecode  2>/dev/null >> junk_info
echo -e "\n" >> junk_info


# HTTP server inforamtion collection
# Nginx collection
echo "[Nginx Info]" >> junk_info
echo -e "\n" >> junk_info
# tar default directory
if [ -e "/usr/local/nginx" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
	echo "Grab NGINX files!" >> junk_info
	echo -e "\n" >> junk_info
fi

# Apache2 collection
echo "[Apache Info]" >> junk_info
echo -e "\n" >> junk_info
# tar default directory
if [ -e "/etc/apache2" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/apache2 2>/dev/null
	echo "Grab APACHE files!" >> junk_info
	echo -e "\n" >> junk_info
fi

# Install files
echo "[Core modules - lsmod]" >> junk_info
lsmod >> junk_info
echo -e "\n" >> junk_info

echo "[Пустые пароли ?]" >> junk_info
cat /etc/shadow | awk -F: '($2==""){print $1}' >> junk_info
echo -e "\n" >> junk_info

# Malware collection
# .bin
#echo "[BIN FILETYPE]" >> junk_info
#find / -name \*.bin >> junk_info
#echo -e "\n" >> junk_info

# .exe
#echo "[BIN FILETYPE]" >> junk_info
#find / -name \*.exe >> junk_info
#echo -e "\n" >> junk_info

#find copied
# Find nouser or nogroup  data
echo "[NOUSER files]" >> junk_info
find /root /home -nouser 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

# check for files without holder
#find / -xdev \( -nouser -o -nogroup \) -print
# check for files without holder
#find / \( -perm -4000 -o -perm -2000 \) -print

echo "[NOGROUP files]" >> junk_info
find /root /home -nogroup 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[lsof -n]" >> lsof_file
lsof -n 2>/dev/null>> lsof_file
echo -e "\n" >> lsof_file

echo "[Verbose open files: lsof -V ]" >> lsof_file #open ports
lsof -V  >> lsof_file
# lsof 
echo -e "\n" >> lsof_file

if [ -e /var/log/btmp ]
	then 
	echo "[Last LOGIN fails: lastb]" >> junk_info
	lastb 2>/dev/null >> junk_info
	echo -e "\n" >> junk_info
fi

if [ -e /var/log/wtmp ]
	then 
	echo "[Login logs and reboot: last -f /var/log/wtmp]" >> junk_info
	last -f /var/log/wtmp >> junk_info
	echo -e "\n" >> junk_info
fi

if [ -e /etc/inetd.conf ]
then
	echo "[inetd.conf]" >> junk_info
	cat /etc/inetd.conf >> junk_info
	echo -e "\n" >> junk_info
fi

echo "[File system info: df -k in blocks]" >> junk_info
df -k >> junk_info
echo -e "\n" >> junk_info

echo "[File system info: df -Th in human format]" >> junk_info
df -Th >> junk_info
echo -e "\n" >> junk_info

echo "[List of mounted filesystems: mount]" >> junk_info
mount >> junk_info
echo -e "\n" >> junk_info

echo "[kernel messages: dmesg]" >> junk_info
dmesg 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Repo info: cat /etc/apt/sources.list]" >> junk_info 
cat /etc/apt/sources.list >> junk_info
echo -e "\n" >> junk_info

echo "[Static file system info: cat /etc/fstab]" >> junk_info 
cat /etc/fstab 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

# echo "Begin Additional Sequence Now *********************************"

# Vurtual memory statistics
echo "[Virtual memory state: vmstat]" >> junk_info 
vmstat >> junk_info
echo -e "\n" >> junk_info

# Check for hardware events
echo "[HD devices check: dmesg | grep hd]" >> junk_info 
dmesg | grep -i hd 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

# Show activity log
echo "[Get log messages: cat /var/log/messages]" >> junk_info 
cat /var/log/messages 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[USB check 3 Try: cat /var/log/messages]" >> junk_info 
cat /var/log/messages | grep -i usb 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

# List all mounted files and drives
echo "[List all mounted files and drives: ls -lat /mnt]" >> junk_info 
ls -lat /mnt >> junk_info
echo -e "\n" >> junk_info

echo "[Disk usage: du -sh]" >> junk_info 
du -sh >> junk_info
echo -e "\n" >> junk_info

echo "[Disk partition info: fdisk -l]" >> junk_info 
fdisk -l 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Additional info - OS version cat /proc/version]" >> junk_info
cat /proc/version >> junk_info
echo -e "\n" >> junk_info

echo "[Additional info lsb_release (distribution info)]" >> junk_info
lsb_release 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Query journal: journalctl]" >> junk_info 
journalctl >> junk_info
##journalctl -o export > journal-exp.txt
echo -e "\n" >> junk_info

echo "[Memory free]" >> junk_info 
free >> junk_info
echo -e "\n" >> junk_info

echo "[Hardware: lshw]" >> junk_info 
lshw 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Hardware info: cat /proc/(cpuinfo|meminfo)]" >> junk_info 
cat /proc/cpuinfo >> junk_info
echo -e "\n" >> junk_info
cat /proc/meminfo >> junk_info
echo -e "\n" >> junk_info

echo "[/sbin/sysctl -a (core parameters list)]" >> junk_info 
/sbin/sysctl -a 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Profile parameters: cat /etc/profile.d/*]" >> junk_info 
cat /etc/profile.d/* 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Language locale]" >> junk_info 
locale  2>/dev/null >> junk_info
echo -e "\n" >> junk_info


#manual installed
echo "[Get manually installed packages apt-mark showmanual (TOP)]" >> junk_info 
apt-mark showmanual 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]" >> junk_info 
apt list --manual-installed | grep -F \[installed\] 2>/dev/null  >> junk_info
echo -e "\n" >> junk_info
#aptitude search '!~M ~i'
#aptitude search -F %p '~i!~M'

mkdir -p ./artifacts/config_root
#desktop icons and other_stuff
cp -r /root/.config ./artifacts/config_root 2>/dev/null 
#saved desktop sessions of users
cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

echo "[VMware clipboard (root)!]" >> junk_info
ls -laR /root/.cache/vmware/drag_and_drop/ 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Mails of root]" >> junk_info
cat /var/mail/root 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

#cp -R ~/.config/ 2>/dev/null 

#ls -la /usr/share/applications
echo "[Apps ls -la /usr/share/applications]" >> junk_info 
ls -la /usr/share/applications >> junk_info
#ls -la /home/*/.local/share/applications/ 
echo -e "\n" >> junk_info

#recent 
echo "[Recently-Used]" >> junk_info 
cat  /home/*/.local/share/recently-used.xbel 2>/dev/null >>  junk_info 
echo -e "\n" >> junk_info 

#get mail for each user:
#echo "[Recently-Used]" >> junk_info 
#cat /var/mail/username$ 2>/dev/null 

#mini list of apps
echo "[Var-LIBS directories - like program list]" >> junk_info 
ls -la /var/lib 2>/dev/null >> junk_info 
echo -e "\n" >> junk_info

# crypto stuff
echo "[Some encypted data?]" >> junk_info 
cat /etc/crypttab 2>/dev/null >> junk_info 
echo -e "\n" >> junk_info

# Default settings for user directories
echo "[User dirs default configs]" >> junk_info 
cat /etc/xdg/user-dirs.defaults    2>/dev/null  >> junk_info
echo -e "\n" >> junk_info      

#os info
echo "[OS-release:]" >> junk_info 
cat /etc/os-release 2>/dev/null >> junk_info 
echo -e "\n" >> junk_info

#list boots 
echo "[List of boots]" >> junk_info 
journalctl --list-boots  2>/dev/null >> junk_info 
echo -e "\n" >> junk_info

#machine ID
echo "[Machine-ID:]" >> junk_info 
cat /etc/machine-id 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

#analyze ssl certs and keys
echo "[SSL files:]" >> junk_info 
ls -laR /etc/ssl    2>/dev/null  >> junk_info
echo -e "\n" >> junk_info

#GPG info
echo "[GnuPG contains:]" >> junk_info 
ls -la ~/.gnupg/* 2>/dev/null >> junk_info 
echo -e "\n" >> junk_info

# Здесь можно встретить информацию в виде dat-файлов о состоянии батареи ноутбука, включая процент зарядки, расход и состояние отключения батарейки и ее заряда
#battery info for laptops
#history­charge­*.dat — log of percentage charged
# history­rate­*.dat — log of energy consumption rate
#history­time­empty­*.dat — when unplugged, log of time (in seconds) until empty
# history­time­full­*.dat — when charging, log of time (in seconds) until full
echo "[Battery logs]" >> junk_info 
cat /var/lib/upower/* 2>/dev/null >> junk_info 
echo -e "\n" >> junk_info 

echo "Get UUID of partitions: blkid" >> junk_info
blkid 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

echo "[Volumes: vol*]" >> junk_info
cat /media/data/vol* 2>/dev/null>> junk_info
echo -e "\n" >> junk_info

#COPY ALL WEB PROFILES FOR THE GOD!
echo "[Web collection]"
echo "[Web collection]" >> junk_info
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

echo "[Look through (SSH) service logs for errors]" >> junk_info
journalctl _SYSTEMD_UNIT=sshd.service | grep “error” 2>/dev/null >> junk_info
echo -e "\n" >> junk_info

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

	#check mail:
	echo "[Mails of $usa:]" >> junk_info
	cat /var/mail/$usa 2>/dev/null >> junk_info
	echo -e "\n" >> junk_info

	echo "[VMware clipboard (maybe)!]" >> junk_info
	ls -laR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null >> junk_info
	echo -e "\n" >> junk_info
done

# <<< Заканчиваем писать файл junk_info
# ----------------------------------
# ----------------------------------
#! - конец для записи файла junk_info

# ----------------------------------
# ----------------------------------

# Архивируем собранные артефакты
echo Packing artifacts...
tar --remove-files -zc -f ./artifacts.tar.gz artifacts 2>/dev/null
  
echo "Завершили сбор данных!" >> host_info
date >> host_info
echo -e "\n" >> host_info

# Завершающая часть после выполнения необходимых команд
# Для выходной директории даем права всем на чтение и удаление
 chmod -R ugo+rwx ./../$saveto
 end=`date +%s`
 echo -e "\n" 
 echo ENDED! Execution time was $(expr $end - $start) seconds.
 echo "Проверяй директорию ${saveto}!"

# Открываем директорию в файловом менеджере — работает не во всех дистрибутивах. В Astra также можно использовать команду fly-fm
xdg-open .
 } |& tee ./console_log # Наш лог-файл
