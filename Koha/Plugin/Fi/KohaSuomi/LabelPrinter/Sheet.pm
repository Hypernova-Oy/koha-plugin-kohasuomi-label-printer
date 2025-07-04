package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet;
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

use DateTime;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Item;
use C4::Context;

use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Exceptions;

use parent qw(Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasDimensions Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasPosition);

sub new {
    my ($class, $params) = @_;

    my $self = {};
    bless($self, $class);
    $self->setName($params->{name});
    $self->setId($params->{id});
    $self->setSchema($params->{schema});
    $self->setGrid($params->{grid});
    $self->setDimensions($params->{dimensions});
    $self->setPosition();
    $self->setVersion($params->{version});
    $self->setAuthor($params->{author});
    $self->setTimestamp($params->{timestamp});
    $self->setBoundingBox($params->{boundingBox});
    $self->setItems($params->{items});
    return $self;
}

=head toJSON

Use this to serialize this object and all attached components, items, regions and elements.

=cut

sub toJSON {
    my ($self) = @_;
    my $obj = $self->toHash();
    my $json = JSON::XS->new()->encode($obj);
    return $json;
}
=head toHash
Strips special object-stuff and returns a simplified easy-to-JSON hash.
=cut
sub toHash {
    my ($self) = @_;
    my $obj = {};
    $obj->{id} = $self->getId();
    $obj->{schema} = $self->getSchema();
    $obj->{grid} = $self->getGrid();
    $obj->{name} = $self->getName();
    $obj->{dimensions} = $self->getDimensions()->toHash();
    $obj->{version} = $self->getVersion();
    $obj->{author} = $self->getAuthor();
    $obj->{timestamp} = $self->getTimestamp()->iso8601();
    $obj->{boundingBox} = ($self->getBoundingBox() == 1) ? 'true' : 'false';
    $obj->{items} = [];
    foreach my $item (@{$self->getItems()}) {
        my $ij = $item->toHash();
        push @{$obj->{items}}, $ij;
    }
    return $obj;
}
sub setName {
    my ($self, $name) = @_;
    unless (defined $name && $name =~ /^.+$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'name' is missing");
    }
    $self->{name} = $name;
}
sub getName { return shift->{name}; }
sub setSchema {
    my ($self, $schema) = @_;
    $self->{schema} = $schema;
}
sub getSchema { return shift->{schema}; }

=head2 setGrid

OPTIONAL. Old versions are missing this!
Set the grid size for the sheet.

=cut

sub setGrid {
    my ($self, $grid) = @_;
    if ($grid && $grid > 0) {
        unless ($grid =~ /^\d+\.?\d*$/) {
            Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'grid' is missing or is not a float");
        }
        $self->{grid} = $grid;
    }
    else {
        $self->{grid} = 0;
    }
}
sub getGrid { return shift->{grid}; }
sub getGridWidth { my ($self) = @_; return $self->{grid}; }
sub getGridHeight { my ($self) = @_; return $self->{grid}; }
sub setId {
    my ($self, $id) = @_;
    unless ($id =~ /^\d+$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'id' is missing or is not a digit");
    }
    $self->{id} = $id;
}
sub getId { return shift->{id}; }
sub setPosition {
    my ($self, $unused1, $unused2, $origo) = @_;

    my $dimensions = $self->getDimensions();
    $self->SUPER::setPosition({left => 0, top => $dimensions->{height}}, $unused2, $origo);
}
sub setVersion {
    my ($self, $version) = @_;
    unless ($version =~ /^\d+\.?\d*$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'version' is not a float");
    }
    $self->{version} = $version;
}
sub getVersion { return shift->{version}; }
sub setAuthor {
    my ($self, $author) = @_;
    unless (ref($author) eq 'HASH' && $author->{borrowernumber} =~ /^\d+$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'author' is missing 'borrowernumber'-property");
    }
    $self->{author} = $author;
}
sub getAuthor { return shift->{author}; }
sub setTimestamp {
    my ($self, $timestamp) = @_;
    eval {
        $timestamp = $timestamp . 'Z' unless $timestamp =~ /Z$/;
        my $dt = dt_from_string($timestamp, 'rfc3339');
        $self->{timestamp} = $dt;
    };
    if ($@) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'timestamp': $@");
    }
}
sub getTimestamp { return shift->{timestamp}; }
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
sub setItems {
    my ($self, $items) = @_;
    unless (ref($items) eq 'ARRAY') {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__.":: Parameter 'items' is not an array");
    }
    $self->{items} = [];
    foreach my $item (@$items) {
        push(@{$self->{items}}, Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Item->new($self, $item));
    }

    #Remove index gaps for smoothly iterating printable labels groups in the correct order.
    my @sorted = sort {$a->getIndex() <=> $b->getIndex()} @{$self->{items}};
    for (my $i=0 ; $i<@sorted ; $i++) {
        $sorted[$i]->setIndex($i+1);
    }
}
sub getItems { return shift->{items}; }

sub getRegionById {
    my ($self, $id) = @_;
    unless ($id =~ /^\d+$/) {
        Koha::Exceptions::BadParameter->throw(error => __PACKAGE__."->getRegionById($id) Parameter 'id' is missing or is not a digit");
    }
    foreach my $item (@{$self->getItems()}) {
        my $region = $item->getRegionById($id);
        if ($region) {
            return $region;
        }
    }
    return undef;
}
sub setOrigo {
    my ($self, $margins) = @_;
    $self->{origo} = [$margins->{left}, $margins->{top}];

    $self->setPosition(undef, undef, $self->getOrigo());

    foreach my $item (@{$self->{items}}) {
        foreach my $region (@{$item->{regions}}) {
            $region->setPosition($region->getPosition(), $self);

            foreach my $element (@{$region->{elements}}) {
                $element->setPosition($element->getPosition(), $region);
            }
        }
    }
}
sub getOrigo { return $_[0]->{origo}; }

return 1;
