package Cpu;

# Synacor challenge: implement a CPU emulator for fun and learning purpose.
#
# Copyright (C) 2022 A-725-K (Andrea Canepa)
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

use v5.36;
use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__);

use Stack;
use Debugger;
use Operations;

our $MOD = 32768;
our $REG_BASE = 32768;
our $MAX_VALUE = 32775;

sub new {
  my ($class, $_verbose) = @_;

  $_verbose //= 0;

  my $self;

  $self = {
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
    _debugger => Debugger->new(\$self),
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
  return;
}

sub Emulate {
  my ($self) = @_;

  while ($self->{_PC} < $self->{_addresses}) {
    $self->_execNext;
  }

  return;
}

# ################### #
# private subroutines #
# ################### #
sub _execNext {
  my ($self) = @_;

  my $next_op = $self->{_memory}[$self->{_PC}];

  if ($next_op == $Operations::OPCODES->{HALT}) { # 0
    $self->_halt;
  } elsif ($next_op == $Operations::OPCODES->{SET}) { # 1
    $self->_set;
  } elsif ($next_op == $Operations::OPCODES->{PUSH}) { # 2
    $self->_push;
  } elsif ($next_op == $Operations::OPCODES->{POP}) { # 3
    $self->_pop;
  } elsif ($next_op == $Operations::OPCODES->{EQ}) { # 4
    $self->_eq;
  } elsif ($next_op == $Operations::OPCODES->{GT}) { # 5
    $self->_gt;
  } elsif ($next_op == $Operations::OPCODES->{JMP}) { # 6
    $self->_jmp;
  } elsif ($next_op == $Operations::OPCODES->{JT}) { # 7
    $self->_jt;
  } elsif ($next_op == $Operations::OPCODES->{JF}) { # 8
    $self->_jf;
  } elsif ($next_op == $Operations::OPCODES->{ADD}) { # 9
    $self->_add;
  } elsif ($next_op == $Operations::OPCODES->{MULT}) { # 10
    $self->_mult;
  } elsif ($next_op == $Operations::OPCODES->{MOD}) { # 11
    $self->_mod;
  } elsif ($next_op == $Operations::OPCODES->{AND}) { # 12
    $self->_and;
  } elsif ($next_op == $Operations::OPCODES->{OR}) { # 13
    $self->_or;
  } elsif ($next_op == $Operations::OPCODES->{NOT}) { # 14
    $self->_not;
  } elsif ($next_op == $Operations::OPCODES->{RMEM}) { # 15
    $self->_rmem;
  } elsif ($next_op == $Operations::OPCODES->{WMEM}) { # 16
    $self->_wmem;
  } elsif ($next_op == $Operations::OPCODES->{CALL}) { # 17
    $self->_call;
  } elsif ($next_op == $Operations::OPCODES->{RET}) { # 18
    $self->_ret;
  } elsif ($next_op == $Operations::OPCODES->{OUT}) { # 19
    $self->_out;
  } elsif ($next_op == $Operations::OPCODES->{IN}) { # 20
    $self->_in;
  } elsif ($next_op == $Operations::OPCODES->{NOOP}) { # 21
    $self->_noop;
  } elsif ($next_op == $Operations::OPCODES->{BP}) { # -1
    $self->{_debugger}->HandleBreakpoint;
  } else {
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
  $self->_storeInReg($reg, $value);
  $self->{_PC} += 3;
  return;
}

# [2:push] -> push <a> onto the stack
sub _push {
  my ($self) = @_;
  my ($arg) = $self->_getArgs(1);
  $arg = $self->_fetch($arg);
  say "[$self->{_PC}] #2: push $arg" if $self->{_verbose};
  $self->{_stack}->Push($arg);
  $self->{_PC} += 2;
  return;
}

# [3:pop] -> pop: 3 a remove the top element from the stack and write it into
#            <a>; empty stack = error
sub _pop {
  my ($self) = @_;
  my ($reg) = $self->_getArgs(1);
  $reg = $self->_getRegIndex($reg);
  say "[$self->{_PC}] #3: pop $reg" if $self->{_verbose};
  die "Error: Cannot pop from empty stack" if $self->{_stack}->IsEmpty;
  my $value = $self->{_stack}->Pop;
  $self->_storeInReg($reg, $value);
  $self->{_PC} += 2;
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

# [10:mult] -> store into <a> the product of <b> and <c> (modulo 32768)
sub _mult {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #10: mult $dest $op1 $op2" if $self->{_verbose};
  my $result = ($op1 * $op2) % $MOD;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [11:mod] -> store into <a> the remainder of <b> divided by <c>
sub _mod {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #11: mod $dest $op1 $op2" if $self->{_verbose};
  my $result = $op1 % $op2;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [12:and] -> stores into <a> the bitwise and of <b> and <c>
sub _and {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #12: and $dest $op1 $op2" if $self->{_verbose};
  my $result = $op1 & $op2;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [13:or] -> stores into <a> the bitwise or of <b> and <c>
sub _or {
  my ($self) = @_;
  my ($dest, $op1, $op2) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $op1 = $self->_fetch($op1);
  $op2 = $self->_fetch($op2);
  say "[$self->{_PC}] #13: or $dest $op1 $op2" if $self->{_verbose};
  my $result = $op1 | $op2;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 4;
  return;
}

# [14:not] -> stores 15-bit bitwise inverse of <b> in <a>
sub _not {
  my ($self) = @_;
  my ($dest, $arg) = $self->_getArgs(3);
  $dest = $self->_getRegIndex($dest);
  $arg = $self->_fetch($arg);
  say "[$self->{_PC}] #14: not $dest $arg" if $self->{_verbose};
  my $result = ~$arg & 0x7fff;
  $self->_storeInReg($dest, $result);
  $self->{_PC} += 3;
  return;
}

# [15:rmem] -> read memory at address <b> and write it to <a>
sub _rmem {
  my ($self) = @_;
  my ($dest, $addr) = $self->_getArgs(2);
  $dest = $self->_getRegIndex($dest);
  $addr = $self->_fetch($addr);
  say "[$self->{_PC}] #15: rmem $dest $addr" if $self->{_verbose};
  $self->_storeInReg($dest, $self->{_memory}[$addr]);
  $self->{_PC} += 3;
  return;
}

# [16:wmem] -> write the value from <b> into memory at address <a>
sub _wmem {
  my ($self) = @_;
  my ($dest, $src) = $self->_getArgs(2);
  $dest = $self->_fetch($dest);
  $src = $self->_fetch($src);
  say "[$self->{_PC}] #16: wmem $dest $src" if $self->{_verbose};
  $self->{_memory}[$dest] = $src;
  $self->{_PC} += 3;
  return;
}

# [17:call] -> write the address of the next instruction to the stack and
#              jump to <a>
sub _call {
  my ($self) = @_;
  my ($addr) = $self->_getArgs(1);
  $addr = $self->_fetch($addr);
  say "[$self->{_PC}] #17: call $addr" if $self->{_verbose};
  $self->{_stack}->Push($self->{_PC}+2);
  $self->{_PC} = $addr;
  return;
}

# [18:ret] -> remove the top element from the stack and jump to it;
#             empty stack = halt
sub _ret {
  my ($self) = @_;
  say "[$self->{_PC}] #18: ret" if $self->{_verbose};
  $self->halt if $self->{_stack}->IsEmpty;
  my ($addr) = $self->{_stack}->Pop;
  $self->{_PC} = $addr;
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

# [20:in] -> read a character from the terminal and write its ascii code to
#            <a>; it can be assumed that once input starts, it will continue
#            until a newline is encountered; this means that you can safely
#            read whole lines from the keyboard and trust that they will be
#            fully read
sub _in {
  my ($self) = @_;
  my ($reg) = $self->_getArgs(1);
  $reg = $self->_getRegIndex($reg);
  say "[$self->{_PC}] #20: in $reg" if $self->{_verbose};
  my $c;
  while (!defined $c) {
    $c = getc(STDIN);
  }
  if ($c eq '@') {
    chomp(my $dbg_cmd = <>);
    $self->{_debugger}->RunCmd($dbg_cmd);
    return;
  }
  $self->_storeInReg($reg, ord($c));
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

