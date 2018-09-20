#!/usr/bin/env perl

#=============================================================================
# Object representing single player.
#=============================================================================

package TNNT::Player;

use Moo;
use TNNT::ClanList;

with 'TNNT::GameList::AddGame';
with 'TNNT::AscensionList';
with 'TNNT::ScoringList';



#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

has name => (
  is => 'ro',
  required => 1
);

# clan instance reference or undef

has clan => (
  is => 'ro',
  builder => 1,
  lazy => 1,
);

has achievements => (
  is => 'rwp',
  default => sub { [] },
);

has achievements_hash => (
  is => 'rwp',
  default => sub { {} },
);

has maxcond => (
  is => 'rwp',
);

has maxlvl => (
  is => 'rwp',
);



#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#-----------------------------------------------------------------------------
# Builder for the 'clan' attribute
#-----------------------------------------------------------------------------

sub _build_clan
{
  my ($self) = @_;

  my $clans = TNNT::ClanList->instance();
  return $clans->find_clan($self);
}


#-----------------------------------------------------------------------------
# Display player name (for development purposes).
#-----------------------------------------------------------------------------

sub disp
{
  my ($self) = @_;

  print $self->name(), "\n";
}


#-----------------------------------------------------------------------------
# This is implemented in GameList role.
#-----------------------------------------------------------------------------

sub add_game
{
  my ($self, $game) = @_;

  #--- track highest number of conducts

  if($game->is_ascended && $game->conducts() > ($self->maxcond() // 0)) {
    $self->_set_maxcond(scalar($game->conducts()));
  }

  #--- track maximum depth reached

  if($game->maxlvl() > ($self->maxlvl() // 0)) {
    $self->_set_maxlvl($game->maxlvl());
  }
}



#=============================================================================

1;
