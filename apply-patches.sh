#!/bin/sh

for i in $(find /opt/wallabag/patches/ -type f -name "*.patch" | sort); do
  (cd /var/www/html ; echo "Applying ${i}…" ; patch -p1 < ${i})
done
