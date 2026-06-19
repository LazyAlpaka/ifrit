#!/bin/bash
# IFRIT. Stands for: Incident Forensic Response In Terminal =)
# Official release 4.1 (13.06.2026)
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
echo -e "${yellow}build 14.06.2026 ${clear}"


# Глобальные флаги для работы. При их установке необходимо заполнить связанные поисковые массивы ниже
SET_HISTORY=0 			# принудительная установка best-practice HISTTIMEFORMAT
SEARCH_KEYWORDS=0       # поиск ключевых слов в /home/* (массив terms)
SEARCH_IPS=0        	# поиск IP-адресов в /usr /etc /var (массив ips)
SEARCH_IOC_FILES=1      # проверка файловых IOC-путей (массив iocfiles)
SEARCH_DATERANGE=0      # поиск файлов в home по диапазону дат (переменные startdate, enddate)
SEARCH_UNUSIAL_LOGS=0 	# поиск файлов-логов в директориях /root /home /bin /etc /lib64 /opt /run /usr
SEARCH_IPS_LOGS=0		# экстракции всех IP-адресов из всех логов
SEARCH_UNUSIAL_EXT=0 	# поиск нестандартных расширений файлов в /home


echo -e "${cyan}Configuration:${clear}"
echo "  SEARCH_KEYWORDS=$SEARCH_KEYWORDS, SEARCH_IPS=$SEARCH_IPS"
echo "  SEARCH_IOC_FILES=$SEARCH_IOC_FILES, SEARCH_DATERANGE=$SEARCH_DATERANGE"
echo "  SET_HISTORY=$SET_HISTORY, SEARCH_UNUSIAL_LOGS=$SEARCH_UNUSIAL_LOGS"
echo "  SEARCH_IPS_LOGS=$SEARCH_IPS_LOGS, SEARCH_UNUSIAL_EXT=$SEARCH_UNUSIAL_EXT"
echo

# Задаём связанные массивы переменных
#! Даты и время предполагаемого инцидента для поиска изменённых за это время файлов (потом ищем их в домашних каталогах). Нужно будет раскомментировать строки ниже в коде для включения данного режима
startdate="2024-05-09 00:53:00"
enddate="2025-05-10 05:00:00" 

#! IP-адресов, ищем в логах приложений /usr /etc /var. Оставь пустым, если не нужно, разделённых пробелом
#ips=("1.2.3.5" "6.7.8.9" )
ips=()

#! Терминов\слов для поиска в домашних каталогах и файлах, разделённых пробелом
# terms=("терменвокс"  "1.2.3.4" )
terms=()

#! Папок и путей для поиска подозрительных мест залегания
# Сейчас - Shishiga и Rotajakiro
# iocfiles=()
iocfiles=(
    "/etc/rc2.d/S04syslogd"
    "/etc/rc3.d/S04syslogd"
    "/etc/rc4.d/S04syslogd"
    "/etc/rc5.d/S04syslogd"
    "/etc/init.d/syslogd"
    "/bin/syslogd"
    "/etc/cron.hourly/syslogd"
    "/tmp/drop"
    "/tmp/srv"
    "$HOME/.local/ssh.txt"
    "$HOME/.local/telnet.txt"
    "$HOME/.local/nodes.cfg"
    "$HOME/.local/check"
    "$HOME/.local/script.bt"
    "$HOME/.local/update.bt"
    "$HOME/.local/server.bt"
    "$HOME/.local/syslog"
    "$HOME/.local/syslog.pid"
    "$HOME/.dbus/sessions/session-dbus"
    "$HOME/.gvfsd/.profile/gvfsd-helper"
)

# Разрешим скрипту продолжать выполняться с ошибками. Это необязательно, для острастки
set +e
set -o pipefail 

# Задаём служебные функции
# Дисклеймер команды
snapshot_header() {
	comment="$1"
	shift
	command="$@"
	echo -e "\n### $(date '+%Y-%m-%d %H:%M:%S') [$comment] - executing '$command'  ###";
}

# Обёртка вызова команды
snapshot() {
    local file="$1" label="$2";
    shift 2
    {
        snapshot_header "$label" "$@"
        "$@" 2>/dev/null
    } >> "$file"
}

# Фиксируем текущую дату
start=$(date +%s)

# Проверка, что мы root
echo -e "${magenta}[Текущий пользователь]${clear}"
echo $(id -u -n)

# «Без root будет бедная форензика»
if (( $EUID != 0 )); then
# if [ $(id -u) -ne 0 ]; then
    echo -e "${red}Пользователь не root!! ${clear}"
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
cd $saveto #|| {echo "Ошибка: не удалось перейти в $saveto" >&2; exit 1; }

# Создаем вложенную директорию для триаж-файлов
mkdir -p ./artifacts


# Package files  - сразу пакуем логи, чтобы не мусорить скриптом
echo -e "${green}[Пакуем LOG-файлы (/var/log/)...]${clear}"

# Дополнительная проверка, что логи поместятся и что нет проблем с lastlog

LASTLOG_FILE="/var/log/lastlog"
LASTLOG_MAX_SIZE=$((100 * 1024 * 1024))  

# Функция для получения размера в байтах
get_size_bytes() {
    #stat -c%s "$1" 2>/dev/null || echo 0
	du -b "$1" | awk '{print $1}' || echo 0
}

# Функция для получения свободного места в байтах
get_free_space() {
    df --output=avail -B1 ./ | tail -n1
}

# Функция для оценки размера архива
estimate_archive_size() {
    local total_size=0
    
    # Считаем размер всех файлов в /var/log кроме lastlog
    while IFS= read -r -d '' file; do
        if [[ "$file" != "$LASTLOG_FILE" ]]; then
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
        fi
    done < <(find /var/log -type f -print0 2>/dev/null)
    
    echo $total_size
}


# ========== ПРОВЕРКА 1: Достаточно ли места ==========
echo "Проверка свободного места на диске..."

# Оцениваем размер будущего архива (размер всех файлов логов)
estimated_log_size=$(estimate_archive_size)
echo "Примерный размер файлов логов (без lastlog): $((estimated_log_size / 1024 / 1024)) МБ"

# Учитываем, что lastlog может быть добавлен в сжатом виде
if [ -f "$LASTLOG_FILE" ]; then
    lastlog_real_size=$(get_size_bytes "$LASTLOG_FILE")
    
    if [ "$lastlog_real_size" -gt "$LASTLOG_MAX_SIZE" ]; then
        # Если lastlog большой, добавляем его сжатый размер (примерно 10% от исходного)
        estimated_lastlog_compressed=$((lastlog_real_size / 10))
        estimated_log_size=$((estimated_log_size + estimated_lastlog_compressed))
        echo "Lastlog будет сжат отдельно (примерно до $((estimated_lastlog_compressed / 1024 / 1024)) МБ)"
    else
        estimated_log_size=$((estimated_log_size + lastlog_real_size))
    fi
fi

# Применяем коэффициент сжатия и небольшой запас
required_space=$((estimated_log_size / 2 * 3))  # примерно 50% сжатие + запас
free_space=$(get_free_space)

echo "Необходимо места: примерно $((required_space / 1024 / 1024)) МБ"
echo "Свободного места: $((free_space / 1024 / 1024)) МБ"

if [ "${free_space:-0}" -lt "${required_space:-0}" ]; then
    echo "ОШИБКА: Недостаточно места для создания архива с логами!"
    echo "Требуется: $((required_space / 1024 / 1024)) МБ"
    echo "Доступно: $((free_space / 1024 / 1024)) МБ"
    #exit 1
	
else

echo "✓ Места достаточно"

# продолжаем проверки

echo "Проверка размера $LASTLOG_FILE..."

if [ -f "$LASTLOG_FILE" ]; then
    # Получаем реальный размер файла (allocated size)
    real_size=$(get_size_bytes "$LASTLOG_FILE")
    
    echo "Реальный размер lastlog: $((real_size / 1024 / 1024)) МБ"
    #echo "Занимает на диске: $((disk_size / 1024 / 1024)) МБ"
    
    if [ "$real_size" -gt "$LASTLOG_MAX_SIZE" ]; then
        echo "ВНИМАНИЕ: lastlog превышает 100 МБ или является sparse-файлом"
        echo "Будет выполнена специальная обработка..."
        
        # Копируем только реальные данные (разреженные области пропускаются)
		# different handler for troubled file
		tar --sparse -czf ./artifacts/lastlog.tar.gz /var/log/lastlog
            
            echo "✓ Lastlog обработан отдельно"

    else
        # Размер в норме, создаем обычный архив
        echo "Размер lastlog в норме, создаем стандартный архив..."
        #tar --exclude='lastlog' -czf "$ARCHIVE_PATH" /var/log
        # /var/log/
		tar	 -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null
        # Добавляем lastlog отдельно в архив
        #tar --append -f "$ARCHIVE_PATH" -C /var/log lastlog 2>/dev/null || \
        #gzip -c /var/log/lastlog > ./artifacts/lastlog.gz
        
        echo "✓ Архив создан с lastlog"
    fi
else
    # lastlog отсутствует
    echo "lastlog не найден, создаем архив без него..."
	# /var/log/
	tar --exclude='lastlog' -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null
fi

# /var/log/
#tar --exclude='lastlog' -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null

if [ -d /var/run/log ]; then
	tar -zc -f ./artifacts/VAR_RUN_LOG.tar.gz /var/run/log  2>/dev/null && echo 'Логи скопированы';
	else echo 'Директория /var/run/log не найдена'; 
fi


fi


# Шпора:
#/var/log/auth.log Аутентификация
#/var/log/cron.log Cron задачи
#/ var / log / maillog Почта
#/ var / log / httpd Apache
# Подробнее: https://www.securitylab.ru/analytics/520469.php


# Начинаем писать лог в файл
# Кодировка файлов по умолчанию  UTF-8
	
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
snapshot host_info "Текущий хост и время" date
snapshot host_info "Имя хоста" hostname
snapshot host_info "DNS/FQDN" dnsdomainname

