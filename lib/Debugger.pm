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
    _breakpoints => {},
    _CPU => $cpu,
  };

  bless $self, $class;
}

sub RunCmd {
  my ($self, $line) = @_;

  my @cmd = split ' ', $line;

  if ($cmd[0] eq 'solvecoins') {
    $self->_solveCoins;
  } elsif ($cmd[0] eq 'b') {
    $self->_setUnsetBreakpoint($cmd[1]);
  } elsif ($cmd[0] eq 'v') {
    $self->_toggleVerbose;
  } elsif ($cmd[0] eq 'x') {
    $self->_printAddrs($cmd[1], 1);
  } elsif ($cmd[0] eq 'p') {
    $self->_printAddrs(${ $self->{_CPU} }->{_PC}, $cmd[1]);
  } elsif ($cmd[0] eq 'save') {
    $self->_saveState($cmd[1]);
  } elsif ($cmd[0] eq 'load') {
    $self->_loadState($cmd[1]);
  } elsif ($cmd[0] eq 'st') {
    $self->_dumpStack;
  } elsif ($cmd[0] eq 'reg') {
    $self->_dumpRegisters;
  } elsif ($cmd[0] eq 'setreg') {
    $self->_setReg($cmd[1], $cmd[2]);
  } else {
    say "Command not known, insert again."
  }

  return;
}

sub HandleBreakpoint {
  my ($self) = @_;
  my $cpu = ${ $self->{_CPU} };

  print '*DBG* ?- ';
  chomp(my $dbg_cmd = <>);
  if ($dbg_cmd ne 'c') {
    $self->RunCmd($dbg_cmd);
  }
  return;
}

# ############################################ #
# private subroutines and debugger opearations #
# ############################################ #
sub _setUnsetBreakpoint {
  my ($self, $addr) = @_;

  # If no address specified, display existing breakpoints
  if (!defined $addr) {
    $self->_displayBreakpoints;
    return;
  }

  my $cpu = ${ $self->{_CPU} };
  if ($addr < 0 || $addr >= $cpu->{_addresses}) {
    say 'You must provide a valid address to set a breakpoint!';
    return;
  }

  # If exists already a breakpoint, then remove it
  # Otherwise create a new one
  if (exists $self->{_breakpoints}{$addr}) {
    my $old_instr = $self->{_breakpoints}{$addr};
    $cpu->{_memory}[$addr] = $old_instr;
    delete $self->{_breakpoints}{$cpu->{_PC}};
  } else {
    my $old_instr = $cpu->{_memory}[$addr];
    $self->{_breakpoints}->{$addr} = $old_instr;
    $cpu->{_memory}[$addr] = -1;
  }

  return;
}

sub _displayBreakpoints {
  my ($self) = @_;
  my $i = 0;
  say "Breakpoints in the CPU:";
  foreach (keys %{ $self->{_breakpoints} }) {
    say "  - Break[$i]: $_";
    $i++;
  }
  return;
}

sub _saveState {
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

sub _loadState {
  my ($self, $filename) = @_;
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

sub _toggleVerbose {
  my ($self) = @_;
  ${ $self->{_CPU} }->{_verbose} = (${ $self->{_CPU} }->{_verbose}+1) % 2;
  return;
}

sub _setReg {
  my ($self, $regIdx, $value) = @_;
  die "Wrong register index: $regIdx, it should be in [0,7]"
    if $regIdx < 0 || $regIdx > 7;
  ${ $self->{_CPU} }->{_registers}[$regIdx] = $value;
  return;
}

sub _dumpStack {
  my ($self) = @_;
  my $i = 0;
  say 'Stack:';
  foreach (${ $self->{_CPU} }->{_stack}->GetStack) {
    say "\tSTACK[$i]: $_";
    $i++;
  }
}

sub _dumpRegisters {
  my ($self) = @_;
  my $i = 0;
  say 'Registers:';
  foreach (@{ ${ $self->{_CPU} }->{_registers} }) {
    say "\tREG[$i]: $_";
    $i++;
  }
}

sub _printAddrs {
  my ($self, $addr, $len) = @_;
  for (0..$len-1) {
    my $value = ${ $self->{_CPU} }->{_memory}[$addr+$_];
    $value = ${ $self->{_CPU} }->_fetch($value);
    if ($value < 0) {
      $value = "$self->{_breakpoints}{$addr+$_} [BP]";
    }
    say "MEM[$addr+$_] = $value";
  }
}

sub _solveCoins {
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

