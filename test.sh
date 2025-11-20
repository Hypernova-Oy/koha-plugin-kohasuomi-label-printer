#!/Bin/bash

KOHA_CONF="/etc/koha/sites/demo_fi/koha-conf.xml" perl -I. -I/usr/share/koha/lib t/$1*.t
