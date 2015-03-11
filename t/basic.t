#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use IO::Async::Loop::Epoll;
use IO::Async::Process;
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

my $loop = IO::Async::Loop::Epoll->new;

$loop->add(my $cal   = _test_httpd('cal'));
$loop->add(my $feeds = _test_httpd('feeds'));
$loop->add(my $rss   = _test_httpd('rss'));
$loop->add(my $st    = _test_httpd('st'));

sleep 2;

$loop->add(
   my $main = IO::Async::Process->new(
      command => [
         qw(docker run --rm --name), "httpd-$$",
         '--link',    "st-$$:st",
         '--link',   "rss-$$:rss",
         '--link',   "cal-$$:cal",
         '--link', "feeds-$$:feeds",
         '-P',
         'httpd-test-main',
      ],
      on_exception => sub { die "httpd exited unexpectedly!" },
      on_finish => sub {},
      stdout => { on_read => sub {} },
      stderr => { on_read => sub {} },
   ),
);

$SIG{INT} = sub { exit(1) };

sleep 2;

my (undef, $http_port) = split /:/,
   capture { system(qw(docker port), "httpd-$$", 80) };

my (undef, $https_port) = split /:/,
   capture { system(qw(docker port), "httpd-$$", 443) };

chomp($http_port);
chomp($https_port);

my $cal_f   = _test_future('cal');
my $feeds_f = _test_future('feeds');
my $rss_f   = _test_future('rss');

  is($cal_f->decoded_content, 'name: cal, URI: /caltest', 'cal');
is($feeds_f->decoded_content, 'name: feeds, URI: /feedstest', 'feeds');
  is($rss_f->decoded_content, 'name: rss, URI: /rsstest', 'rss');

done_testing;

sub _test_httpd {
   my $name = shift;
   IO::Async::Process->new(
      command => [
         qw(docker run --rm),
         '--name', "$name-$$",
         '-e',  "NAME=$name",
         'httpd-test'
      ],
      on_exception => sub { die "$name exited unexpectedly!" },
      on_finish => sub {},
      stdout => { on_read => sub {} },
      stderr => { on_read => sub {} },
   )
}

sub _test_future {
   my $name = shift;
   my $ua = LWP::UserAgent->new;
   $ua->ssl_opts(verify_hostname => 0);
   $ua->ssl_opts(SSL_verify_mode => SSL_VERIFY_NONE);
   $ua->ssl_opts(SSL_hostname => "$name.afoolishmanifesto.com");
   $ua
      ->request(
         HTTP::Request->new(
            GET => "https://localhost:$https_port/${name}test",
            [ Host => "$name.afoolishmanifesto.com" ],
         ),
      );
}

END {
   undef $_ for $cal, $feeds, $rss, $st, $main;
   for (qw(cal feeds rss st httpd)) {
      capture {
         CORE::system(qw(docker kill), "$_-$$");
         CORE::system(qw(docker rm), "$_-$$");
      };
   }
}

