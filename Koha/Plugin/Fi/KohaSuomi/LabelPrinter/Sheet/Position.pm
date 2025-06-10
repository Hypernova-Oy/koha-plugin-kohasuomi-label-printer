package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Position;
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
  my ($class, $positionInMMOrLeft, $optionalTopInMM, $parent, $origo) = @_;

  my $self = bless({}, $class);
  if (ref($positionInMMOrLeft) eq 'HASH' || ref($positionInMMOrLeft) eq 'Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Position') {
    $self->{left} = $positionInMMOrLeft->{left};
    $self->{top} = $positionInMMOrLeft->{top};
  }
  elsif (ref($positionInMMOrLeft) eq 'ARRAY') {
    $self->{left} = $positionInMMOrLeft->[0];
    $self->{top} = $positionInMMOrLeft->[1];
  }
  else {
    $self->{left} = $positionInMMOrLeft;
    $self->{top} = $optionalTopInMM;
  }

  unless ($self->{left} =~ /^\d+\.?\d*$/) {
    Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'dimensions' has bad left '".($self->{left} ? $self->{left} : 'undef')."'.");
  }
  unless ($self->{top} =~ /^\d+\.?\d*$/) {
    Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'dimensions' has bad top '".($self->{top} ? $self->{top} : 'undef')."'.");
  }
  if ($parent && $origo) {
    Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Both paramters \$parent and \$origo must not be given! Origo is already calculated in the parent.");
  }

  if ($parent) {
    my $parentPos = $parent->getPdfPosition();
    $self->{x} = $parentPos->{x} + mm2p($self->{left});
    $self->{y} = $parentPos->{y} - mm2p($self->{top});
  }
  elsif ($origo) {
    $self->{x} = mm2p($self->{left} + $origo->[0]);
    $self->{y} = mm2p($self->{top} + $origo->[1]);
  }
  else {
    $self->{x} = mm2p($self->{left});
    $self->{y} = mm2p($self->{top});
  }

  return $self;
}
sub toHash {
  my ($self) = @_;
  my $obj = {};
  $obj->{left} = $self->getLeft();
  $obj->{top} = $self->getTop();
  return $obj;
}

sub getLeft {return $_[0]->{left}}
sub getTop {return $_[0]->{top}}
sub getPdfX {return $_[0]->{x}}
sub getPdfY {return $_[0]->{y}}
sub getPdfPosition {return {x => $_[0]->{x}, y => $_[0]->{y}}}

1;