# Сведения о релизе ОС, например из файла os-release
# Аналоги: cat /usr/lib/os-release или lsb_release
snapshot host_info "Доп информация о системе из etc/*(-release|_version)" cat /proc/version
snapshot host_info "Доп информация о системе из etc/*release" more /etc/*release
snapshot host_info "Доп информация о системе из etc/*version" more /etc/*version

# Для справки:
#Вывести непустые и некомментарии строчки 
# grep -v '^#' /file | grep -P '\S'

snapshot host_info "Доп информация о системе из /etc/issue" cat /etc/issue
snapshot host_info "Доп информация о системе из /etc/issue.net" cat /etc/issue.net
snapshot host_info "Идентификатор хоста (hostid)" hostid
snapshot host_info "Информация из hostname" hostname -f
snapshot host_info "Информация из hostnamectl" hostnamectl
snapshot host_info "IP адрес(а)" ip addr
snapshot host_info "Информация о системе" uname -a
snapshot host_info "Текущий пользователь" who am i
snapshot host_info "Группы пользователя" groups
snapshot host_info "Действующие алиасы" alias
snapshot host_info "Информация об учетных записях и группах" bash -c "for name in $(ls /home); do id $name; done"


# Получим список живых пользователей. Зачастую мы хотим просто посмотреть реальных пользователей, у которых есть каталоги, чтобы в них порыться. Запишем имена в переменную для последующей эксплуатации

echo -e "${magenta}[Анализ базы]${clear}" 
snapshot host_info "Пользователи с /home/" ls /home
# Исключаем папку lost+found
users=`ls /home -I lost*`
snapshot host_info "Залогиненные юзеры" w
snapshot host_info "Залогиненные юзеры (who --all)" who --all
snapshot host_info "Залогиненные юзеры и терминалы (who -T)" who -T

snapshot host_info "File system info: df -k" df -k
snapshot host_info "File system info: df -Th" df -Th
snapshot host_info "List of mounted filesystems: mount" mount
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

snapshot users_files "AD_cfg_info" cat /etc/sssd/sssd.conf
snapshot users_files "/etc/passwd" cat /etc/passwd
snapshot users_files "/etc/shadow" cat /etc/shadow
snapshot users_files "/etc/group" cat /etc/group

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
	#sudo -l -U $name 2>&1;
	sudo -n -l -U $name 2>&1 || echo "sudo check skipped (password required)"
	echo -e "\n" ; 
done;

snapshot users_files "Пользовательские файлы из (Downloads,Documents, Desktop)" ls -lta /home/*/Downloads
snapshot users_files "Пользовательские файлы из (Загрузки)" ls -lta /home/*/Загрузки
snapshot users_files "Пользовательские файлы из (Documents)" ls -lta /home/*/Documents
snapshot users_files "Пользовательские файлы из (Документы)" ls -lta /home/*/Документы
snapshot users_files "Пользовательские файлы из (Desktop)" ls -lta /home/*/Desktop
snapshot users_files "Пользовательские файлы из (Рабочий стол)" ls -lta /home/*/Рабочий\ стол
snapshot users_files "Файлы в корзине из home" ls -ltaR /home/*/.local/share/Trash/files
snapshot users_files "Файлы в корзине из root" ls -ltaR /root/.local/share/Trash/files
snapshot users_files "Кешированные изображения программ из home" ls -lta /home/*/.thumbnails

} >> users_files

# Ищем лакомые термины в домашних пользовательских папках
if [[ "$SEARCH_KEYWORDS" -gt 0 ]] && [[ "${#terms[@]}" -gt 0 ]]; then
	echo -e "${magenta}[Ищем ключевые слова... ]${clear}"

	for f in ${terms[@]};
	do
		echo "Search keyword $f" 
		echo -e "\n" >> ioc_word_info
		# add  binary files supports
		grep -a -C2 -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /home/* 2>/dev/null >> ioc_word_info
		
	done
fi


if [[ "$SEARCH_UNUSIAL_EXT" -gt 0 ]]; then
	echo "[Поиск интересных файловых расширений в папках home и root]"
	find /root /home -type f -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml 2>/dev/null >> users_files
	echo -e "\n" >> users_files
fi

# Ищем логи приложений (но не в /var/log)
if [[ "$SEARCH_UNUSIAL_LOGS" -gt 0 ]]; then
	echo "[Возможные логи приложений (с именем или расширением *log*)]"
	echo "[Возможные логи приложений (с именем или расширением *log*)]" >> int_files_info
	find /root /home /bin /etc /lib64 /opt /run /usr -type f \( -name "*.log" -o -name "*_log*" -o -name "*.log.*" -o -name "*-log*" \) \
    ! -name "*.png" ! -name "*.svg" ! -name "*.jpg" ! -name "*.jpeg" \
    ! -name "*.gif" ! -name "*.ico" ! -name "*.webp" \
    ! -name "*.ogg" ! -name "*.oga" ! -name "*.wav" ! -name "*.mp3" ! -name "*.mp4" \
    ! -name "*.woff" ! -name "*.woff2" ! -name "*.ttf" ! -name "*.eot" 2>/dev/null >> int_files_info
fi

# Ищем в домашнем каталоге файлы с изменениями (созданием) в определённый временной интервал
if [[ "$SEARCH_DATERANGE" -gt 0 ]]; then
	echo "[Ищем между датами от ${startdate} до ${enddate}]"
	# пример запуска:
	# find /home/* -type f -newermt "2023-02-24 00:00:11" \! -newermt "2023-02-24 00:53:00" -ls >> int_files_info
	find /home/* -type f -newermt "${startdate}" \! -newermt "${enddate}" -ls >> int_files_info
	# ещё вариант для определённых директорий:
	# find -newerct "10 May 2024 05:00:00" ! -newerct "10 May 2024 11:00:00" -ls | sort
fi

# Поиск бинарей с capabilites
#getcap -r / 2>/dev/null

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
snapshot apps_file "Installed apps with GUI" bash -c "ls /usr/share/applications | awk -F '.desktop' ' { print \$1}' - | grep -v -e fly -e org -e okularApplication"

echo "[Проверка браузеров и других приложений]" 
# вызывает зависания иногда
snapshot apps_file "Проверка firefox" bash -c "[ "$EUID" -ne 0 ] && firefox --version || echo Not executed because of root" 
snapshot apps_file "Проверка firefox (dpkg)" bash -c "dpkg -l --no-pager| grep firefox"
snapshot apps_file "Проверка thunderbird" thunderbird --version
snapshot apps_file "Проверка chromium" chromium --version
snapshot apps_file "Проверка chrome" chrome --version
snapshot apps_file "Проверка opera" opera --version
snapshot apps_file "Проверка brave" brave --version
snapshot apps_file "Проверка yandex-browser-beta" yandex-browser-beta --version

# Проверка стандартных приложений для открытия файлов
# xdg-mime query default application/xml 2>/dev/null
# Get part of registered apps, associated with mime types
#grep 'MimeType' /usr/share/applications/*.desktop | tr ';' '\n'
#snapshot apps_file "Desktop files props (short)" bash -c 'for dfile in /usr/share/applications/*.desktop; do echo \$dfile; grep Name= \$dfile; grep GenericName= \$dfile; grep Comment= \$dfile; grep Exec= \$dfile; grep MimeType= \$dfile; echo; done'

echo "Desktop files props (short)"
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
snapshot apps_file "Проверка signal-desktop" signal-desktop --version
snapshot apps_file "Проверка viber" viber --version
snapshot apps_file "Проверка whatsapp-desktop" whatsapp-desktop --version
snapshot apps_file "Проверка tdesktop" tdesktop --version
snapshot apps_file "Проверка zoom" zoom --version
snapshot apps_file "Проверка steam" steam --version
snapshot apps_file "Проверка discord" discord --version
snapshot apps_file "Проверка dropbox" dropbox --version
snapshot apps_file "Проверка yandex-disk" yandex-disk --version

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
		  #update=$(jq ".update_url" $i)
		  update=$(grep -o '"update_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$i" | cut -f4 -d '"')
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
snapshot apps_file "Python packages" pip list

# pip3 packages
snapshot apps_file "pip3 packages" pip3 list

} >> apps_file

echo -e "${magenta}[Сохранение профилей популярных браузеров в папку ./artifacts]${clear}"
{
snapshot apps_file "Сохранение профилей mozilla" bash -c 'for d in /home/*/.mozilla/firefox/; do [ -d "$d" ] && mkdir -p ./artifacts/mozilla && cp -r "$d" ./artifacts/mozilla 2>/dev/null; done'
snapshot apps_file "Сохранение профилей google-chrome" bash -c 'for d in /home/*/.config/google-chrome*/; do [ -d "$d" ] && mkdir -p ./artifacts/gchrome && cp -r "$d" ./artifacts/gchrome 2>/dev/null; done'
snapshot apps_file "Сохранение профилей chromium" bash -c 'for d in /home/*/.config/chromium/; do [ -d "$d" ] && mkdir -p ./artifacts/chromium && cp -r "$d" ./artifacts/chromium 2>/dev/null; done'
snapshot apps_file "Сохранение профилей brave" bash -c 'for d in /home/*/.config/Brave*/; do [ -d "$d" ] && mkdir -p ./artifacts/brave && cp -r "$d" ./artifacts/brave 2>/dev/null; done'
snapshot apps_file "Сохранение профилей opera" bash -c 'for d in /home/*/.config/opera*/; do [ -d "$d" ] && mkdir -p ./artifacts/opera && cp -r "$d" ./artifacts/opera 2>/dev/null; done'
snapshot apps_file "Сохранение профилей yandex" bash -c 'for d in /home/*/.config/yandex*/; do [ -d "$d" ] && mkdir -p ./artifacts/yandex && cp -r "$d" ./artifacts/yandex 2>/dev/null; done'

# remove empty folders
find ./artifacts/ -maxdepth 1 -empty -type d -delete

snapshot apps_file "Проверка приложений торрента" bash -c "apt list --installed 2>/dev/null | grep torrent"
snapshot apps_file "Все пакеты, установленные в системе" bash -c "apt list --installed 2>/dev/null"
snapshot apps_file "dpkg - installed apps" bash -c "dpkg --get-selections 2>/dev/null"
snapshot apps_file "snap - installed apps" snap list
snapshot apps_file "Все пакеты, установленные вручную" bash -c "apt-mark showmanual 2>/dev/null"
snapshot apps_file "Все пакеты, установленные вручную (вар. 2)" bash -c "apt list --manual-installed 2>/dev/null | grep -F -e \[установлен\] -e \[installed\]"

# Как вариант, можешь написать aptitude search '!~M ~i' или aptitude search -F %p '~i!~M'
# Для openSUSE, ALT, Mandriva, Fedora, Red Hat, CentOS
snapshot apps_file "rpm - installed apps" bash -c "rpm -qa --qf '(%{INSTALLTIME:date}): %{NAME}-%{VERSION}\n' 2>/dev/null"

