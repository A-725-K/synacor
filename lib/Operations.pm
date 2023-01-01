package Operations;

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

our $OPCODES = {
  HALT => 0,
  SET => 1,
  PUSH => 2,
  POP => 3,
  EQ => 4,
  GT => 5,
  JMP => 6,
  JT => 7,
  JF => 8,
  ADD => 9,
  MULT => 10,
  MOD => 11,
  AND => 12,
  OR => 13,
  NOT => 14,
  RMEM => 15,
  WMEM => 16,
  CALL => 17,
  RET => 18,
  OUT => 19,
  NOOP => 21,
};

1;

