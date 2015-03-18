admin@smartit.bg

'zmbkpose' do parallel backups independently, even with -a switch.
Current script is passing to zmbkpose five accounts at once with -a switch.
But it needs to wait the "haviest" account to be backed up to continue with the next five accounts.
To fastening the process this script will run 'zmbkpose' with -a switch N number of times as background process. 

Also, one have an option to backup only active mailboxes or closed ones.

Zmbkpose repo

https://github.com/bggo/Zmbkpose