# Для Fedora, Red Hat, CentOS
snapshot apps_file "yum list installed" yum list installed

# Для Fedora
snapshot apps_file "dnf list installed" dnf list installed

# Для Arch
snapshot apps_file "pacman -Q" pacman -Q

# Для openSUSE
snapshot apps_file "zypper info" zypper info

# Поставил в конец, чтобы не мусорило
# get firefox extensions list
snapshot apps_file "Firefox browser extensions" bash -c "more /home/*/.mozilla/firefox/*.default-release/extensions.json 2>/dev/null | cat"

# get thunderbird extensions list
snapshot apps_file "Thunderbird extensions" bash -c "more /home/*/.thunderbird/*.default-release/extensions.json 2>/dev/null | cat"
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
snapshot secur_cfg "Kerberos check (klist)" klist
snapshot secur_cfg "Kerberos check (klist -k -Ke)" klist -k -Ke
snapshot secur_cfg "Kerberos config" bash -c "cat /etc/krbr5.* 2>/dev/null"
snapshot secur_cfg "Kerberos tmp files" bash -c "ls /tmp 2>/dev/null | grep krb"

# Проверка конфига SSH
snapshot secur_cfg "SSH config check" cat /etc/ssh/sshd_config

# Проверка logrotate
snapshot secur_cfg "logrotate conf" bash -c "cat /etc/logrotate.conf"
snapshot secur_cfg "logrotate.d conf" bash -c "more /etc/logrotate.d/* 2>/dev/null | cat"

# Конфигурация syslog-ng, rsyslog, syslogd,audispd
snapshot secur_cfg "Syslog-ng conf" bash -c "more /etc/syslog-ng/*.conf 2>/dev/null | cat"
snapshot secur_cfg "Syslog conf" cat /etc/syslog.conf
snapshot secur_cfg "rsyslog conf" cat /etc/rsyslog.conf
snapshot secur_cfg "rsyslog.d conf" bash -c "more /etc/rsyslog.d/*.conf 2>/dev/null | cat"
snapshot secur_cfg "audispd conf (syslog)" cat /etc/audit/plugins.d/syslog.conf
snapshot secur_cfg "audispd conf (audisp)" cat /etc/audisp/plugins.d/syslog.conf

# Проверка правил аудита - сам конфиг и правила аудита? + посмотрим что по факту
snapshot secur_cfg "auditd conf" cat /etc/audit/auditd.conf
snapshot secur_cfg "audit rules.d" bash -c "more /etc/audit/rules.d/* 2>/dev/null | cat"
snapshot secur_cfg "audit.rules" cat /etc/audit/audit.rules
snapshot secur_cfg "auditd loaded rules" auditctl -l
snapshot secur_cfg "auditd status" auditctl -s

# Проверка целостности
snapshot secur_cfg "SSH config check" cat /etc/afick.conf

# SElinux проверки
snapshot secur_cfg "SElinux status check" sestatus
snapshot secur_cfg "getenforce" getenforce
snapshot secur_cfg "selinux config" cat /etc/selinux/config
snapshot secur_cfg "semodule -l" bash -c "sudo -n semodule -l 2>/dev/null"
snapshot secur_cfg "getsebool -a" getsebool -a
snapshot secur_cfg "semanage boolean" bash -c "semanage boolean -l 2>/dev/null"

echo "[Apparmor checks]"  
# APP armor checks
snapshot secur_cfg "Apparmor checks (apparmor_status)" apparmor_status
snapshot secur_cfg "Apparmor checks (aa-status)" aa-status
snapshot secur_cfg "Apparmor dirs" bash -c "ls -d /etc/apparmor* 2>/dev/null"
snapshot secur_cfg "Apparmor configs" bash -c "more /etc/apparmor.d/* 2>/dev/null | cat"
snapshot secur_cfg "Netstat with Z - extended security attributes" bash -c "netstat -anpZ 2>/dev/null"
snapshot secur_cfg "ps auxZe" bash -c "ps auxZe 2>/dev/null"
snapshot secur_cfg "pam.conf" cat /etc/pam.conf
snapshot secur_cfg "pam.d conf" bash -c "more /etc/pam.d/* 2>/dev/null | cat"
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
snapshot virt_apps_file "Проверка Virtualbox" bash -c "apt list --installed 2>/dev/null | grep virtualbox"
snapshot virt_apps_file "Проверка KVM" virsh list --all

# А вот так можем посмотреть логи QEMU, в том числе и об активности виртуальных машин
snapshot virt_apps_file "Проверка логов QEMU" bash -c "more /home/*/.cache/libvirt/qemu/log/* 2>/dev/null | cat"

# иногда wine будет создавать здесь конфиг...
snapshot virt_apps_file "Проверка Wine (list-installed)" winetricks list-installed
snapshot virt_apps_file "Проверка Wine (settings)" winetricks settings list
snapshot virt_apps_file "Wine program_files" ls -lta /home/*/.wine/drive_c/program_files
snapshot virt_apps_file "Wine Program" ls -lta /home/*/.wine/drive_c/Program
snapshot virt_apps_file "Wine Program Files" ls -lta /home/*/.wine/drive_c/Program\ Files
snapshot virt_apps_file "Wine Program (alt)" ls -lta /home/*/.wine/drive_c/Program

# Артефакты LXC
if command -v lxc >/dev/null 2>&1; then
	#snapshot virt_apps_file "LXC Info" lxc info
	snapshot virt_apps_file "LXC List All Projects" lxc list --all-projects --format compact
	snapshot virt_apps_file "LXC Image List" lxc image list --format compact 
fi

# Артефакты containerd : /etc/containerd/* и /var/lib/containerd/
snapshot virt_apps_file "containerd version" containerd --version
snapshot virt_apps_file "podman ps" podman ps
snapshot virt_apps_file "crictl ps" crictl ps

snapshot virt_apps_file "GRUB menu entries" bash -c "awk -F\\' '/menuentry / {print \$2}' /boot/grub/grub.cfg 2>/dev/null"
snapshot virt_apps_file "GRUB config" cat /boot/grub/grub.cfg
snapshot virt_apps_file "Проверка загрузочных ОС" os-prober
snapshot virt_apps_file "Проверка сборок ядра" bash -c "ls /boot 2>/dev/null | grep vmlinuz-"
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
snapshot history_info "Время работы системы, количество залогиненных пользователей" uptime
snapshot history_info "Журнал перезагрузок (last -x reboot)" last -x reboot
snapshot history_info "Журнал выключений (last -x shutdown)" last -x shutdown
# Список последних входов в систему с указанием даты (/var/log/lastlog)
snapshot history_info "Список последних входов в систему (/var/log/lastlog)" lastlog
# Список последних залогиненных юзеров (/var/log/wtmp), их сессий, ребутов и включений и выключений
snapshot history_info "Список последних залогиненных юзеров с деталями (/var/log/wtmp)" last -Faiwx
snapshot history_info "Последние команды из fc текущего пользователя" bash -c "fc -li 1 2>/dev/null"
# history -a
# Аналог команды history, выводит список последних команд, выполненных текущим пользователем в терминале
snapshot history_info "Последние команды из fc текущего пользователя (вер. 2)" bash -c "fc -l 1"

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
# Для любителей повершелла - история команд powershell
# Например, .nano_history,mysql_history итд
if ls /root/.*_history >/dev/null 2>&1; then
	snapshot history_info "История Root (/root/.*history)" bash -c "more /root/.*history | cat"
	# Для любителей повершелла - история команд powershell
	snapshot history_info "История Root powershell PSReadline" bash -c "more /root/.local/share/powershell/PSReadline/* 2>/dev/null | cat"
fi
snapshot history_info "История пользователей (.*history)" bash -c 'for name in $(ls /home); do echo "--- chage $name ---"; chage -l $name 2>/dev/null; echo "--- history $name ---"; more /home/$name/.*history 2>/dev/null | cat; more /home/$name/.local/share/powershell/PSReadline/* 2>/dev/null | cat; done'

# История установки пакетов. Также можно грепать в файлах /var/log/dpkg.log*, например
if [ -f /var/log/dpkg.log ]; then 
	snapshot history_info "История установленных приложений из /var/log/dpkg.log" bash -c "grep 'install ' /var/log/dpkg.log"

	# История установки пакетов в архивных логах. Для поиска во всех заархивированных системных логах исправь dpkg.log на *
	snapshot history_info "Архив истории установленных приложений из /var/log/dpkg.log.gz" bash -c "zcat /var/log/dpkg.log.gz 2>/dev/null | grep 'install '"

	snapshot history_info "История обновленных приложений из /var/log/dpkg.log" bash -c "grep 'upgrade ' /var/log/dpkg.log"

	snapshot history_info "История удаленных приложений из /var/log/dpkg.log" bash -c "grep 'remove ' /var/log/dpkg.log"

else
	echo "[Файл /var/log/dpkg.log не найден!]" 
fi

snapshot history_info "История apt-действий (history.log)" cat /var/log/apt/history.log

snapshot dpkg_status "DPKG Status" cat /var/lib/dpkg/status

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
snapshot network_info "IP адрес(а)" ip a
snapshot network_info "Настройки сети" ifconfig -a
snapshot network_info "Маршруты и правила IPv4/v6" bash -c "ip -4 route ls 2>/dev/null; ip -4 rule ls 2>/dev/null"
snapshot network_info "Маршруты и правила IPv6" bash -c "ip -6 route ls 2>/dev/null; ip -6 rule ls 2>/dev/null"
snapshot network_info "Сетевые интерфейсы (конфиги)" bash -c "cat /etc/network/interfaces 2>/dev/null; more /etc/network/interfaces.d/* 2>/dev/null | cat; cat /etc/sysconfig/network 2>/dev/null"
snapshot network_info "Настройки DNS" bash -c "cat /etc/resolv.conf; cat /etc/host.conf 2>/dev/null"
snapshot network_info "Сети (/etc/networks)" cat /etc/networks
snapshot network_info "Сетевой менеджер (nmcli)" nmcli
snapshot network_info "Беспроводные сети (iwconfig)" iwconfig
snapshot network_info "Информация из hosts" cat /etc/hosts
snapshot network_info "Сетевое имя машины" cat /etc/hostname
snapshot network_info "Сохраненные VPN ключи" ip xfrm state list
snapshot network_info "ARP таблица" arp -e

snapshot network_info "ARP Table (ip neigh)" ip neighbor show
snapshot network_info "Network Interfaces" ip link show

