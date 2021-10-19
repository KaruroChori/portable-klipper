# Portable klipper

A docker-based environment with klipper, moonraker and fluidd or mainsail. It can be installed on any computer running linux with docker and some minimal dependencies.
In order to use it:

1) edit services.sh to update your selection of the UI and add the latest version.
2) put your klipper config to runtime/config as `printer.cfg`.
3) properly edit your `moonraker.conf` file in `moonraker_docker` based on your network configuration.
3) run ```./start.sh build``` which will clone klipper and moonraker and download mainsail release, build docker images.
4) you can run an interactive shell in klipper to configure and flash the printer according to klipper docs.
4) run ```./services.sh start``` to start. 

now klipper, moonraker and your UI of choice are running in docker (hopefully) and you can connect to your localhost:8080 with any web browser.

To stop, use ```./services.sh stop```.
To restart, ```./services.sh restart```.
