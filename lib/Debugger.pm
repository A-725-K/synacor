package Debugger;

# Synacor challenge: implement a CPU emulator for fun and learning purpose.
#
# Copyright (C) 2023 A-725-K (Andrea Canepa)
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

use Queue;
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
  } elsif ($cmd[0] eq 'solvetel') {
    $self->_solveTeleporter;
  } elsif ($cmd[0] eq 'solvemaze') {
    $self->_solveMaze;
  } elsif ($cmd[0] eq 'm') {
    $self->_mirrorStr($cmd[1]);
  } elsif ($cmd[0] eq 'd') {
    $self->_disass($cmd[1], $cmd[2]);
  } elsif ($cmd[0] eq 'h' || $cmd[0] eq 'help' || $cmd[0] eq '?') {
    $self->_help;
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
  } elsif ($cmd[0] eq 'halt') {
    $self->_haltCpu;
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
    say "Command not known, insert again.";
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
sub _help {
  my ($self) = @_;
  my $help_str = <<'EOF';

@@@@@@@@@@@@@@@@@@@@@@@@@
@@@ DEBUGGER COMMANDS @@@
@@@@@@@@@@@@@@@@@@@@@@@@@

=== UTIL ===
  - h, help, ?          print this help message
  - save <FILENAME>     save the CPU state in file <FILENAME>
  - load <FILENAME>     load the CPU state from file <FILENAME>
  - halt                halt the CPU gracefully
  - m <STR>             read the string <STR> as if it was in a mirror
  - v                   toggle verbose mode of CPU to see debug information

=== CPU ===
  - st                  dump the content of the stack
  - reg                 display the registers and their content
  - setreg <IDX> <VAL>  set register <IDX> to value <VAL>
  - b <ADDR>            set breakpoint to address <ADDR>, if there was already
                        a breakpoint set, remove it
  - s                   run a single instruction
  - x <ADDR>            dump the content of memory ad address <ADDR>
  - p <NUM>             dump the content of <NUM> memory addresses starting
                        from PC (Program Counter)
  - d <ADDR> <NUM>      disassemble <NUM> instructions starting from address
                        <ADDR>
  - w <ADDR> <VAL>      write value <VAL> in memory at address <ADDR>

=== SOLVERS ===
  - solvecoins          solve coins riddle and display the solution
  - solvetel            solve teleporter riddle and display the solution
                        (/!\ TAKES LONG TIME! BE CAREFUL! /!\)
  - solvemaze           solve maze riddle and display the solution
EOF
  say $help_str;
  return;
}

sub _haltCpu {
  my ($self) = @_;
  ${ $self->{_CPU} }->_halt;
  return;
}

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
  my $mod = ${ $self->{_CPU} }->{_MOD};
  if ($addr >= $mod) {
    $addr -= $mod;
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

# ################## #
# Coin puzzle solver #
# ################## #
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

# ######################## #
# Teleporter riddle solver #
# ######################## #
sub _memoAck {
  my ($self, $r0, $r1, $r7, $memo, $mod) = @_;

  no warnings 'recursion';

  if (exists $memo->{"$r0:$r1"}) {
    return $memo->{"$r0:$r1"};
  }

  my $res;
  if ($r0 == 0) {
    $res = ($r1+1) % $mod;
    $memo->{"$r0:$r1"} = $res;
    return $res;
  }

  if ($r1 == 0) {
    my $r0Tmp = ($r0-1) % $mod;
    $res = $self->_memoAck($r0Tmp, $r7, $r7, $memo, $mod);
    $memo->{"$r0Tmp:$r7"} = $res;
    return $res;
  }

  my $r0Tmp = $r0;
  my $r1Tmp = ($r1-1) % $mod;
  $r0 = $self->_memoAck($r0Tmp, $r1Tmp, $r7, $memo, $mod);
  $memo->{"$r0Tmp:$r1Tmp"} = $r0;
  $r0Tmp = ($r0Tmp-1) % $mod;
  $res = $self->_memoAck($r0Tmp, $r0, $r7, $memo, $mod);
  $memo->{"$r0Tmp:$r0"} = $res;

  return $res;
}

sub _rangeMemoAck {
  my ($self, $id, $start, $end, $mod) = @_;

  for (my $r7 = $start; $r7 < $end; $r7++) {
    my %memo;
    my $res = $self->_memoAck(4, 1, $r7, \%memo, $mod);

    say "[$id] Testing $r7..." if ($r7%300) == 0;

    if ($res == 6) {
      say "Result: {$r7} found in process [$id]";
      return $r7;
    }
  }

  return undef;
}

sub _solveTeleporter {
  my ($self) = @_;

  my $procs = [];
  my $mod = ${ $self->{_CPU} }->{_MOD};

  local $SIG{CHLD} = 'IGNORE';
  local $SIG{ALRM} = sub {
    kill 'SIGKILL', @$procs;
  };

  for (my $i = 0; $i < 8; $i++) {
    my $start = $mod/8*$i;
    my $end = $mod/8*($i+1);

    my $pid = fork();
    die "Cannot fork: $!" if !defined $pid;

    if ($pid == 0) {
      # CHILD PROCESS
      my $res = $self->_rangeMemoAck($i, $start, $end, $mod);
      if (defined $res) {
        say ">>> Result is $res";
        kill 'SIGALRM', getppid;
      }
    } else {
      # PARENT PROCESS
      push @$procs, $pid;
    }
  }

  wait for @$procs;
  return;
}

# #################### #
# Orb challenge solver #
# #################### #
sub _mirrorStr {
  my ($self, $s) = @_;
  if (!defined $s) {
    say "You must provide a string to reverse!";
    return;
  }
  $s = scalar reverse $s;
  my @chars = split //, $s;
  while (my ($i, $c) = each @chars) {
    if ($c eq 'b') {
      $chars[$i] = 'd';
    } elsif ($c eq 'd') {
      $chars[$i] = 'b'
    } elsif ($c eq 'q') {
      $chars[$i] = 'p';
    } elsif ($c eq 'p') {
      $chars[$i] = 'q';
    }
  }
  $s = join '', @chars;
  say "$s -> ", scalar reverse $s;
  return;
}

sub _isValid {
  my ($self, $x, $y) = @_;
  return $x >= 0 && $x <= 3 && $y >= 0 && $y <= 3;
}

sub _isOperand {
  my ($self, $c) = @_;
  return $c eq '+' || $c eq '-' || $c eq '*';
}

sub _findPath {
  my ($self, $goal, @maze) = @_;

  my ($start_x, $start_y) = (0, 3);
  my ($end_x, $end_y) = (3, 0);
  my $hit_start = 0;
  my $min_lvl = 999;
  my @paths;

  my $q = Queue->new;
  $q->Enqueue([0, $start_x, $start_y, '+', 0, ('take orb (0,3) [22]')]);
  
  until ($q->IsEmpty) {
    my ($value, $x, $y, $prev_op, $lvl, @p) = @{ $q->Dequeue };

    # do the operation
    my ($next_op, $next_value, $curr) = ('', $value, $maze[$y][$x]);
    if ($self->_isOperand($curr)) {
      $next_op = $curr;
    } else {
      if ($prev_op eq '+') {
        $next_value += $curr;
      } elsif ($prev_op eq '-') {
        $next_value -= $curr;
      } elsif ($prev_op eq '*') {
        $next_value *= $curr;
      } else {
        say "Invalid operation: $curr";
        return ();
      }
    }

    # it is possible to walk on the final tile only once
    if ($x == $end_x && $y == $end_y) {
      # can open the secret vault
      if ($next_value == $goal && $lvl <= $min_lvl) {
        $min_lvl = $lvl;
        say '>>>>>>>>>>> FOUND A PATH!';
        push @paths, \@p;
      }
      # ended up in the final tile with a wrong orb weight, discard this path
      next;
    }

    # if the current level is greater than the min path already found
    # that path won't be the correct one
    next if $lvl > $min_lvl;

    # if the orb is too heavy or too light, I assume there is no solution down
    # that path
    next if $value > 60 || $value < 0;

    # it is possible to walk on start tile only once
    next if $hit_start++ && $x == $start_x && $y == $start_y;

    # try to walk east
    if ($self->_isValid($x+1, $y)) {
      my @new_path = @p;
      push @new_path, sprintf(
        "east (%d,%d) [%s] {%d}",
        $x+1, $y,
        $maze[$y][$x+1],
        $next_value,
      );
      $q->Enqueue([$next_value, $x+1, $y, $next_op, $lvl+1, @new_path]);
    }

    # try to walk west
    if ($self->_isValid($x-1, $y)) {
      my @new_path = @p;
      push @new_path, sprintf(
        "west (%d,%d) [%s] {%d}",
        $x-1, $y,
        $maze[$y][$x-1],
        $next_value,
      );
      $q->Enqueue([$next_value, $x-1, $y, $next_op, $lvl+1, @new_path]);
    }

    # try to walk south
    if ($self->_isValid($x, $y+1)) {
      my @new_path = @p;
      push @new_path, sprintf(
        "south (%d,%d) [%s] {%d}",
        $x, $y+1,
        $maze[$y+1][$x],
        $next_value,
      );
      $q->Enqueue([$next_value, $x, $y+1, $next_op, $lvl+1, @new_path]);
    }

    # try to walk north
    if ($self->_isValid($x, $y-1)) {
      my @new_path = @p;
      push @new_path, sprintf(
        "north (%d,%d) [%s] {%d}",
        $x, $y-1,
        $maze[$y-1][$x],
        $next_value,
      );
      $q->Enqueue([$next_value, $x, $y-1, $next_op, $lvl+1, @new_path]);
    }
  }

  return @paths;
}

sub _solveMaze {
  my ($self) = @_;

  my @maze = (
    ['*', '8', '-', '1'],
    ['4', '*', '11', '*'],
    ['+', '4', '-', '18'],
    ['22', '-', '9', '*'],
  );

  for (my $y = 0; $y < 4; $y++) {
    for (my $x = 0; $x < 4; $x++) {
      printf "[%2s]", $maze[$y][$x];
    }
    say '';
  }
  say '';

  my @paths = $self->_findPath(30, @maze);
  while (my ($i, $path) = each @paths) {
    say "\n[$i] Path of length: ", scalar @$path - 1;
    foreach my $step (@$path) {
      say "  $step";
    }
  }

  return;
}

1;