# ip n 2>/dev/null
snapshot network_info "Таблица маршрутизации" ip r
snapshot network_info "Проверка proxy (http_proxy)" bash -c "echo \$http_proxy"
snapshot network_info "Проверка proxy (https_proxy)" bash -c "echo \$https_proxy"
snapshot network_info "Проверка proxy (env | grep proxy)" bash -c "env | grep proxy"
snapshot network_info "Проверка интернета (ping)" bash -c "ping -c2 google.com"
snapshot network_info "Внешний IP-адрес (wget)" bash -c "wget -T 2 -O- https://api.ipify.org 2>/dev/null"
# Аналог:
snapshot network_info "Внешний IP-адрес (curl)" bash -c "curl ifconfig.co 2>/dev/null"
# База аренд DHCP-сервера (файлы dhcpd.leases). Гламурный аналог — утилита dhcp-lease-list
snapshot network_info "Проверка DHCP (dhcp)" bash -c "more /var/lib/dhcp/* 2>/dev/null | cat"
# Основные конфиги DHCP-сервера (можно сразу убрать из вывода все строки, начинающиеся с комментариев, и посмотреть именно актуальный конфиг, если тебе это надо, конечно)
snapshot network_info "DHCP конфиги" bash -c "more /etc/dhcp/* 2>/dev/null | cat | grep -vE ^"
# В логах смотрим инфу о назначенном адресе по DHCP
snapshot network_info "DHCP in logs (lease, dhcp)" bash -c "journalctl | grep -iE ' lease|dhcp'"
snapshot network_info "Сетевые процессы и сокеты" netstat -anlp
# Актуальная альтернатива netstat, выводит имена процессов (если запуск от суперпользователя) с текущими TCP/UDP-соединениями
snapshot network_info "TCP/UDP соединения (ss)" ss -tuplna
snapshot network_info "Количество полуоткрытых соединений" bash -c "netstat -tan 2>/dev/null | grep -c -i syn"
snapshot network_info "Сетевые соединения (lsof -Pi)" lsof -Pi

} >> network_info 

{
# Незамысловатый карвинг из логов сетевых соединений
snapshot network_add_info "Network connections list - connection" bash -c "journalctl -u NetworkManager | grep -i \"connection '\""
snapshot network_add_info "Network connections list - addresses" bash -c "journalctl -u NetworkManager | grep -i address"
snapshot network_add_info "Network connections wifi enabling" bash -c "journalctl -u NetworkManager | grep -i wi-fi"
snapshot network_add_info "Network connections internet" bash -c "journalctl -u NetworkManager | grep -i global -C2"
# Сети Wi-Fi, к которым подключались
snapshot network_add_info "wifi networks info (psk)" bash -c "grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null"
# Альтернатива
snapshot network_add_info "NetworkManager connections full" bash -c "cat /etc/NetworkManager/system-connections/* 2>/dev/null"
# collect "iptables" information
snapshot network_add_info "Firewall iptables-save" iptables-save
snapshot network_add_info "Firewall iptables -n -L -v" bash -c "iptables -n -L -v --line-numbers 2>/dev/null"
snapshot network_add_info "Firewall iptables -S" iptables -S
# collect "ip6tables" information
snapshot network_add_info "Firewall ip6tables-save" ip6tables-save
snapshot network_add_info "Firewall ip6tables -n -L -v" bash -c "ip6tables -n -L -v --line-numbers 2>/dev/null"
snapshot network_add_info "Firewall ip6tables -S" ip6tables -S

# NAT rules
snapshot network_add_info "IPv4 NAT Rules" iptables -t nat -L -v -n
snapshot network_add_info "IPv6 NAT Rules" ip6tables -t nat -L -v -n

# Список правил файрвола nftables
snapshot network_add_info "Firewall nftables" bash -c "nft list ruleset 2>/dev/null"
# alt:  /usr/sbin/nft list ruleset 2>/dev/null
# ufw status
snapshot network_add_info "UFW rules (status)" ufw status verbose
snapshot network_add_info "UFW rules (show added)" ufw show added
# firewalld
snapshot network_add_info "Firewalld" bash -c "firewall-cmd --list-all-zones 2>/dev/null"
# wireguard
snapshot network_add_info "Wireguard wg show" bash -c "wg show 2>/dev/null; ip link show 2>/dev/null"
# dns journalctl check
snapshot network_add_info "DNS journalctl" bash -c "resolvectl statistics 2>/dev/null; cat /etc/systemd/resolved.conf 2>/dev/null"
# fail2ban
snapshot network_add_info "fail2ban" bash -c "fail2ban-client status 2>/dev/null; cat /etc/fail2ban/jail.* 2>/dev/null"
# net namespace
snapshot network_add_info "net namespace" ip netns list

} >> network_add_info


if [[ "$SEARCH_IPS_LOGS" -gt 0 ]] || [[ "$SEARCH_IPS" -gt 0 ]] && [[ "${#ips[@]}" -gt 0 ]]; then
echo -e "${blue}[Поиск IP-адресов...]${clear}"

{

if [[ "$SEARCH_IPS_LOGS" -gt 0 ]]; then
# Ищем IP-адреса в логах и выводим список
echo "Search IP-adresses in journalctl:" 
echo -e "\n" 
journalctl | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]| sudo [01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' | sort |uniq
echo -e "\n" 
echo "Search IP-adresses in journalctl:" 
grep -a -r -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' /var/log | sort | uniq
echo -e "\n" 
fi

# Ищем айпишник в логах или конфигах приложений, как вариант
if [[ "$SEARCH_IPS" -gt 0 ]] && [[ "${#ips[@]}" -gt 0 ]]; then
	echo "[Ищем IP-адреса в текстовых файлах...]"
	for f in ${ips[@]};
	do
		echo "Search IP-adresses: $f" 
		echo -e "\n" 
		grep -a -C2 -F -rn $f --exclude="*ifrit.sh" --exclude-dir=$saveto /usr /etc /var 2>/dev/null 
	done
fi

# Как вариант подсчёта встречаемости для accesslogs
# https://www.jaiminton.com/cheatsheet/DFIR/#size-of-file-bytes
# cut -d " " -f 1 access.log | sort -u | wc -l

} >> ip_search_info

fi 

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

snapshot activity_info "Top 10 Memory Consuming Processes" bash -c "ps -eo pid,ppid,comm,cmd,%mem,%cpu --sort=-%mem 2>/dev/null | head" 

# Вывод запущенных графических приложений
# можно вывести и всё, что привязано к дисплею:
# xlsclients | sort | uniq
snapshot activity_info "Running GUI apps" bash -c "xlsclients 2>/dev/null | awk '{print \$2}' | sort | uniq"
# происходят фризы
snapshot activity_info "Running GUI apps from xwininfo" bash -c "[ "$EUID" -ne 0 ] && xwininfo -root -children || echo Not executed because of root"

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
snapshot activity_info "Список активных сессий (Screen)" screen -ls
snapshot activity_info "Фоновые задачи (jobs)" jobs
snapshot activity_info "Задачи в планировщике (Crontab)" crontab -l
} >> activity_info 

echo -e "${magenta}[Анализ планировщиков]${clear}"
{
snapshot cronconfigs_info "Crontab в /etc/cron*" bash -c "more /etc/cron*/* 2>/dev/null | cat"
snapshot cronconfigs_info "Crontab всех юзеров" bash -c 'for user in $(ls /home/); do echo "[Crontabs for $user]"; crontab -u $user -l 2>/dev/null; done'
snapshot cronconfigs_info "Лог планировщика /var/log/cron.log*" bash -c 'for f in /var/log/cron.log*; do case $f in *.gz) zcat "$f" 2>/dev/null;; *) cat "$f" 2>/dev/null;; esac; done'
snapshot cronconfigs_info "Общедоступный крон" bash -c "find /etc/cron* -type f -perm -o+w -exec ls -l {} \;"
} >> cronconfigs_info

{
snapshot activity_info "Crontab в /etc/crontab" cat /etc/crontab
snapshot activity_info "Автозагрузка .desktop" ls -lta /etc/xdg/autostart
snapshot activity_info "Автозапуски xdg (Exec=)" bash -c "cat /etc/xdg/autostart/* 2>/dev/null | grep 'Exec='"
snapshot activity_info "Автозагрузка GNOME/KDE" bash -c "more /home/*/.config/autostart/*.desktop 2>/dev/null | cat"

# Список всех запущенных процессов, лучше класть в отдельный файлик
snapshot activity_info "Список процессов (ROOT)" ps -l

# Процессы - детализированный список в древовидном формате
snapshot activity_info "Process Tree" ps auxwwwwf
} >> activity_info

{
# Гламурный вывод дерева процессов
snapshot pstree_file "Дерево процессов" pstree -aups
#pstree -Aup 
# Текстовый вывод аналога виндового диспетчера задач
snapshot pstree_file "Инфа о процессах через top" top -bcn1 -w512
snapshot pstree_file "Список процессов (все)" ps -auxw
#ps aux 
#ps -eaf
snapshot pstree_file "Список процессов (дерево)" ps auxwf
} >> pstree_file

echo -e "${magenta}[Анализ активности]${clear}"
{
# Проверка почтовых правил - часто используется для скрытого мониторинга почты злоумышленниками
snapshot activity_info "R7-office mail rules и Thunderbird mail rules" bash -c '
for usa in $(ls /home); do
    echo "--- R7-organizer mail rules for $usa ---"
    more /home/$usa/.r7organizer/*.default-default/*Mail/*/*msgFilterRules.dat 2>/dev/null | cat
    more /home/$usa/.r7organizer/*.default/*Mail/*/*msgFilterRules.dat 2>/dev/null | cat
    echo "--- Thunderbird mail rules for $usa ---"
    more /home/$usa/.thunderbird/*.default-release/*Mail/*/msgFilterRules.dat 2>/dev/null | cat
    more /home/$usa/.thunderbird/*.default/*Mail/*/msgFilterRules.dat 2>/dev/null | cat
done
'
snapshot activity_info "Вывод задач в бэкграунде atjobs" ls -lta /var/spool/cron/atjobs
snapshot activity_info "Вывод jobs из var/spool/at" bash -c "more /var/spool/at/* 2>/dev/null | cat"
snapshot activity_info "Файлы deny/allow для cron/at" bash -c "more /etc/at.* 2>/dev/null | cat"
snapshot activity_info "Вывод задач Anacron" bash -c "more /var/spool/anacron/cron.* 2>/dev/null | cat"

} >> activity_info 

