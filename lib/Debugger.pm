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
  } elsif ($cmd[0] eq 'v') {
    $self->ToggleVerbose;
  } elsif ($cmd[0] eq 'x') {
    $self->PrintAddrs($cmd[1], 1);
  } elsif ($cmd[0] eq 'p') {
    $self->PrintAddrs(${ $self->{_CPU} }->{_PC}, $cmd[1]);
  } elsif ($cmd[0] eq 'save') {
    $self->SaveState($cmd[1]);
  } elsif ($cmd[0] eq 'load') {
    $self->LoadState($cmd[1]);
  } elsif ($cmd[0] eq 'st') {
    $self->DumpStack;
  } elsif ($cmd[0] eq 'reg') {
    $self->DumpRegisters;
  } elsif ($cmd[0] eq 'setreg') {
    $self->SetReg($cmd[1], $cmd[2]);
  } else {
    say "Command not known, insert again."
  }

  return;
}

sub SaveState {
  my ($self, $filename) = @_;
  $filename //= 'dump.bin';
  my $cpu = ${ $self->{_CPU} };

  open my $f, '>', $filename or die "Cannot open $filename";
  binmode $f;

  print $f pack 'v', $cpu->{_PC};
  foreach (@{ $cpu->{_registers} }) { print $f pack 'v', $_; }
  print $f pack 'v', $cpu->{_addresses};
  foreach (@{ $cpu->{_memory} }) { print $f pack 'v', $_; }
  foreach ($cpu->{_stack}->GetStack) { print $f pack 'v', $_; }

  close $f;
}

sub LoadState {   my ($self, $filename) = @_;
  if (!$filename) {
    say 'You must provide a file to load the state from!';
    return;
  }

  ## no critic (RequireBriefOpen)
  open my $f, '<', $filename or die "Cannot open $filename";
  binmode $f;
  ## use critic

  # Restore PC
  read $f, my $next_value, 2;
  $next_value = unpack 'S', $next_value;
  ${ $self->{_CPU} }->{_PC} = $next_value;

  # Load registers
  for (my $i = 0; $i < 8; $i++) {
    read $f, $next_value, 2;
    $next_value = unpack 'S', $next_value;
    ${ $self->{_CPU} }->{_registers}[$i] = $next_value;
  }

  # Load memory
  read $f, $next_value, 2;
  $next_value = unpack 'S', $next_value;
  ${ $self->{_CPU} }->{_addresses} = $next_value;

  my @memory;
  for (my $i = 0; $i < ${ $self->{_CPU} }->{_addresses}; $i++) {
    read $f, $next_value, 2;
    $next_value = unpack 'S', $next_value;
    push @memory, $next_value;
  }
  ${ $self->{_CPU} }->{_memory} = \@memory;

  # Load stack
  while (read $f, $next_value, 2) {
    $next_value = unpack 'S', $next_value;
    ${ $self->{_CPU} }->{_stack}->Push($next_value);
  }

  close $f;
}

sub ToggleVerbose {
  my ($self) = @_;
  ${ $self->{_CPU} }->{_verbose} = (${ $self->{_CPU} }->{_verbose}+1) % 2;
  return;
}

sub SetReg {
  my ($self, $regIdx, $value) = @_;
  die "Wrong register index: $regIdx, it should be in [0,7]"
    if $regIdx < 0 || $regIdx > 7;
  ${ $self->{_CPU} }->{_registers}[$regIdx] = $value;
  return;
}

sub DumpStack {
  my ($self) = @_;
  my $i = 0;
  say 'Stack:';
  foreach (${ $self->{_CPU} }->{_stack}->GetStack) {
    say "\tSTACK[$i]: $_";
    $i++;
  }
}

sub DumpRegisters {
  my ($self) = @_;
  my $i = 0;
  say 'Registers:';
  foreach (@{ ${ $self->{_CPU} }->{_registers} }) {
    say "\tREG[$i]: $_";
    $i++;
  }
}

sub PrintAddrs {
  my ($self, $addr, $len) = @_;
  for (0..$len-1) {
    my $value = ${ $self->{_CPU} }->{_memory}[$addr+$_];
    $value = ${ $self->{_CPU} }->_fetch($value);
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

