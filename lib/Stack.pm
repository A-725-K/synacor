package Stack;

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

sub new {
  my ($class) = @_;
  my $self = {
    _stack => [],
  };
  bless $self, $class;
  return $self;
}

sub Push {
  my ($self, $el) = @_;
  push @{ $self->{_stack} }, $el;
  return;
}

sub Pop {
  my ($self) = @_;
  return pop @{ $self->{_stack} };
}

sub Size {
  my ($self) = @_;
  return scalar @{ $self->{_stack} };
}

sub IsEmpty {
  my ($self) = @_;
  return $self->Size == 0;
}

sub GetStack {
  my ($self) = @_;
  return @{ $self->{_stack} };
}

1;