{
snapshot rc_scripts "Скрипты автозапуска rc" bash -c "more /etc/rc*/* 2>/dev/null | cat; more /etc/rc.d/* 2>/dev/null | cat"
} >> rc_scripts


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
# systemctl list-units --type=service --state=running
snapshot services_info "Список активных служб systemd" systemctl list-units --no-pager

# можно отдельно посмотреть модули ядра: cat /etc/modules.conf и cat /etc/modprobe.d/*
snapshot services_info "Список всех служб" systemctl list-unit-files --type=service --no-pager
snapshot services_info "Статус всех служб (service)" service --status-all
# To list software from a terminal
snapshot services_info "systemctl -a" systemctl -a --no-pager
# Units
snapshot services_info "systemctl status" systemctl status

snapshot services_info "Список сервисов (init)" ls -lta /etc/init
snapshot services_info "Сценарии init.d" ls -lta /etc/init.d

} >> services_info 

{
snapshot services_configs "systemctl loading" systemd-analyze
snapshot services_configs "systemctl critical unit chain" systemd-analyze critical-chain
snapshot services_configs "systemctl unit-paths system" systemd-analyze unit-paths
snapshot services_configs "systemctl unit-paths user" systemd-analyze unit-paths --user
snapshot services_configs "systemd-analyze blame" systemd-analyze blame --no-pager
snapshot services_configs "Конфиги сервисов" bash -c "more /etc/systemd/system/*.service 2>/dev/null | cat"

snapshot services_configs "Systemd Service Units" bash -c "more /lib/systemd/system/*.service 2>/dev/null || cat /lib/systemd/system/*.service 2>/dev/null"
snapshot services_configs "Systemd Timer Units" bash -c "more /lib/systemd/system/*.timer 2>/dev/null || cat /lib/systemd/system/*.timer"
} >> services_configs

# <<< Заканчиваем писать файл services_info
# ----------------------------------
# ----------------------------------

# ----------------------------------
# ----------------------------------
# Начинаем писать файл devices_info >>>

echo -e "${magenta}[Информация об устройствах]${clear}"
{
# Вывод инфо о PCI-шине
snapshot devices_info "Информация об устройствах (lspci)" lspci
# printers check
snapshot devices_info "Any printers?" lpstat -a
snapshot devices_info "Устройства USB (lsusb)" lsusb
snapshot devices_info "Блочные устройства (lsblk)" lsblk
# more /sys/bus/pci/devices/*/* | cat
snapshot devices_info "Список примонтированных ФС (findmnt)" findmnt
snapshot devices_info "Bluetooth устройства (bt-device -l)" bt-device -l
snapshot devices_info "Bluetooth устройства (hcitool dev)" hcitool dev
snapshot devices_info "Bluetooth устройства (/var/lib/bluetooth)" ls -ltaR /var/lib/bluetooth

snapshot devices_info "Другие устройства из journalctl (PCI/ACPI/Plug)" bash -c "journalctl 2>/dev/null | grep -i 'PCI|ACPI|Plug'"
snapshot devices_info "Подключение сетевого кабеля из journalctl" bash -c "journalctl 2>/dev/null | grep 'NIC Link is'"

# Открытие/закрытие крышки ноутбука
snapshot devices_info "LID open-downs из journalctl" bash -c "journalctl 2>/dev/null | grep Lid"

snapshot devices_info "CPU Stats (mpstat)" mpstat

    if command -v pvdisplay >/dev/null 2>&1; then
        snapshot devices_info  "LVM Physical Volumes" pvdisplay 
        snapshot devices_info  "LVM Volume Groups" vgdisplay
        snapshot devices_info  "LVM Logical Volumes" lvs
    else
        snapshot devices_info  "LVM Info" bash -c "echo 'LVM утилиты (pvdisplay/vgdisplay/lvs) не найдены'" 
    fi

} >> devices_info 

{
# Пример usbrip, если он установлен
# https://github.com/snovvcrash/usbrip
snapshot usb_list_file "Устройства USB (usbrip)" usbrip events history

# Подключенные в текущей сессии USB-устройства — у Linux аптайм обычно большой, может, прокатит
snapshot usb_list_file "Устройства USB из dmesg" bash -c "dmesg | grep -i usb 2>/dev/null"

# Usbrip делает то же самое, но потом обрабатывает данные и делает красиво
snapshot usb_list_file "Устройства USB из journalctl" bash -c "journalctl | grep -i usb"
# journalctl -o short-iso-precise | grep -iw usb

snapshot usb_list_file "Устройства USB из syslog (SerialNumber)" bash -c "cat /var/log/syslog* 2>/dev/null | grep -i usb | grep -A1 -B2 -i SerialNumber:"

snapshot usb_list_file "Устройства USB из messages (SerialNumber)" bash -c "cat /var/log/messages* 2>/dev/null | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null"

# Как ты понимаешь, устройства в текущей сессии имеет смысл собирать, только если система давно не перезагружалась
snapshot usb_list_file "Устройства USB (dmesg SerialNumber)" bash -c "dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber:"
snapshot usb_list_file "Устройства USB (journalctl SerialNumber)" bash -c "journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber:"

} >> usb_list_file

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
snapshot env_profile_info "Глобальные переменные среды ОС (env)" env
snapshot env_profile_info "Все текущие переменные среды (printenv)" printenv
snapshot env_profile_info "Переменные шелла (set)" set
snapshot env_profile_info "Расположение исполняемых файлов шеллов" cat /etc/shells

if [ -e "/etc/profile" ] ; then
    snapshot env_profile_info "Содержимое /etc/profile" cat /etc/profile
fi

if [ -e "/etc/bashrc" ] ; then
    snapshot env_profile_info "Содержимое /etc/bashrc" cat /etc/bashrc
fi

if [ -e "/etc/bash.bashrc" ] ; then
    snapshot env_profile_info "Содержимое /etc/bash.bashrc" cat /etc/bash.bashrc
fi

snapshot env_profile_info "Runlevel" runlevel

} >> env_profile_info

{
echo "[File contents of /home/users/.*]" 
for name in $(ls /home); do
    #more /home/$name/.*_profile 2>/dev/null | cat 
	echo Hidden config-files for: $name 
	more /home/$name/.* 2>/dev/null | cat  
    echo -e "\n" 
done

snapshot users_cfgs "Лимиты" ulimit -a
} >> users_cfgs

{

echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
# Список файлов, пример
#.*_profile (.profile)
#.*_login
#.*_logout
#.*rc
#.*history 
snapshot root_cfg "ROOT hidden configs /root/.*" bash -c 'more /root/.* 2>/dev/null | cat'
} >> root_cfg

{
snapshot env_profile_info "Пользователи SUDO" cat /etc/sudoers
snapshot env_profile_info "Пользователи SUDO (sudoers.d)" bash -c 'more /etc/sudoers.d/* 2>/dev/null | cat'
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
snapshot susp_chk "Check for /dev/null links in /var/log" bash -c 'ls -lar /var/log/ 2>/dev/null | grep "/dev/null"'
snapshot susp_chk "Check for /dev/null links in /root" bash -c 'ls -lar /root/ 2>/dev/null | grep "/dev/null"'
snapshot susp_chk "Check for /dev/null links in /home" bash -c 'ls -lar /home/*/.* 2>/dev/null | grep "/dev/null"'

# 1.1 Файлы пишут в /dev/null
snapshot susp_chk "Файлы с выводом в /dev/null" lsof -w /dev/null

# 2. Ключевые файлы для определения активности больше не пишутся, так как находятся в Immutable режиме
# Inspired by https://forumsoc.ru/reports/file/73/
# check HIGHLY suspicious immutable bit set
# used by attackers to disable logs and history
snapshot susp_chk "Check for immutable bit in /var/log" bash -c 'lsattr -R /var/log/ 2>/dev/null | grep -- "-i-"'
snapshot susp_chk "Check for immutable bit in /root" bash -c 'lsattr -R /root/ 2>/dev/null | grep -- "-i-"'
snapshot susp_chk "Check for immutable bit in /home" bash -c 'lsattr -R /home/*/.* 2>/dev/null | grep -- "-i-"'

# 3. Потенциальное место для закрепления - запуск команд при подключении устройств
snapshot susp_chk "Device connection scripts" bash -c 'more /etc/udev/rules.d/* 2>/dev/null | cat'

# 4. Смотрим процессы, путь к исполняемым файлам которых скрыт
# show processes with executable in HIDDEN location or with HIDDEN name:
snapshot susp_chk "SUSPICIOUS process started or named hidden" bash -c 'ps ax -o pid,user,cmd | grep "/\."'

# 5. Пытаемся выявить процессы, которые маскируются под потоки ядра
snapshot susp_chk "Suspicious kernel process masquerading" bash -c 'ps auxww | grep \\[ | awk '\''{print $2}'\'' | xargs -I % sh -c '\''rev /proc/%/maps 2>/dev/null | cut -d " " -f1 | rev | sort | uniq | xargs -0 --no-run-if-empty echo -e "$(ps -p % -o pid=,user=,cmd=)\n"'\'' | sort | uniq'

# 6. Запущенные процессы с удалённым исполняемым файлом
snapshot susp_chk "Processes with deleted executable" bash -c 'find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted'

# 7. Processes runned from memory via memfd_create():
snapshot susp_chk "Processes runned from memory via memfd_create" bash -c 'ls -alR /proc/*/exe 2> /dev/null | grep memfd:.*\(deleted\)'

# 8. Неудачные попытки входа - мб был брутик
if [ -e /var/log/btmp ]; then
    snapshot susp_chk "Last LOGIN fails: lastb" lastb
fi

snapshot susp_chk "LD_PRELOAD and LD_AUDIT check" bash -c 'cat /proc/*/environ 2>/dev/null | grep -a -o "LD_PRELOAD\|LD_AUDIT"'
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

snapshot junk_info "Timedatectl Status" timedatectl status 

snapshot junk_info "Иерархия контрольных групп systemd" systemd-cgls --no-pager

# Вдруг в буфере что-то интересненькое))
# clipboard check by https://book.hacktricks.xyz/linux-hardening/privilege-escalation
echo "[Clibboard smth?]"
if [ `command -v xclip 2>/dev/null` ]; then
    echo "Clipboard: "`xclip -o -selection clipboard 2>/dev/null`
    echo "Highlighted text: "`xclip -o 2>/dev/null`
  elif [ `command -v xsel 2>/dev/null` ]; then
    echo "Clipboard: "`xsel -ob 2>/dev/null`
    echo "Highlighted text: "`xsel -o 2>/dev/null`
  else echo "No applicable clipboard =(. Not found xsel and xclip"
  fi
 echo -e "\n"  

# inter-process communication status (active message queues, semaphore sets, shared memory segments)
snapshot junk_info "Inter-proc communication stats" ipcs -a

# Проверимся на руткиты, иногда помогает
snapshot junk_info "Проверка на rootkits chkrootkit" chkrootkit

# systemd dumps listing
snapshot junk_info "Перечень крашдампов" coredumpctl list
snapshot junk_info "Coredump directory listing" ls -la /var/lib/systemd/coredump

# OS specific — Astra Linux Closed Software Environment mode
if [ -f /sys/digsig/elf_mode ]; then
    snapshot junk_info "AstraLinux - protected software mode (elf_mode)" cat /sys/digsig/elf_mode
    snapshot junk_info "AstraLinux - protected software mode (xattr_mode)" cat /sys/digsig/xattr_mode
fi

} >> junk_info

