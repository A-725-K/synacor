package Operations;

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

our $OPCODES = {
  HALT => 0,
  SET => 1,
  EQ => 4,
  GT => 5,
  JMP => 6,
  JT => 7,
  JF => 8,
  ADD => 9,
  OUT => 19,
  NOOP => 21,
};

1;

