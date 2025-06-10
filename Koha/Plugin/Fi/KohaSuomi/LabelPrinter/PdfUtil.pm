package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfUtil;
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
use Scalar::Util qw(blessed);
use Try::Tiny;

use Koha::Logger;
use Log::Log4perl::Level;
our $log = Koha::Logger->get({category => __PACKAGE__});

our @EXPORT = qw(mm2p);
use Exporter 'import';

=head2 mm2p

Postfix standard (.pdf uses it) defines a static DPI, which is 72 points per inch.
All measurements in the Sheets are in millimetres.
This converts mm to postfix points.

=cut

sub mm2p {
    my ($mm) = @_;
    return $mm * (72 / 25.4);
}

return 1;
