Napkin
======

Napkin is an interaction platform for HTTP enabled devices.  The Napkin server offers a REST API with predefined services for storing and retrieving configuration information and collecting time series data from client devices.  A plug-in model provides extensibility in HTTP handling and periodic processing of stored data.  The Napkin server runs on Ruby [Sinatra](http://www.sinatrarb.com/) and the [Neo4j](http://www.neo4j.org/) graph database.

Napkin began when I was clued into the emergence of small, inexpensive but HTTP capable (ARM-based, "[arduino](http://en.wikipedia.org/wiki/Arduino)-ish") computers like the [Netduino Plus](http://www.netduino.com/), [.Net Gadgeteer](http://www.ghielectronics.com/catalog/category/274), [BeagleBone](http://beagleboard.org/bone), [Raspberry Pi](http://www.raspberrypi.org/), etc. and parts websites like [Sparkfun](https://www.sparkfun.com/), [Adafruit](http://adafruit.com/), etc. I built systems based on these devices to monitor and control the environment around my home (temperature, humidity, light levels, sounds, etc.) and needed a way to collect, store and process all of the data.

### Details

The Napkin server can run in (at least) these configurations:
* [Ubuntu (x86) 12.04](Server-on-Ubuntu-x86)
* [pcduino (running Ubuntu 12.04)](Server-on-pcduino)
* [BeagleBone black (running Ubuntu 13.04)](Server-on-BeagleBone-black)

Napkin clients use REST-style HTTP communication to access services such as:
* [config](Plugin-config) - allows devices to store and retrieve hierarchical configuration data
* [chatter](Plugin-chatter) - allows devices to post time series data
* vitals - periodically stores data about the state of the napkin server (such as memory and disk usage)
* new services can be implemented as plugins

Napkin client examples:
* .Net Gadgeteer (C#)
  * [cerbee1](Gadgeteer-client-cerbee1)
  * [cerb1](Gadgeteer-client-cerb1)
  * [cerb2](Gadgeteer-client-cerb2)
* BeagleBone (Python)
  * [bone1](Beaglebone-client-bone1)
