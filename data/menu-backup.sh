#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- KatsuTun -##########

infos() {
echo -e "
====================================================================================
Because owners of this script lack of email account, we changing the backup method.
So basically it is not hard to do, just follow the things up:
====================================================================================
1. Create a telegram bot from @BotFather
2. Follow the step it provides, like give it a name and username for your bot
3. It should gives you a bot token, so save it
4. Now go to @MissRose_bot and type /id, she will inform you your ID, save it
5. (optional) If you wanna make your new bot runs in your group chat, type /id in
   your group chat and make sure @MissRose_bot is there.
6. Now you have both bot token and chat id
7. So lets just store them to your backup configuration. Go back to the backup menu
   and choose BACKUP SETTINGS
8. Input your bot token and chat id
9. Done! Now you can do backup to test if the script is working well
====================================================================================
How to restore:
1. After you did setting the backup configuration up, and your bot works well,
   upload your latest backup file to google drive and copy the link
2. Go back to the backup menu and choose RESTORE
3. Paste the backup link from google drive
4. Done!
====================================================================================
Report errors at $ISSUES_URL
Thank you for using this script
===================================================================================="
echo ""
ui_pause; menu-backup
}


ui_screen "BACKUP & RESTORE" "encrypted archive to your own storage"
ui_card_start
ui_options "01:Auto backup" "03:Restore" "02:Backup now" "04:Backup settings" "05:How to use" "06:Install dependencies"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; autobackup ;;
02 | 2) clear ; backup ;;
03 | 3) clear ; restore ;;
04 | 4) clear ; backup_setting ;;
05 | 5) clear ; infos ;;
06 | 6) clear ; bash /etc/lukman/dependencies.sh ; menu-backup ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-backup ;;
esac
