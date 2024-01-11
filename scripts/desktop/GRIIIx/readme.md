* if not already synced: copy .sh and .py to location in .desktop file
* check group id 
** of `sudo ls -alh /home/steph/.local/share/waydroid/data/media/0/`
** of `sudo ls -alh /home/steph/.local/share/waydroid/data/media`
* then 
```
sudo groupadd -g 1023 waydroid-system
sudo usermod -a -G waydroid-system steph
sudo groupadd -g 10136 waydroid-user
sudo usermod -a -G waydroid-user steph
sudo chmod +x /home/steph/.local/share/waydroid/data/media/0/DCIM/GRIIIx/download-camera-images.sh
sudo chmod -R g+rw /home/steph/.local/share/waydroid/data/media/0/DCIM
sudo find /home/steph/.local/share/waydroid/data/media/0/DCIM -type d -exec chmod g+x {} \;
```
* copy .desktop to ~/.local/share/applications
* log out and back in