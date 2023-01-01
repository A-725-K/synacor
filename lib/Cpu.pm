package Cpu;

# This file is part of synacor.
#
# synacor is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Softwar
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

sub new {
  my ($class, $_verbose) = @_;

  $_verbose //= 0;

  my $self = {
    # registers
    _reg0 => 0,
    _reg1 => 0,
    _reg2 => 0,
    _reg3 => 0,
    _reg4 => 0,
    _reg5 => 0,
    _reg6 => 0,
    _reg7 => 0,

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

sub ExecNext {
  my ($self) = @_;

  my $next_op = $self->{_memory}[$self->{_PC}];

  if ($next_op == $Operations::OPCODES->{HALT}) {
    say "Executing #0: HALT" if $self->{_verbose};
    $self->halt; 
  } elsif ($next_op == $Operations::OPCODES->{OUT}) {
    say "Executing #19: OUT" if $self->{_verbose};
    $self->out;
  } elsif ($next_op == $Operations::OPCODES->{NOOP}) {
    say "Executing #21: NOOP" if $self->{_verbose};
    $self->noop;
  } else {
    say "Operation not known: #OPCODE = $next_op";
    exit 1;
  }

  return;
}

sub Emulate {
  my ($self) = @_;

  while ($self->{_PC} < $self->{_addresses}) {
    $self->ExecNext;
  }
}

# #################################### #
# implementation of opcodes operations #
# #################################### #

# [0:halt] -> stop execution and terminate the program
sub halt { 
  my ($self) = @_;
  say "Shutting down:";
  for (3..0) {
    say "$_...";
    sleep 1;
  }
  exit 0;
}

# [19:out] -> write the character represented by ascii code <a> to the terminal
sub out {
  my ($self) = @_;

  my $a = chr($self->{_memory}[$self->{_PC}+1]);
  print $a;

  $self->{_PC} += 2;
  return;
}

# [21:noop] -> no operation
sub noop {
  my ($self) = @_;
  $self->{_PC}++;
  return;
}

1;

