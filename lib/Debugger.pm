package Debugger;

# Synacor challenge: implement a CPU emulator for fun and learning purpose.
#
# Copyright (C) 2022 A-725-K (Andrea Canepa)
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# synacor is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# synacor. If not, see <https://www.gnu.org/licenses/>.

use v5.36;
use strict;
use warnings;

use Algorithm::Permute;

sub new {
  my ($class, $cpu) = @_;

  my $self = {
    _CPU => $cpu,
  };

  bless $self, $class;
}

sub RunCmd {
  my ($self, $line) = @_;

  my @cmd = split ' ', $line;

  if ($cmd[0] eq 'solvecoins') {
    $self->SolveCoins;
  } elsif ($cmd[0] eq 'x') {
    $self->PrintAddrs($cmd[1], 1);
  } elsif ($cmd[0] eq 'p') {
    $self->PrintAddrs(${ $self->{_CPU} }->{_PC}, $cmd[1]);
  } else {
    say "Command not known, insert again."
  }

  return;
}

sub PrintAddrs {
  my ($self, $addr, $len) = @_;
  for (0..$len) {
    my $value = ${ $self->{_CPU} }->{_memory}[$addr+$_];
    # if ($value >= 32768) {
    #   $value = ${ $self->{_CPU} }->{_registers}[$value-32768];
    # }
    say "MEM[$addr+$_] = $value";
  }
}

sub SolveCoins {
  my ($self) = @_;

  my %colors = (
    2 => 'red',
    3 => 'corroded',
    5 => 'shiny',
    7 => 'concave',
    9 => 'blue',
  );

  my $nums = Algorithm::Permute->new([2, 3, 5, 7, 9]);
  while (my @next_perm = $nums->next) {
    my $equation =
      $next_perm[0] +
      $next_perm[1]*($next_perm[2]**2) +
      $next_perm[3]**3 -
      $next_perm[4];
    if ($equation == 399) {
      print 'The correct sequence is: ';
      map { print "$colors{$_}, " } @next_perm;
      print "\n";
      last;
    }
  }

  return;
}

1;