if [[ "$SEARCH_IOC_FILES" -gt 0 ]] && [[ "${#iocfiles[@]}" -gt 0 ]]; then
	echo -e "${yellow}[Файловые IOC?]${clear}"
	echo "[IOC-paths?]" >> junk_info
	echo -e "\n" >> junk_info
	# https://www.welivesecurity.com/2017/04/25/linux-shishiga-malware-using-lua-scripts/

	counter=0
	for f in "${iocfiles[@]}"
	do
		echo -e "Проверка наличия файла $f..."
		if [ -e "$f" ]
		then
			counter=$((counter+1))
			echo -e "${red}IOC-path found: ${clear}" "$f"
			echo "IOC-path found: " "$f" >> junk_info
			echo -e "\n" >> junk_info
		fi
	done

	if [ $counter -gt 0 ]
	then 
		echo -e "${red}IOC Markers found!!${clear}" 
		echo "IOC Markers found!!" >> junk_info
		echo -e "\n" >> junk_info
	fi
fi
# ниже идут команды, которые применялись в самой первой версии скрипта, который представлял собой безумную компиляцию из кучи команд без особого понимания в их необходимости. но в части ресурсов, книг и других скриптов они, возможно, были...
# ...а теперь мне просто западло их убирать

echo -e "${yellow}[i am alive, just processing...]${clear}"

{
# time information diff maybe?
snapshot junk_info "BIOS TIME" hwclock -r
snapshot junk_info "SYSTEM TIME" date

# privilege information
snapshot junk_info "All users /etc/passwd" cat /etc/passwd

# ssh keys — root
snapshot junk_info "SSH root authorized_keys" cat /root/.ssh/authorized_keys
snapshot junk_info "SSH root known_hosts" cat /root/.ssh/known_hosts
snapshot junk_info "SSH root config" cat /root/.ssh/config

#for users:
echo "[Additional info cat ssh (users) keys and hosts]" 
for name in $(ls /home)
do
echo "[SSH-files for: $name]"
cat /home/$name/.ssh/authorized_keys 2>/dev/null 
echo -e "\n" 
cat /home/$name/.ssh/known_hosts 2>/dev/null 
echo -e "\n" 
cat /home/$name/.ssh/config 2>/dev/null 
done
echo -e "\n" 

# VM detection
snapshot junk_info "Virtual Machine Detection (manufacturer)" dmidecode -s system-manufacturer
snapshot junk_info "Virtual Machine Detection (full)" dmidecode

# Nginx collection
snapshot junk_info "Nginx Info" echo "=== Nginx ==="
if [ -e "/usr/local/nginx" ]; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
    snapshot junk_info "Nginx archive" echo "Grab NGINX files!"
fi

# Apache2 collection
snapshot junk_info "Apache Info" echo "=== Apache ==="
if [ -e "/etc/apache2" ]; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/apache2 2>/dev/null
    snapshot junk_info "Apache archive" echo "Grab APACHE files!"
fi

snapshot junk_info "Loaded core modules - lsmod" lsmod

snapshot junk_info "Пустые пароли" bash -c 'cat /etc/shadow | awk -F: '\''($2==""){print $1}'\'''

# Malware collection
# .bin
#echo "[BIN FILETYPE]" 
#find / -name \*.bin 
#echo -e "\n" 

# .exe
#echo "[BIN FILETYPE]" 
#find / -name \*.exe 
#echo -e "\n" 

# find copied
# Find nouser or nogroup  data
# check for files without holder
# find / -xdev \( -nouser -o -nogroup \) -print
# check for files without holder
# find / \( -perm -4000 -o -perm -2000 \) -print

snapshot junk_info "NOUSER files" find /root /home -nouser
snapshot junk_info "NOGROUP files" find /root /home -nogroup
} >> junk_info

{
snapshot lsof_file "Currently open files: lsof -n" lsof -n
snapshot lsof_file "Verbose open files: lsof -V" lsof -V
snapshot lsof_file "Opened Files for Read/Write" bash -c "lsof 2>/dev/null | awk 'NR==1 || \$4~/[0-9][uwr]/' | grep REG "
snapshot lsof_file "UNIX IPC Sockets" lsof -U 
snapshot lsof_file "Listening Ports" lsof -nPli
} >> lsof_file


# super errors mode:
# journalctl -o verbose -p 4 
snapshot journalctlq "Query journal: journalctl" journalctl -xe -n 10000
##journalctl -o export > journal-exp.txt

{
if [ -e /var/log/wtmp ]; then
    snapshot junk_info "Login logs and reboot: last -f /var/log/wtmp" last -f /var/log/wtmp
fi

if [ -e /etc/inetd.conf ]; then
    snapshot junk_info "inetd.conf" cat /etc/inetd.conf
fi

snapshot junk_info "Repo info: apt sources.list" bash -c 'more /etc/apt/sources.list* 2>/dev/null | cat'
snapshot junk_info "Repo info: apt sources.list subdirs" bash -c 'more /etc/apt/sources.list*/* 2>/dev/null | cat'
snapshot junk_info "Static file system: /etc/fstab" cat /etc/fstab

# echo "Begin Additional Sequence Now *********************************"

# Virtual memory statistics
snapshot junk_info "Virtual memory state: vmstat" vmstat
snapshot junk_info "Virtual memory state: vmstat disks" vmstat -D
snapshot junk_info "Virtual memory state: vmstat memory" vmstat -s

# Check for hardware events
snapshot junk_info "HD devices check: dmesg | grep hd" bash -c 'dmesg | grep -i hd 2>/dev/null'

# Show activity log
snapshot junk_info "USB check: /var/log/messages" bash -c 'cat /var/log/messages 2>/dev/null | grep -i usb 2>/dev/null'

# List all mounted files and drives
# List all mounted files and drives
snapshot junk_info "Mounted files: ls -lat /mnt" ls -lat /mnt

# systemd configuration options
snapshot junk_info "Logind config" cat /etc/systemd/logind.conf

# System config info junk
snapshot junk_info "/etc/mtab" cat /etc/mtab
snapshot junk_info "Disk usage: du -sh" du -sh
snapshot junk_info "Disk partition: fdisk -l" fdisk -l
snapshot junk_info "OS version: /proc/version" cat /proc/version
snapshot junk_info "Distribution: lsb_release" lsb_release
snapshot junk_info "Memory free" free -h

snapshot junk_info "Hardware: lshw" lshw
snapshot junk_info "Hardware info: cpuinfo" cat /proc/cpuinfo
snapshot junk_info "Hardware info: lscpu" lscpu
snapshot junk_info "Hardware info: meminfo" cat /proc/meminfo
snapshot junk_info "Profile parameters: /etc/profile.d" bash -c 'more /etc/profile.d/* 2>/dev/null | cat'
snapshot junk_info "Language locale" locale

# manual installed
snapshot junk_info "Manually installed packages (apt-mark)" apt-mark showmanual

#echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]"  
#aptitude search '!~M ~i'
#aptitude search -F %p '~i!~M'

# Copy root config artifacts
mkdir -p ./artifacts/config_root
#desktop icons and other_stuff
cp -r /root/.config ./artifacts/config_root 2>/dev/null 
#saved desktop sessions of users
cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

snapshot junk_info "VMware clipboard (root)" ls -ltaR /root/.cache/vmware/drag_and_drop/
snapshot junk_info "Mails of root" cat /var/mail/root
snapshot junk_info "Spool mails" bash -c 'cat /var/spool/mail/* 2>/dev/null'
snapshot junk_info "Recently-Used" bash -c 'more /home/*/.local/share/recently-used.xbel 2>/dev/null | cat'

#get mail for each user:
#echo "[Recently-Used]"  
#cat /var/mail/username$ 2>/dev/null 

#mini list of apps
snapshot junk_info "Var-LIBS directories" ls -lta /var/lib

# crypto stuff
snapshot junk_info "Encrypted data? /etc/crypttab" cat /etc/crypttab

# Default settings for user directories
snapshot junk_info "User dirs defaults" cat /etc/xdg/user-dirs.defaults     

#os info
snapshot junk_info "OS-release" cat /etc/os-release

#list boots 
snapshot junk_info "List of boots" journalctl --list-boots

#machine ID
snapshot junk_info "Machine-ID" cat /etc/machine-id

#GPG info
snapshot junk_info "GnuPG contains" bash -c 'ls -ltaR /home/*/.gnupg/* 2>/dev/null'

# Здесь можно встретить информацию в виде dat-файлов о состоянии батареи ноутбука, включая процент зарядки, расход и состояние отключения батарейки и ее заряда
#battery info for laptops
#history­charge­*.dat — log of percentage charged
# history­rate­*.dat — log of energy consumption rate
#history­time­empty­*.dat — when unplugged, log of time (in seconds) until empty
# history­time­full­*.dat — when charging, log of time (in seconds) until full
snapshot junk_info "Battery logs" bash -c 'more /var/lib/upower/* 2>/dev/null | cat'
snapshot junk_info "ac connected check" systemd-ac-power -v
snapshot junk_info "battery reduce check" systemd-ac-power -v --l
snapshot junk_info "UUID of partitions: blkid" blkid
snapshot junk_info "Volumes: vol*" bash -c 'more /media/data/vol* 2>/dev/null | cat'
} >> junk_info

{
snapshot dmesg "kernel messages: dmesg" dmesg -T
} >> dmesg

