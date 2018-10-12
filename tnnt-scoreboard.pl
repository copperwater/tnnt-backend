#!/usr/bin/env perl -I.

#=============================================================================
# THE NOVEMBER NETHACK TOURNAMENT
# """""""""""""""""""""""""""""""
# Scoreboard generator.
#=============================================================================

use v5.10;

use FindBin qw($Bin);
use lib "$Bin";

use JSON;
use Try::Tiny;
use Moo;
use TNNT::Cmdline;
use TNNT::Config;
use TNNT::Source;
use TNNT::ClanList;
use TNNT::Score;
use TNNT::Template;

$| = 1;

#--- process command-line arguments

my $cmd;

try {
  $cmd = TNNT::Cmdline->instance();
} catch {
  print STDERR "Invalid command-line arguments\n";
  exit(1);
};

#--- load configuration file

my $cfg = TNNT::Config->instance(config_file => "$Bin/config.json");
$cfg->config();

#--- load clan list

my $clans = TNNT::ClanList->instance();

#--- initialize sources

my @sources;

$cfg->iter_sources(sub {
  push(@sources, TNNT::Source->new(@_));
});

#--- perform reading of the xlogfiles

my $score = TNNT::Score->new();

for my $src (@sources) {
  $src->read(sub { $score->add_game($_[0]) });
}

#--- compile the scoreboard

$score->process();
my $data = $score->export();

#--- output JSON data

if(defined (my $out = $cmd->json_only())) {
  my $js = JSON->new()->pretty(1);
  if($out eq '') {
    print $js->encode($data);
  } else {
    open(my $fh, '>', $out) or die "Cannot open file '$out'";
    print $fh $js->encode($data);
    close($fh);
  }
}

#--- process the templates

else {
  my $t = TNNT::Template->new(data => $data);
  $t->process();
  $t->process('players', 'player', $data->{'players'}{'ordered'});
  $t->process('clans', 'clan', $data->{'clans'}{'ordered'});
}