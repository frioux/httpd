#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use IO::Socket::SSL 'SSL_VERIFY_NONE';
use File::pushd;
use IPC::System::Simple 'system';
use Capture::Tiny 'capture';
use HTTP::Request;
use LWP::UserAgent;

capture {
   system(qw(docker build -t httpd-test-main .));
   my $d = pushd('t');
   system(qw(docker build -f Dockerfile.test -t httpd-test .));
};

my $parent = $$;
for (qw(cal feeds rss st)) {
   next if fork;
   my $name = $_;
   capture {
      exec(
         qw(docker run --rm),
         '--name', "$name-$parent",
         '-e',  "NAME=$name",
         'httpd-test'
      )
   }
}

sleep 3;

capture {
   exec(
      qw(docker run --rm --name), "httpd-$parent",
      '--link',    "st-$parent:st",
      '--link',   "rss-$parent:rss",
      '--link',   "cal-$parent:cal",
      '--link', "feeds-$parent:feeds",
      '-P',
      'httpd-test-main',
   )
} unless fork;

$SIG{INT} = sub { exit(1) };

sleep 2;

my (undef, $http_port) = split /:/,
   capture { system(qw(docker port), "httpd-$$", 80) };

my (undef, $https_port) = split /:/,
   capture { system(qw(docker port), "httpd-$$", 443) };

chomp($http_port);
chomp($https_port);

for (qw(cal feeds rss)) {
   my $name = $_;
   my $r = LWP::UserAgent->new(
      ssl_opts => {
         verify_hostname => 0,
         SSL_verify_mode => SSL_VERIFY_NONE,
         SSL_hostname => "$name.afoolishmanifesto.com",
      }
   )->request(
      HTTP::Request->new(
         GET => "https://localhost:$https_port/${name}test",
         [ Host => "$name.afoolishmanifesto.com" ],
      ),
   );
   is($r->decoded_content, "name: $name, URI: /${name}test", $name);
}

done_testing;

END {
   for (qw(cal feeds rss st httpd)) {
      next if fork;
      capture {
         CORE::system(qw(docker kill), "$_-$parent");
         CORE::system(qw(docker rm), "$_-$parent");
      };
   }
}

