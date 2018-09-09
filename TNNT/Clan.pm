#!/usr/bin/env perl

#=============================================================================
# Clan class
#=============================================================================

package TNNT::Clan;

use Moo;
with 'TNNT::ScoringList';



#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

has name => (
  is => 'rw',
  required => 1,
);

has players => (
  is => 'rw',
  default => sub { []; }
);

has admins => (
  is => 'rw',
  default => sub { []; }
);



#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#=============================================================================
# Add player to the clan, used during reading the clans from database.
#=============================================================================

sub add_player
{
  my ($self, $player, $admin) = @_;

  push(@{$self->players()}, $player);
  push(@{$self->admins()}, $player) if $admin;

  return $self;
}



#=============================================================================

1;
