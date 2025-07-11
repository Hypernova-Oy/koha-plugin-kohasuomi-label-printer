package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasDimensions;
# Copyright 2025 Hypernova Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use warnings;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Dimensions;

sub setDimensions {
    my ($self, $dimensions) = @_;
    $self->{dimensions} = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Dimensions->new($dimensions);
}
sub getDimensions { return $_[0]->{dimensions}; }
sub getPdfDimensions {return $_[0]->{dimensions}->getPdfDimensions()};

1;
