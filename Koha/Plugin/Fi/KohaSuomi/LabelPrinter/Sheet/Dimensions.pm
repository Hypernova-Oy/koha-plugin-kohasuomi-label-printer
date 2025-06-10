package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Dimensions;
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

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfUtil qw(mm2p);

use Koha::Exceptions::BadParameter;

sub new {
    my ($class, $dimensionsInMMOrWidth, $optionalHeightInMM) = @_;

    my $self = bless({}, $class);
    if (ref($dimensionsInMMOrWidth) eq 'HASH' || ref($dimensionsInMMOrWidth) eq 'Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Dimensions') {
      $self->{width} = $dimensionsInMMOrWidth->{width};
      $self->{height} = $dimensionsInMMOrWidth->{height};
    }
    elsif (ref($dimensionsInMMOrWidth) eq 'ARRAY') {
      $self->{width} = $dimensionsInMMOrWidth->[0];
      $self->{height} = $dimensionsInMMOrWidth->[1];
    }
    else {
      $self->{width} = $dimensionsInMMOrWidth;
      $self->{height} = $optionalHeightInMM;
    }

    unless ($self->{width} =~ /^\d+\.?\d*$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'dimensions' has bad width '".($self->{width} ? $self->{width} : 'undef')."'");
    }
    unless ($self->{height} =~ /^\d+\.?\d*$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'dimensions' has bad height '".($self->{height} ? $self->{height} : 'undef')."'");
    }

    $self->{pdfWidth} = mm2p($self->{width});
    $self->{pdfHeight} = mm2p($self->{height});

    return $self;
}
sub toHash {
    my ($self) = @_;
    my $obj = {};
    $obj->{width} = $self->getWidth();
    $obj->{height} = $self->getHeight();
    return $obj;
}

sub getWidth {return $_[0]->{width}}
sub getHeight {return $_[0]->{height}}
sub getPdfWidth {return $_[0]->{pdfWidth}}
sub getPdfHeight {return $_[0]->{pdfHeight}}
sub getPdfDimensions {return {width => $_[0]->{pdfWidth}, height => $_[0]->{pdfHeight}}}

1;