echo -e "${yellow}[Сбор информации о службах...]${clear}" 
{
snapshot kernel_params "sysctl -a (core parameters list)" /sbin/sysctl -a
snapshot kernel_params "/etc/security/limits.conf" cat /etc/security/limits.conf

snapshot kernel_params "Modprobe Configuration" cat /etc/modprobe.d/*.conf

# Modules
snapshot kernel_params "Modules listing" bash -c 'find /lib/modules -printf "%M\t%u\t%g\t%s\t%AY-%Am-%Ad-%AH:%AM\t%CY-%Cm-%Cd-%CH:%CM\t%TY-%Tm-%Td-%TH:%TM\t%P\n"'
} >> kernel_params

#COPY ALL WEB PROFILES FOR THE GOD!
echo -e "${magenta}[Web collection]${clear}"
{
echo "[Web collection start...]" 
snapshot junk_info "Сохранение профилей mozilla" bash -c 'for d in /home/*/.mozilla/firefox/; do [ -d "$d" ] && mkdir -p ./artifacts/mozilla && cp -r "$d" ./artifacts/mozilla 2>/dev/null; done'

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

snapshot junk_info "SSH service logs errors" bash -c 'journalctl _SYSTEMD_UNIT=sshd.service | grep "error" 2>/dev/null'
} >> junk_info

#echo "Get users Recent and personalize collection"
echo -e "${yellow}[Сбор информации о конфигурации пользователей...]${clear}" 
echo "Get users Recent and personalize collection (without Trash files)" >> junk_info

for usa in $users
do
	mkdir -p ./artifacts/share_user/$usa
	cp -r /home/$usa/.local/share ./artifacts/share_user/$usa 2>/dev/null 
	# because probably too large directory
    rm -r ./artifacts/share_user/$usa/Trash 2>/dev/null 
    rm -r ./artifacts/share_user/$usa/share/Trash/files 2>/dev/null 
done

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
	echo "[Mails of $usa]" 
	# alt: for x in "/var/mail"; do ls -lh "$x"; done
	cat /var/mail/$usa 2>/dev/null 
	echo -e "\n" 

	echo "[VMware clipboard (maybe)!]" 
	ls -ltaR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
	echo -e "\n" 
		
	} >> junk_info
done


{
# Check for misconfigurations from Cheatsheet
snapshot junk_info "Popular config check" echo "=== Popular config check ==="
snapshot junk_info "Samba config" cat /etc/samba/smb.conf
snapshot junk_info "Samba testparm" testparm -s
snapshot junk_info "chttp.conf" cat /etc/chttp.conf
snapshot junk_info "lighttpd.conf" cat /etc/lighttpd.conf
snapshot junk_info "cupsd.conf" cat /etc/cups/cupsd.conf
snapshot junk_info "inetd.conf" cat /etc/inetd.conf
snapshot junk_info "apache2.conf" cat /etc/apache2/apache2.conf
snapshot junk_info "my.conf" cat /etc/my.conf
snapshot junk_info "httpd.conf" cat /etc/httpd/conf/httpd.conf
snapshot junk_info "lampp httpd.conf" cat /opt/lampp/etc/httpd.conf

# get sendmail configuration files
snapshot junk_info "sendmail config" bash -c 'more /etc/mail/* 2>/dev/null | cat'

# get exim configuration files
snapshot junk_info "exim4 config" bash -c 'more /etc/exim4/* 2>/dev/null | cat'

# get postfix configuration files
snapshot junk_info "postfix config" bash -c 'cat /etc/postfix/*.cf 2>/dev/null'

# NOT incldable checks by kaspers'ky
# get listing of system directories
#ls -la / /tmp /opt /var /etc /usr 2>/dev/null
# get listing of system libs
#ls -la / /usr | grep lib 2>/dev/null
#ls -laL /lib*  2>/dev/null
#ls -laL /usr/lib* 2>/dev/null

#analyze ssl certs and keys
snapshot junk_info "SSL files" ls -ltaR /etc/ssl

snapshot junk_info "Log messages: /var/log/messages" cat /var/log/messages
} >> junk_info

# <<< Заканчиваем писать файл junk_info
# ----------------------------------
# ----------------------------------

# ----------------------------------
# ----------------------------------
# Начинаем писать файл persistence_check >>>
echo -e "${yellow}[Сбор потенциальных конфигураций для закрепления...]${clear}" 
{
# kasper best practices — system autorun persistence check
snapshot persistence_check "X11: xinitrc" cat /etc/X11/xinit/xinitrc
snapshot persistence_check "X11: xserverrc" cat /etc/X11/xinit/xserverrc
snapshot persistence_check "Anacrontab" cat /etc/anacrontab
snapshot persistence_check "bash.bash_logout" cat /etc/bash.bash_logout
snapshot persistence_check "bash.bashrc" cat /etc/bash.bashrc
snapshot persistence_check "incron files" bash -c 'more /etc/incron.d/* 2>/dev/null | cat'
snapshot persistence_check "init.d scripts" bash -c 'more /etc/init.d/* 2>/dev/null | cat'
snapshot persistence_check "inittab" cat /etc/inittab
snapshot persistence_check "ld.so.conf" cat /etc/ld.so.conf
snapshot persistence_check "ld.so.conf.d" bash -c 'more /etc/ld.so.conf.d/* 2>/dev/null | cat'
snapshot persistence_check "ld.so.preload" cat /etc/ld.so.preload
snapshot persistence_check "modules" cat /etc/modules
snapshot persistence_check "modules-load.d" bash -c 'more /etc/modules-load.d/* 2>/dev/null | cat'
snapshot persistence_check "profile" cat /etc/profile
snapshot persistence_check "profile.d" bash -c 'more /etc/profile.d/* 2>/dev/null'
snapshot persistence_check "rc.boot" cat /etc/rc.boot
snapshot persistence_check "rc.local" cat /etc/rc.local
snapshot persistence_check "systemd system units" bash -c 'more /etc/systemd/system/* 2>/dev/null | cat'
snapshot persistence_check "systemd system.conf" cat /etc/systemd/system.conf
snapshot persistence_check "lib systemd units" bash -c 'more /lib/systemd/system/* 2>/dev/null | cat'
snapshot persistence_check "udev rules" bash -c 'more /etc/udev/rules.d/* 2>/dev/null | cat'
snapshot persistence_check "update-motd.d" bash -c 'more /etc/update-motd.d/* 2>/dev/null | cat'
snapshot persistence_check "update.d" bash -c 'more /etc/update.d/* 2>/dev/null | cat'
snapshot persistence_check "XDG autostart" bash -c 'more /etc/xdg/autostart/* 2>/dev/null | cat'
snapshot persistence_check "LXDE autostart" cat /etc/xdg/lxsession/LXDE/autostart
snapshot persistence_check "motd.d" bash -c 'more /var/run/motd.d/* 2>/dev/null | cat'
snapshot persistence_check "anacron spool" bash -c 'more /var/spool/anacron/* 2>/dev/null | cat'
snapshot persistence_check "cron atjobs" cat /var/spool/cron/atjobs
snapshot persistence_check "cron crontabs" bash -c 'more /var/spool/cron/crontabs/* 2>/dev/null | cat'
snapshot persistence_check "incron spool" bash -c 'more /var/spool/incron/* 2>/dev/null | cat'
} >> persistence_check

# <<< Заканчиваем писать файл persistence_check
# ----------------------------------
# ----------------------------------

{
  # Находим все service-файлы в стандартных путях systemd
        service_files=$(
            find /etc/systemd/system /lib/systemd/system /run/systemd/system \
            -name "*.service" -type f 2>/dev/null | sort -u
        )
        
        if [ -z "$service_files" ]; then
            echo "Service-файлы не найдены"
            #exit 0
        else
        # Обрабатываем каждый найденный файл
        echo "$service_files" | while read -r service_file; do
            # Извлекаем имя сервиса из пути
            service_name=$(basename "$service_file")
            
            echo "========================================="
            echo "=== Путь: $service_file ==="
            echo "=== Статус: ==="
            
            # Получаем статус сервиса (если systemctl доступен)
            if command -v systemctl >/dev/null 2>&1; then
                systemctl status "$service_name" 2>/dev/null || \
                echo "Не удалось получить статус (возможно, сервис не загружен)"
            else
                echo "systemctl недоступен"
            fi
            
            echo ""
            echo "=== Содержимое unit-файла: ==="
            
            # Выводим содержимое файла
            if [ -r "$service_file" ]; then
                cat "$service_file"
            else
                echo "Нет прав на чтение файла"
            fi
            
            echo ""
            echo "========================================="
            echo ""
        done
        fi

} >> systemd_units

echo -e "${yellow}[Построение дерева зависимостей systemctl]${clear}" 
{
snapshot systemd_timers_gens "systemctl full dependency tree"  systemctl list-dependencies  --all --no-pager
} >> systemd_tree

