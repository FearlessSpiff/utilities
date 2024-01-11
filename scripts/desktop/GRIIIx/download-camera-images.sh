#!/bin/bash
cd /home/steph/.local/share/waydroid/data/media/0/DCIM/GRIIIx || exit
python GRsync.py -a
chmod g+w -R  /home/steph/.local/share/waydroid/data/media/0/DCIM/GRIIIx/100RICOH/
chgrp -R waydroid-user /home/steph/.local/share/waydroid/data/media/0/DCIM/GRIIIx/100RICOH/

