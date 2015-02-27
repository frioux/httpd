#!/usr/bin/en perl

use strict;
use warnings;

use Template;

my $template = Template->new({ ABSOLUTE => 1 });

$template->process('/usr/local/apache2/conf/httpd.conf.template', {
     cal_port => $ENV{CAL_PORT_5000_TCP_PORT},
   feeds_port => $ENV{FEEDS_PORT_5000_TCP_PORT},
     rss_port => $ENV{RSS_PORT_5000_TCP_PORT},
      st_port => $ENV{ST_PORT_8080_TCP_PORT},
}, '/usr/local/apache2/conf/httpd.conf')
    || die $template->error();

unless (-f '/usr/local/apache2/ssl/wild.key') {
   mkdir('/usr/local/apache2/ssl');
   # rmdir('/usr/local/apache2/ssl/wild.key') or die "$!";
   # rmdir('/usr/local/apache2/ssl/wild.cert') or die "$!";
   system(qw(
      openssl req
      -nodes
      -x509
      -newkey rsa:2048
      -keyout /usr/local/apache2/ssl/wild.key
      -out /usr/local/apache2/ssl/wild.cert
      -days 356
      -subj /CN=*.afoolishmanifesto.com
   ));
}

exec 'httpd-foreground';
