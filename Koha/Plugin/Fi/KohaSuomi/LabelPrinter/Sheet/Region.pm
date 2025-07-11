package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region;
# Copyright 2015 KohaSuomi
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

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Dimensions;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Element;

use Koha::Exceptions;

use parent qw(Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasDimensions Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasPosition);

sub new {
    my ($class, $item, $params) = @_;

    my $self = {};
    bless($self, $class);
    $self->setParent($item);
    $self->setId($params->{id});
    $self->setCloneOfId($params->{cloneOfId});
    $self->setDimensions($params->{dimensions});
    $self->setPosition($params->{position}, $item->getParent());
    $self->setBoundingBox($params->{boundingBox});
    $self->setElements($params->{elements});
    return $self;
}
sub toHash {
    my ($self) = @_;
    my $obj = {};
    $obj->{id} = $self->getId();
    $obj->{cloneOfId} = $self->getCloneOfId();
    $obj->{dimensions} = $self->getDimensions()->toHash();
    $obj->{position} = $self->getPosition()->toHash();
    $obj->{boundingBox} = ($self->getBoundingBox() == 1) ? 'true' : 'false';
    $obj->{elements} = [];
    foreach my $element (@{$self->getElements()}) {
        my $ej = $element->toHash();
        push @{$obj->{elements}}, $ej;
    }
    return $obj;
}
sub setId { # New attribute, not present with legacy regions.
    my ($self, $id) = @_;
    if ($id) {
        unless ($id =~ /^\d+$/) {
            Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'id' is not a number");
        }
        $self->{id} = $id;
    }
    else {
        $self->{id} = 0;
    }
}
sub getId {
    my ($self) = @_;
    return $self->{id};
}
sub setCloneOfId { # New attribute, not present with legacy regions.
    my ($self, $cloneOfId) = @_;
    if ($cloneOfId) {
        unless ($cloneOfId =~ /^\d+$/) {
            Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'cloneOfId' is not a number");
        }
        $self->{cloneOfId} = $cloneOfId;
    }
    else {
        $self->{cloneOfId} = 0;
    }
}
sub getCloneOfId {
    my ($self) = @_;
    return $self->{cloneOfId};
}
sub setBoundingBox {
    my ($self, $boundingBox) = @_;
    unless ($boundingBox =~ /^(1|0|true|false)$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'boundingBox' is not 'true|1' or 'false|0'");
    }
    if ($boundingBox =~ /(1|true)/) {
        $self->{boundingBox} = 1;
    }
    else {
        $self->{boundingBox} = 0;
    }
}
sub getBoundingBox { return shift->{boundingBox}; }
sub setElements {
    my ($self, $elements) = @_;
    unless (ref($elements) eq 'ARRAY') {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'elements' is not an array");
    }
    $self->{elements} = [];
    foreach my $element (@$elements) {
        push(@{$self->{elements}}, Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Element->new($self, $element));
    }
}
sub getElements { return shift->{elements}; }
sub setParent {
    my ($self, $item) = @_;
    unless (blessed($item) && $item->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Item')) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__."->setParent($item) Parameter 'parent' is not a Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Item-object");
    }
    $self->{parent} = $item;
}
sub getParent { return shift->{parent}; }
sub getSheet {
    my ($self) = @_;
    return $self->getParent()->getParent();
}
sub getItem {
    my ($self) = @_;
    return $self->getParent();
}

sub cloneElementsToRegion {
    my ($self, $region) = @_;
    unless (blessed($region) && $region->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region')) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__."->cloneElementsToRegion($region) Parameter 'region' is not a Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region-object");
    }
    my $elements = $self->getElements();
    foreach my $element (@$elements) {
        my $newElement = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Element->new($region, $element->toHash());
        push(@{$region->{elements}}, $newElement);
    }
}

return 1;
