# IFRIT
Incident Forensic Response In Terminal script for linux

Обновлено 19.05.2024

Исправлены ошибки, повышена стабильность, мелкие правки по дизайну, улучшения в части работоспособности и приятности.
Добавлено несколько тематических файлов и проверок на подозрительную активность в системе. 
Добавлена возможность настройки формата истории команд "на будущее".
Убрана самопроверка целостности, в некоторых местах оставлены альтернативные команды (закомментированные). 


# IFRIT. Incident Forensic Response In Terminal =)
Статья: https://xakep.ru/2023/05/03/linux-incident-response/

Скрипт для сбора различной информации на linux, которая может быть полезна при расследовании инцидентов информационной безопасности, триаже и анализе хостов.
Основное отличие от ближайших аналогов (UAC, CatScale, bizone, и прочих) - в повышенной стабильности и гораздо меньших зависаниях в середине процесса.
Тестировался на Debian-like дистрибутивах типа Kali, Astra. Могут встречаться баги, в системе мы ничего не меняем (предполагаем работу с флешки), формируем папку с результатми выполнения команд (об этом ниже).

Перед запуском:
1) Посмотри код. Скорректируй команды с тегом #!
2) Задай в начале файла для поиска - IP, термины, файловые IOC, временной диапазон предполагаемого инцидента
3) При необходимости - удали или отредактируй блок с тематическим файлом junk_info

Запуск (предпочтительно от рута\sudo):
```
chmod a+x ./ifrit.sh && ./ifrit.sh
```

На выхлопе рядом со скриптом получаем архив вида 
```
<имя_хоста>_<юзер>_<дата и время>.tar.gz
```

в котором есть архив  `artifacts\artifacts.tar.gz` с натриаженными данными -  собранными файлами и артефактами (например, браузерными), а также тематические файлы:

	activity_info - пользовательская активность
	apps_file - приложения, история 
	console_log - лог работы скрипта
	cronconfigs_info - запланированные задачи
	devices_info - инфа по железу
	env_profile_info - инфа по конфигам профиля
	history_info - ключевые действия на хосте 
	host_info - основной файл с базовой информацией о хосте
	ioc_word_info - список файлов и строк из них, где встречаются искомые термины
	IP-search_info - файл с результатами грепа IP-адресов в файлах
	junk_info - мегомусорный файл с результатами выполнения всех команд, которые были пожеланы быть выполнеными
	lsof_file - файл для хранения вывода lsof
	network_add_info - результаты грепа логов (сетевые артефакты)
	network_info - инфа по сетевым конфигам
	pstree_file - гламурный вывод дерева процессов
	root_cfg - текстовка конфигураций профиля рута
	services_configs - конфиги всех служб
	services_info - инфа по службам
	usb_list_file - история подключения USB-носителей
	users_files - инфа по пользовательским файлам, мини-листинг файловой системы
	users_files_timeline - священный таймлайн изменения файлов в пользовательских каталогах
	users_cfgs - текстовка конфигураций профилей пользователей
	virt_apps_file - инфа по виртуалкам или вайнам, альтернативным ОС в системе
	secur_cfg - проверка некоторых конфигов по безопасности (аудит, отправка логов, SELinux, AppArmor)
	susp_chk - проверка на некоторые очень подозрительные техники атакующих в системе
	junk_k_info - выгрузки конфигов на популярные места для закрепления от популярного ИБ-вендора
	dmesg - вывод dmesg
	kernel_params - параметры ядра и модули
	rc_scripts - листинг скриптов из автозаруска в /etc/rc*
	journalctlq - выгрузка journalctl



TODO (updated ~~27.05.2023~~ 19.05.2024):
1. ~~Сделать бест практис по оформлению текущего кода с >> >> >> в вид {}>>.~~
2. ~~Задать переменные для IOC типа поисковых терминов, IP.~~
3. ~~Задать подсчёт контрольной суммы самого файла после блока определений. Зачем? Потому что захотел.~~
4. ~~Сделать смешные и понятные пояснения.~~
5. Сделать readme на английском + markdown.
6. В описании добавить картинок.
7. Сделать комментарии на едином языке и оформлении (русская версия, английский).
8. Сделать автоматическую проверку на аномалии и релевантную инфу (греп грепнутых результатов?).
9. ~~Цветовые алёрты в консоли.~~
10. Убрать закладку для тех, кто не читает то, что запускает. Шутка. Просто об этом подумать и помнить.
11. Чистка кода (научиться не говнокодить).
12. Оптимизировать записываемые файлы (структура, убрать запись эхов без результативных команд, возможно мини-функции).
13. Подумать о том, что вписывая выполняемые эхо-команды в текстовые файлы, можно сформировать эмулятор терминала для игрищ и CTF\digital forensic.
14. ~~Переделать множественные cat'ы, чтобы выводились названия и пути файлов~~
15. ~~Добавить вывод списка запущенных процессов с удалённым исполняемым файлом (т.е. в памяти)~~
16. ~~В выводе финальной директории указывать абсолютный путь~~
17. Провести рефакторинг кода, пересмотреть тематические файлы и их компоновку
18. Сделать единый формат вывода, например в одну строку или функцию вывода