echo -e "${yellow}[Сбор конфигураций systemd timers/generators для закрепления...]${clear}" 
{
snapshot systemd_timers_gens "systemctl list-timers" systemctl list-timers --all --no-pager
snapshot systemd_timers_gens "timers status" systemctl list-unit-files --type=timer --no-legend --no-pager

echo -e "\n" ;
echo "Детальная конфигурация каждого таймера:"
# Получаем список всех юнитов-таймеров (активных и неактивных)
while IFS= read -r timer_unit; do
    # Пропускаем пустые строки и заголовки
    [[ -z "$timer_unit" || "$timer_unit" == *"LOAD"* ]] && continue
    timer_name="${timer_unit%%.timer}"   # убираем суффикс .timer, оставляем чистое имя

    echo "---------------------------------------"
    echo "Таймер: $timer_unit"
    echo "Состояние (systemctl show):"
    systemctl show --no-pager "$timer_unit" 2>/dev/null | grep -E '^Id=|ActiveState=|SubState=|UnitFileState=|Triggers=|NextElapse|LastTrigger'
    echo ""
    echo "Содержимое unit-файла:"
    systemctl cat "$timer_unit" 2>/dev/null || echo "    Не удалось получить файл"
    echo ""
done < <(systemctl list-unit-files --type=timer --no-legend --no-pager 2>/dev/null | awk '{print $1}')

# генераторы
GENERATOR_DIRS=(
    /etc/systemd/system-generators
    /usr/local/lib/systemd/system-generators
    /lib/systemd/system-generators
    /usr/lib/systemd/system-generators
)

# Каталоги, в которых генераторы могут создавать юниты (dynamic transient)
UNIT_SEARCH_PATHS=(
    /run/systemd/generator
    /run/systemd/generator.early
    /run/systemd/generator.late
    /run/systemd/system
    /tmp  # иногда временные файлы с последующим копированием
)

echo -e "Найденные генераторы: \n"
for dir in "${GENERATOR_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
		echo $dir
		ls -latrh $dir/* 
		echo -e "\n" ;
	fi
done

echo -e "Файлы генераторов: \n"
for dir in "${UNIT_SEARCH_PATHS[@]}"; do
    if [[ -d "$dir" ]]; then
		more $dir/*/* | cat 
		echo -e "\n" ;
	fi
done

echo -e "Строки из генераторов\n"
for dir in "${GENERATOR_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
		for dfile in $(ls $dir/*); do
			echo $dfile
			echo -e "\n" ;
			strings $dfile
			echo -e "-------------------------\n" ;
		done
	fi
done

} >> systemd_timers_gens

clean() {
    tr '\n\r\t' '   ' | tr -s ' '
}

# docker analytics
{
# Проверка docker
DOCKER_AVAILABLE=0
if command -v docker >/dev/null 2>&1; then
    DOCKER_AVAILABLE=1
fi

# Маппинг портов: host_port -> container info
declare -A PORT_CONTAINER
declare -A PORT_CONTAINER_PORT
declare -A PORT_IMAGE

if [ "$DOCKER_AVAILABLE" -eq 1 ]; then

#ls /var/lib/docker/containers/*/*-json.log 2>/dev/null 
mkdir -p ./artifacts/docker
cp /var/lib/docker/containers/*/*-json.log ./artifacts/docker 2>/dev/null
# alt paths on some distros
cp /var/lib/docker/containers/*/*/*.log* ./artifacts/docker 2>/dev/null

# Артефакты Docker: /var/lib/docker/containers/*/
snapshot docker_stats "Docker version" docker --version
snapshot docker_stats "Docker ps -a" docker ps -a
snapshot docker_stats "Docker images" docker images ls -a
snapshot docker_stats "Docker info" docker info
snapshot docker_stats "Docker volumes" docker volume list
snapshot docker_stats "Docker stats"  docker stats --all --no-stream --no-trunc

    while read -r cid name image ports; do
        # Пример ports:
        # 0.0.0.0:8080->80/tcp, :::8080->80/tcp
        IFS=',' read -ra mappings <<< "$ports"
        for m in "${mappings[@]}"; do
            # вытащить host_port и container_port
#            if [[ "$m" =~ :([0-9]+)->([0-9]+)/([a-z]+) ]]; then
#                host_port="${BASH_REMATCH[1]}"
#                cont_port="${BASH_REMATCH[2]}"
#               proto="${BASH_REMATCH[3]}"

host_port=$(echo "$m" | sed -nE 's/.*:([0-9]+)->([0-9]+)\/([a-z]+).*/\1/p')
cont_port=$(echo "$m" | sed -nE 's/.*:([0-9]+)->([0-9]+)\/([a-z]+).*/\2/p')
proto=$(echo "$m" | sed -nE 's/.*:([0-9]+)->([0-9]+)\/([a-z]+).*/\3/p')

if [[ -n "$host_port" && -n "$cont_port" && -n "$proto" ]]; then

                key="${host_port}/${proto}"

                PORT_CONTAINER[$key]="$name"
                PORT_CONTAINER_PORT[$key]="$cont_port"
                PORT_IMAGE[$key]="$image"
            fi
        done
    done < <(docker ps --format "{{.ID}} {{.Names}} {{.Image}} {{.Ports}}")
fi

# Заголовок
#printf "%-12s %-18s %-7s %s %-6s %-5s %-15s %-15s %-20s\n" \
printf "\n"
printf "[Docker custom analytics data]"
printf "\n"
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
"USER" "PROCESS" "PID" "CMD" "PORT" "PROTO" "CONTAINER" "CONT_PORT" "IMAGE"  | column -t -s $'\t'

# Сбор через ss
ss -tulnpH | while read -r line; do
    proto=$(echo "$line" | awk '{print $1}')
    local_addr=$(echo "$line" | awk '{print $5}')

    port=$(echo "$local_addr" | sed -E 's/.*:([0-9]+)$/\1/')
    pid=$(echo "$line" | grep -oP 'pid=\K[0-9]+' | head -n1)

    [ -z "$pid" ] && continue

    user=$(ps -o user= -p "$pid" 2>/dev/null)
    comm=$(ps -o comm= -p "$pid" 2>/dev/null)
#cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)

exe=$(readlink -f /proc/$pid/exe 2>/dev/null | clean)
cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | clean)
#cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | tr -s '[:space:]' ' ')
cmd="${cmdline:-$exe}"
#echo $cmd

if [[ -z "$cmd" ]]; then
    cmd=$(ps -o args= -p "$pid" 2>/dev/null)
fi

#    cmd=$(ps -o args= -p "$pid" 2>/dev/null)

    # Docker lookup
    container="-"
    cont_port="-"
    image="-"

    if [ "$DOCKER_AVAILABLE" -eq 1 ]; then
        key="${port}/${proto}"
        container=${PORT_CONTAINER[$key]:--}
        cont_port=${PORT_CONTAINER_PORT[$key]:--}
        image=${PORT_IMAGE[$key]:--}
    fi

   # printf "%-12s %-18s %-7s %-28.28s %-6s %-5s %-15s %-15s %-20s\n" \
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$user" "$comm" "$pid" "$cmd" "$port" "$proto" "$container" "$cont_port" "$image" | column -t -s $'\t'

done


} >> docker_stats






#! - конец для записи основных текстовых файлов

# ----------------------------------
# ----------------------------------

# Архивируем собранные артефакты

echo -e "${yellow}[Packing artifacts...]${clear}"
tar --remove-files -zc -f ./artifacts.tar.gz artifacts 2>/dev/null
# additional clearing for artifacts folder
rm -rf artifacts 2>/dev/null

# облегчим себе задачу в будушем, и добавим запись таймстампов во все файлы history
if [[ "$SET_HISTORY" -gt 0 ]]; then
	echo -e "${yellow}[Change HISTTIMEFORMAT to world-best value IMHO]${clear}"
	echo "CURRENT HISTTIMEFORMAT: $HISTTIMEFORMAT"
	# format:
	# seq. number | unix epoch | dd-mm-YYYY | HH:MM:SS | Zone <space>
	# 191  1715338321 10-05-2024 13:52:01 MSK history
	hist_format="[%s %d-%m-%Y %H:%M:%S %Z] "

	# alt. locations are: ~/.bash_profile, ~/.bashrc ... 
	hist_persist="/etc/bash.bashrc"
	if $(grep -q "^HISTTIMEFORMAT=" $hist_persist); then
		sed -i "s/^HISTTIMEFORMAT=.*/HISTTIMEFORMAT=\"$hist_format\"/" $hist_persist;
	else
		sed "$ a\HISTTIMEFORMAT=\"$hist_format\"" -i $hist_persist
	fi
	
	HISTTIMEFORMAT="[%s %d-%m-%Y %H:%M:%S %Z] "
	export HISTTIMEFORMAT="[%s %d-%m-%Y %H:%M:%S %Z] "

	echo "Changed HISTTIMEFORMAT to <$hist_format> in $hist_persist !"
fi

snapshot host_info "Завершили сбор данных" date
 # Наш лог-файл, фильтруем цветовые формантанты
 } |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log) 

 
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
 echo "ENDED at $(end) ($(date '+%Y-%m-%d %H:%M:%S'))! Execution time was $(expr $end - $start) seconds."
 #echo -e "${magenta}Проверяй директорию ${saveto}! ${clear}"
 echo -e "${magenta}Забирай файл $saveto.tar.gz! ${clear}"
 echo -e "${red}Не забудь удалить меня, ifrit.sh !! ${clear}"
 pathe=$(readlink -f $saveto.tar.gz)
 echo -e "${yellow}Полный путь: ${pathe}! ${clear}"
# Открываем директорию в файловом менеджере — работает не во всех дистрибутивах. В Astra также можно использовать команду fly-fm
if command -v xdg-open >/dev/null 2>&1; then
    if (( $EUID != 0 )); then
        # Not root - execute GUI to open folder
        xdg-open . 2>/dev/null &
    else
        # decrease privs and open as current user
        sudo -u $(whoami) xdg-open . 2>/dev/null  &
		# sudo -u $(logname) xdg-open . 2>/dev/null  &
    fi
fi

# } |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log) # Наш лог-файл, фильтруем цветовые формантанты
 

# Справочно: список выводимых файлов:
	# activity_info - пользовательская активность
	# apps_file - приложения, история 
	# console_log - лог работы скрипта
	# cronconfigs_info - запланированные задачи
	# devices_info - инфа по железу
	# dmesg - вывод dmesg
	# docker_stats - краткая статистика по docker
	# dpkg_status - отдельная выгрузка статуса dpkg
	# env_profile_info - инфа по конфигам профиля
	# history_info - ключевые действия на хосте 
	# host_info - основной файл с базовой информацией о хосте
	# int_files_info - результаты поиска изменённых файлов за временной промежуток
	# ioc_word_info - список файлов и строк из них, где встречаются искомые термины
	# ip_search_info - файл с результатами грепа IP-адресов в файлах
	# journalctlq - выгрузка journalctl
	# junk_info - мегомусорный файл с результатами выполнения всех команд, которые были пожеланы быть выполнеными
	# kernel_params - параметры ядра и модули
	# lsof_file - файл для хранения вывода lsof
	# network_add_info - результаты грепа логов (сетевые артефакты)
	# network_info - инфа по сетевым конфигам
	# persistence_check - выгрузки конфигов на популярные места для закрепления от популярного ИБ-вендора
	# pstree_file - гламурный вывод дерева процессов
	# rc_scripts - листинг скриптов из автозаруска в /etc/rc*
	# root_cfg - текстовка конфигураций профиля рута
	# secur_cfg - проверка некоторых конфигов по безопасности (аудит, отправка логов, SELinux, AppArmor)
	# services_configs - конфиги всех служб
	# services_info - инфа по службам
	# susp_chk - проверка на некоторые очень подозрительные техники атакующих в системе
	# systemd_timers_gens - конфигурации таймеров и генераторов systemd
	# systemd_tree - результат построения дерева зависимостей systemctl
	# systemd_units - конфигурация всех служб 
	# usb_list_file - история подключения USB-носителей
	# users_cfgs - текстовка конфигураций профилей пользователей
	# users_files - инфа по пользовательским файлам, мини-листинг файловой системы
	# users_files_timeline - священный таймлайн изменения файлов в пользовательских каталогах
	# virt_apps_file - инфа по виртуалкам или вайнам, альтернативным ОС в системе
