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

sub GetArgs {
  my ($self, $n) = @_;
  my @args;
  for (1..$n) {
    my $next_arg = $self->{_memory}[$self->{_PC}+$_];
    die "Invalid value in memory" if $next_arg > $MAX_VALUE; 
    if ($next_arg >= $REG_BASE) {
      $next_arg = @{ $self->{_registers} }[$next_arg-$REG_BASE];
    }
    push @args, $next_arg;
  }
  return @args;
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
  # say "PC: $self->{_PC}\tNEXT OP: $next_op" if $self->{_verbose};

  if ($next_op == $Operations::OPCODES->{HALT}) {
    $self->halt; 
  } elsif ($next_op == $Operations::OPCODES->{JMP}) {
    $self->jmp;
  } elsif ($next_op == $Operations::OPCODES->{JT}) {
    $self->jt;
  } elsif ($next_op == $Operations::OPCODES->{JF}) {
    $self->jf;
  } elsif ($next_op == $Operations::OPCODES->{OUT}) {
    $self->out;
  } elsif ($next_op == $Operations::OPCODES->{NOOP}) {
    $self->noop;
  } else {
    die "Operation not known: #OPCODE = $next_op. Segmentation fault at $self->{_PC}";
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

# [6:jmp] -> jump to <a>
sub jmp {
  my ($self) = @_;
  my ($addr) = $self->GetArgs(1);
  say "[$self->{_PC}] #6: jmp $addr" if $self->{_verbose};
  $self->{_PC} = $addr;
  return;
}

# [7:jt] -> if <a> is nonzero, jump to <b>
sub jt {
  my ($self) = @_;
  my ($arg, $addr) = $self->GetArgs(2);
  say "[$self->{_PC}] #7: jt $arg $addr" if $self->{_verbose};
  if ($arg > 0) {
    $self->{_PC} = $addr;
  } else {
    $self->{_PC} += 3;
  }
  return;
}

# [8:jf] -> if <a> is zero, jump to <b>
sub jf {
  my ($self) = @_;
  my ($arg, $addr) = $self->GetArgs(2);
  say "[$self->{_PC}] #8: jf $arg $addr" if $self->{_verbose};
  if ($arg == 0) {
    $self->{_PC} = $addr;
  } else {
    $self->{_PC} += 3;
  }
  return;
}

# [19:out] -> write the character represented by ascii code <a> to the terminal
sub out {
  my ($self) = @_;
  my ($arg) = $self->GetArgs(1);
  say "[$self->{_PC}] #19: out $arg" if $self->{_verbose};
  print chr($arg);
  $self->{_PC} += 2;
  return;
}

# [21:noop] -> no operation
sub noop {
  my ($self) = @_;
  say "[$self->{_PC}] #21: noop" if $self->{_verbose};
  $self->{_PC}++;
  return;
}

1;

