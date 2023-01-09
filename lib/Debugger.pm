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

use Operations;
use Algorithm::Permute;

sub new {
  my ($class, $cpu) = @_;

  my $self = {
    _breakpoints => {},
    _CPU => $cpu,
  };

  bless $self, $class;
  return $self;
}

sub RunCmd {
  my ($self, $line) = @_;

  my @cmd = split ' ', $line;
  $cmd[0] //= '';

  if ($cmd[0] eq 'solvecoins') {
    $self->_solveCoins;
  } elsif ($cmd[0] eq 'd') {
    $self->_disass($cmd[1], $cmd[2]);
  } elsif ($cmd[0] eq 's') {
    $self->_step;
  } elsif ($cmd[0] eq 'b') {
    $self->_setUnsetBreakpoint($cmd[1]);
  } elsif ($cmd[0] eq 'w') {
    $self->_patchMem($cmd[1], $cmd[2]);
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

  print '*DBG* ?- ';
  my $dbg_cmd = '';
  while (chomp($dbg_cmd = <>)) {
    if ($dbg_cmd eq 'c') {
      last;
    }
    $self->RunCmd($dbg_cmd);
    print '*DBG* ?- ';
  }

  my $cpu = ${ $self->{_CPU} };
  if (exists $self->{_breakpoints}{$cpu->{_PC}}) {
    $self->_stepOverBreakpoint;
  }
  return;
}

# ############################################ #
# private subroutines and debugger opearations #
# ############################################ #
sub _patchMem {
  my ($self, $addr, $val) = @_;
  if (!defined $addr || !defined $val) {
    say "You should provide address and value to patch the memory!";
    return;
  }
  ${ $self->{_CPU} }->{_memory}[$addr] = $val;
  return;
}

sub _fetch {
  my ($self, $addr) = @_;
  if ($addr >= 32768) {
    $addr -= 32768;
    $addr = "r$addr";
  }
  return $addr;
}

# disassemble instructions, not all of the instructions are useful to
# decode the interesting routine, disregarding breakpoints
sub _disass {
  my ($self, $addr, $instr_n) = @_;
  if (!defined $addr || !defined $instr_n) {
    say "You should provide base address and number of instructions!";
    return;
  }

  my @mem = @{ ${ $self->{_CPU} }->{_memory} };
  for (1..$instr_n) {
    if ($mem[$addr] == $Operations::OPCODES->{JF}) {
      my $reg = $self->_fetch($mem[$addr+1]);
      say "MEM[$addr]: jf $reg $mem[$addr+2]";
      $addr += 3;
    } elsif ($mem[$addr] == $Operations::OPCODES->{JT}) {
      my $reg = $self->_fetch($mem[$addr+1]);
      say "MEM[$addr]: jt $reg $mem[$addr+2]";
      $addr += 3;
    } elsif ($mem[$addr] == $Operations::OPCODES->{ADD}) {
      my $reg = $self->_fetch($mem[$addr+1]);
      my $op1 = $self->_fetch($mem[$addr+2]);
      my $op2 = $self->_fetch($mem[$addr+3]);
      if ($op2 == 32767) {
        $op2 = -1
      }
      say "MEM[$addr]: add $reg $op1 $op2";
      $addr += 4;
    } elsif ($mem[$addr] == $Operations::OPCODES->{RET}) {
      say "MEM[$addr]: ret";
      $addr++;
    } elsif ($mem[$addr] == $Operations::OPCODES->{PUSH}) {
      my $op1 = $self->_fetch($mem[$addr+1]);
      say "MEM[$addr]: push $op1";
      $addr += 2;
    } elsif ($mem[$addr] == $Operations::OPCODES->{POP}) {
      my $op1 = $self->_fetch($mem[$addr+1]);
      say "MEM[$addr]: pop $op1";
      $addr += 2;
    } elsif ($mem[$addr] == $Operations::OPCODES->{CALL}) {
      my $op1 = $self->_fetch($mem[$addr+1]);
      say "MEM[$addr]: call $op1";
      $addr += 2;
    } elsif ($mem[$addr] == $Operations::OPCODES->{SET}) {
      my $op1 = $self->_fetch($mem[$addr+1]);
      my $op2 = $self->_fetch($mem[$addr+2]);
      say "MEM[$addr]: set $op1 $op2";
      $addr += 3;
    } elsif ($mem[$addr] == $Operations::OPCODES->{EQ}) {
      my $reg = $self->_fetch($mem[$addr+1]);
      my $op1 = $self->_fetch($mem[$addr+2]);
      my $op2 = $self->_fetch($mem[$addr+3]);
      say "MEM[$addr]: eq $reg $op1 $op2";
      $addr += 4;
    } else {
      say "UNKN: $mem[$addr]";
    }
  }

  return;
}

sub _stepOverBreakpoint {
  my ($self) = @_;
  my $cpu = ${ $self->{_CPU} };
  my $bp_addr = $cpu->{_PC};
  my $old_instr = $self->{_breakpoints}{$bp_addr};
  $cpu->{_memory}[$bp_addr] = $old_instr;
  $cpu->_execNext;
  $cpu->{_memory}[$bp_addr] = -1;
  return;
}


sub _step {
  my ($self) = @_;
  my $cpu = ${ $self->{_CPU} };
  if (exists $self->{_breakpoints}{$cpu->{_PC}}) {
    $self->_stepOverBreakpoint;
  } else {
    $cpu->_execNext;
  }
  return;
}

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
  return;
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
  return;
}

sub _toggleVerbose {
  my ($self) = @_;
  ${ $self->{_CPU} }->{_verbose} = (${ $self->{_CPU} }->{_verbose}+1) % 2;
  return;
}

sub _setReg {
  my ($self, $regIdx, $value) = @_;
  if ($regIdx < 0 || $regIdx > 7) {
    say "Wrong register index: $regIdx, it should be in [0,7]";
    return;
  }
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
  return;
}

sub _dumpRegisters {
  my ($self) = @_;
  my $i = 0;
  say 'Registers:';
  foreach (@{ ${ $self->{_CPU} }->{_registers} }) {
    say "\tREG[$i]: $_";
    $i++;
  }
  return;
}

sub _printAddrs {
  my ($self, $addr, $len) = @_;
  if (!defined $addr) {
    say 'No address provided.';
    return;
  }
  for (0..$len-1) {
    my $value = ${ $self->{_CPU} }->{_memory}[$addr+$_];
    $value = ${ $self->{_CPU} }->_fetch($value);
    if ($value < 0) {
      $value = "$self->{_breakpoints}{$addr+$_} [BP]";
    }
    say "MEM[$addr+$_] = $value";
  }
  return;
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

