#!/usr/bin/env perl

#=============================================================================
# Loading and access to clan database. This is basically an external
# configuration, so we handle this in as a singleton object.
#=============================================================================

package TNNT::ClanList;

use Moo;
use DBI;
use TNNT::Config;
use TNNT::Clan;
with 'MooX::Singleton';



#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

has clans => (
  is => 'rw',
  builder => '_load_clans',
);



#=============================================================================
# Config loading
#=============================================================================

sub _load_clans
{
  my ($self) = @_;
  my $cfg = TNNT::Config->instance()->config();

  #--- if the configuration entry doesn't exist, just return empty hash

  if(!exists $cfg->{'clandb'} || !$cfg->{'clandb'}) {
    return {};
  }

  #--- ensure the database file exists and is readable

  if(!-r $cfg->{'clandb'}) {
    die sprintf
      "Clan database file (%s) does not exist or is not readable\n",
      $cfg->{'clandb'};
  }

  #--- open the database file

  my $dbh = DBI->connect(
    'dbi:SQLite:dbname=' . $cfg->{'clandb'},
    undef, undef
  );

  if(!ref($dbh)) {
    die "Failed to open clan database at " . $cfg->{'clandb'};
  }

  #--- prepare and execute the query

  my $sth = $dbh->prepare(
    'SELECT players.name AS name, clans.name AS clan, clan_admin ' .
    'FROM players JOIN clans USING (clans_i)'
  );

  my $r = $sth->execute();
  if(!$r) {
    die sprintf('Failed to query clan database (%s)', $sth->errstr());
  }

  #--- read the clan info from the database

  my %clans;
  my $i = 0;

  while(my $h = $sth->fetchrow_hashref()) {
    my $clan = $h->{'clan'};
    if(!exists $clans{$clan}) {
      $clans{$clan} = new TNNT::Clan(name => $clan, n => $i++);
    }
    $clans{$clan}->add_player(
      $h->{'name'},
      $h->{'clan_admin'}
    );
  }

  #--- finish

  return \%clans;
}


#=============================================================================
# Clans iterator function.
#=============================================================================

sub iter_clans
{
  my ($self, $cb) = @_;

  for my $clan (sort keys %{$self->clans()}) {
    $cb->($self->clans()->{$clan});
  }

  return $self;
}



#=============================================================================
# Find clan by playername or player object ref.
#=============================================================================

sub find_clan
{
  my ($self, $player) = @_;

  if(ref($player)) {
    $player = $player->name();
  }

  my ($clan_name) = grep {
    $self->clans()->{$_}->is_member($player)
  } keys %{$self->clans()};

  if($clan_name) {
    return $self->clans()->{$clan_name};
  } else {
    return undef;
  }
}


#-----------------------------------------------------------------------------
# Add games to clans
#-----------------------------------------------------------------------------

sub add_game
{
  my ($self, $game) = @_;

  my $clan = $self->find_clan($game->player());
  return if !$clan;

  $clan->add_game($game);

  return ($self, $game);
}


#-----------------------------------------------------------------------------
# Export clan data
#
# NOTE/FIXME: We have decided that the clans will be exposed to the templates
# in a list, not hash. Ie. clan is identified not by its name, but by its
# index in the list. This makes it inconsistent with how players are presented
# and makes it somwhat awkward. The intention was to prevent users putting
# arbitrary strings into URLs.
#-----------------------------------------------------------------------------

sub export
{
  my ($self) = @_;
  my (@clans, @clans_by_score);

  #--- produce list of clans with full information

  foreach my $clan_name (keys %{$self->clans()}) {
    my $clan = $self->clans()->{$clan_name};
    my $i = $clan->n();
    $clans[$i] = {
      n            => $i,
      name         => $clan->name(),
      players      => $clan->players(),
      admins       => $clan->admins(),
      score        => $clan->sum_score(),
      scores       => $clan->export_scores(),
      games        => $clan->export_games(),
      ascs         => $clan->export_ascensions(),
      achievements => $clan->achievements(),
      scorelog     => $clan->export_scores(),
      unique_deaths => [
        map { [ $_->[0], $_->[1]->n() ] } @{$clan->unique_deaths()}
      ],
      unique_ascs  => $clan->export_ascensions(sub {
        $_[0]->clan_unique();
      }),
    };

    # ascension ratio

    if($clan->count_ascensions()) {
      $clans[$i]{'ratio'} = sprintf("%3.1f",
        $clan->count_ascensions() / $clan->count_games() * 100
      )
    }

    # trophies (selected trophies for showcasing on the player page)

    my @trophies;
    my $cfg = TNNT::Config->instance()->config();

    my @trophy_names = qw(
      firstasc mostascs mostcond lowscore highscore minturns gimpossible
      maxstreak allroles allraces allaligns allgenders allconducts allachieve
      mostgames
    );

    for my $race (qw(hum elf dwa gno orc)) {
      push(@trophy_names, "greatrace:$race", "lesserrace:$race");
    }

    for my $role (qw(arc bar cav hea mon pri ran rog val wiz)) {
      push(@trophy_names, "greatrole:$role", "lesserrole:$role");
    }

    for my $trophy (@trophy_names) {
      if(my $s = $clan->get_score("clan-$trophy")) {
        push(@trophies, {
          'trophy' => $trophy,
          'title'  => $cfg->{'trophies'}{"clan-$trophy"}{'title'},
          'when'   => $s->_format_when(),
        });
      }
    }

    $clans[$i]{'trophies'} = \@trophies if @trophies;

  }

  #--- produce list of clan indices ordered by score

  @clans_by_score =

  map { $_->{'n'} }
  sort {
    if($b->{'score'} == $a->{'score'}) {
      if(scalar @{$b->{'ascs'}} == scalar @{$a->{'ascs'}}) {
        return @{$b->{'achievements'}} <=> scalar @{$a->{'achievements'}}
      } else {
        return scalar @{$b->{'ascs'}} <=> scalar @{$a->{'ascs'}}
      }
    } else {
      return $b->{'score'} <=> $a->{'score'}
    }
  } @clans;

  #--- get clans' rank

  for(my $i = 0; $i < @clans_by_score; $i++) {
    $clans[$clans_by_score[$i]]{'rank'} = $i + 1;
  }

  #--- finish

  return {
    all => \@clans,
    ordered => \@clans_by_score,
  };
}



#=============================================================================

1;
