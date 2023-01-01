package Cpu;

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

use File::Basename;
use lib dirname (__FILE__);

use Stack;
use Operations;

our $MOD = 32768;
our $REG_BASE = 32768;
our $MAX_VALUE = 32775;

sub new {
  my ($class, $_verbose) = @_;

  $_verbose //= 0;

  my $self = {
    # registers
    _registers => [0, 0, 0, 0, 0, 0, 0, 0],

    # unbounded stack
    _stack => Stack->new,

    # 15-bit address memory
    _memory => [],

    # program counter, keep track of the address in memory
    _PC => 0,

    # utilities
    _verbose => $_verbose,
    _addresses => 0,
  };
  bless $self, $class;
  return $self;
}

sub LoadFile {
  my ($self, $filename) = @_;

  open my $f, '<', $filename or die("Cannot open challenge file: $filename");
  binmode $f;

  while (read $f, my $next_value, 2) {
    $next_value = unpack 'S', $next_value;
    push @{ $self->{_memory} }, $next_value;
    $self->{_addresses}++;
  }

  close $f;
}

sub Emulate {
  my ($self) = @_;

  while ($self->{_PC} < $self->{_addresses}) {
    $self->_execNext;
  }
}

# ################### #
# private subroutines #
# ################### #
sub _execNext {
  my ($self) = @_;

  my $next_op = $self->{_memory}[$self->{_PC}];
  # say "PC: $self->{_PC}\tNEXT OP: $next_op" if $self->{_verbose};

  if ($next_op == $Operations::OPCODES->{HALT}) {
    $self->_halt;
  } elsif ($next_op == $Operations::OPCODES->{EQ}) {
    $self->_eq;
  } elsif ($next_op == $Operations::OPCODES->{GT}) {
    $self->_gt;
  } elsif ($next_op == $Operations::OPCODES->{SET}) {
    $self->_set;
  } elsif ($next_op == $Operations::OPCODES->{JMP}) {
    $self->_jmp;
  } elsif ($next_op == $Operations::OPCODES->{JT}) {
    $self->_jt;
  } elsif ($next_op == $Operations::OPCODES->{JF}) {
    $self->_jf;
  } elsif ($next_op == $Operations::OPCODES->{ADD}) {
    $self->_add;
  } elsif ($next_op == $Operations::OPCODES->{OUT}) {
    $self->_out;
  } elsif ($next_op == $Operations::OPCODES->{NOOP}) {
    $self->_noop;
  } else {
    my @regs = @{ $self->{_registers} };
    say "REGISTERS ===> @regs";
    die "Operation not known: #OPCODE = $next_op. Segmentation fault at $self->{_PC}";
  }

  return;
}

sub _getRegIndex {
  my ($self, $arg) = @_;
  return $arg-$REG_BASE;
}

sub _fetch {
  my ($self, $arg) = @_;
  if ($arg >= $REG_BASE) {
    $arg = @{ $self->{_registers} }[$self->_getRegIndex($arg)];
  }
  return $arg;
}

sub _getArgs {
  my ($self, $n) = @_;
  my @args;
  for (1..$n) {
    my $next_arg = $self->{_memory}[$self->{_PC}+$_];
    die "Invalid value in memory" if $next_arg > $MAX_VALUE;
    push @args, $next_arg;
  }
  return @args;
}

sub _storeInReg {
  my ($self, $reg_idx, $value) = @_;
  @{ $self->{_registers} }[$reg_idx] = $value;
  return;
}

# #################################### #
# implementation of opcodes operations #
# #################################### #

# [0:halt] -> stop execution and terminate the program
sub _halt {
  my ($self) = @_;
  say "[$self->{_PC}] #0: halt" if $self->{_verbose};
  say "\n"."#"x30;
  say "Shutting down the emulator!";
  for (my $t = 3; $t > 0; $t--) {
    say "\t  $t...";
    sleep 1;
  }
  say "Bye!";
  say "#"x30;
  exit 0;
}

# [1:set] -> set register <a> to the value of <b>
sub _set {
  my ($self) = @_;
  my ($reg, $value) = $self->_getArgs(2);
  $reg = $self->_getRegIndex($reg);
  $value = $self->_fetch($value);
  say "[$self->{_PC}] #1: set $reg $value" if $self->{_verbose};
  @{ $self->{_registers} }[$reg] = $value;
  $self->{_PC} += 3;
  return;
}

# [4:eq] -> set <a> to 1 if <b> is equal to <c>; set it to 0 otherwise
sub _eq {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #4: eq $dest $op1 $op2" if $self->{_verbose};
  my $result = $op1 == $op2 ? 1 : 0;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [5:gt] -> set <a> to 1 if <b> is greater than <c>; set it to 0 otherwise
sub _gt {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #5: gt $dest $op1 $op2" if $self->{_verbose};
  my $result = $op1 > $op2 ? 1 : 0;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [6:jmp] -> jump to <a>
sub _jmp {
  my ($self) = @_;
  my ($addr) = $self->_getArgs(1);
  $addr = $self->_fetch($addr);
  say "[$self->{_PC}] #6: jmp $addr" if $self->{_verbose};
  $self->{_PC} = $addr;
  return;
}

# [7:jt] -> if <a> is nonzero, jump to <b>
sub _jt {
  my ($self) = @_;
  my ($arg, $addr) = $self->_getArgs(2);
  $arg = $self->_fetch($arg);
  $addr = $self->_fetch($addr);
  say "[$self->{_PC}] #7: jt $arg $addr" if $self->{_verbose};
  if ($arg > 0) {
    $self->{_PC} = $addr;
  } else {
    $self->{_PC} += 3;
  }
  return;
}

# [8:jf] -> if <a> is zero, jump to <b>
sub _jf {
  my ($self) = @_;
  my ($arg, $addr) = $self->_getArgs(2);
  $arg = $self->_fetch($arg);
  $addr = $self->_fetch($addr);
  say "[$self->{_PC}] #8: jf $arg $addr" if $self->{_verbose};
  if ($arg == 0) {
    $self->{_PC} = $addr;
  } else {
    $self->{_PC} += 3;
  }
  return;
}

# [9:add] -> assign into <a> the sum of <b> and <c> (modulo 32768)
sub _add {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #9: add $dest $op1 $op2" if $self->{_verbose};
  my $result = ($op1 + $op2) % $MOD;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [19:out] -> write the character represented by ascii code <a> to the terminal
sub _out {
  my ($self) = @_;
  my ($arg) = $self->_getArgs(1);
  $arg = $self->_fetch($arg);
  say "[$self->{_PC}] #19: out $arg" if $self->{_verbose};
  print chr($arg);
  $self->{_PC} += 2;
  return;
}

# [21:noop] -> no operation
sub _noop {
  my ($self) = @_;
  say "[$self->{_PC}] #21: noop" if $self->{_verbose};
  $self->{_PC}++;
  return;
}

1;

