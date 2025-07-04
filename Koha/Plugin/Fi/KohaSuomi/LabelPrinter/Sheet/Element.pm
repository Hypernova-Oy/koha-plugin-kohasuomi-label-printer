package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Element;
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

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Fonts;

use Koha::Exceptions;

use parent qw(Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasDimensions Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Mixin::HasPosition);

sub new {
    my ($class, $region, $params) = @_;

    my $self = {};
    bless($self, $class);
    $self->setId(         $params->{id});
    $self->setParent(     $region);
    $self->setDimensions( $params->{dimensions});
    $self->setPosition(   $params->{position}, $region);
    $self->setBoundingBox($params->{boundingBox});
    $self->setDataSource( $params->{dataSource});
    $self->setDataFormat( $params->{dataFormat});
    $self->setFontSize(   $params->{fontSize});
    $self->setFont(       $params->{font});
    $self->setColour(     $params->{colour});
    $self->setCustomAttr( $params->{customAttr});
    return $self;
}
sub toHash {
    my ($self) = @_;
    my $obj = {};
    $obj->{dimensions} =  $self->getDimensions()->toHash();
    $obj->{position} =    $self->getPosition()->toHash();
    $obj->{boundingBox} = ($self->getBoundingBox() == 1) ? 'true' : 'false';
    $obj->{dataSource} =  $self->getDataSource();
    $obj->{dataFormat} =  $self->getDataFormat();
    $obj->{fontSize} =    $self->getFontSize();
    $obj->{font} =        $self->getFont()->{type};
    $obj->{colour} =      $self->getColour();
    $obj->{customAttr} =  $self->flattenCustomAttr();
    return $obj;
}
sub setId {
    my ($self, $id) = @_;
    if ($id && not($id =~ /^\d+$/)) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($id) Parameter 'id' must be a positive number, or undefined");
    }
    $self->{id} = $id;
}
sub getId { return shift->{id}; }
sub setBoundingBox {
    my ($self, $boundingBox) = @_;
    unless ($boundingBox =~ /^(1|0|true|false)$/) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($boundingBox) Parameter 'boundingBox' is not 'true|1' or 'false|0' ".$self->_exceptionId());
    }
    if ($boundingBox =~ /(1|true)/) {
        $self->{boundingBox} = 1;
    }
    else {
        $self->{boundingBox} = 0;
    }
}
sub getBoundingBox { return shift->{boundingBox}; }
sub setDataSource {
    my ($self, $dataSource) = @_;
    unless ($dataSource =~ /^.+$/) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."() Parameter 'dataSource' is missing ".$self->_exceptionId());
    }
    $dataSource =~ s/^\s+//; #Remove whitespace
    $dataSource =~ s/\s+$//;
    $self->{dataSource} = $dataSource;

    #Validate the DataSource for correctness
    #If my dataSource is a function, make sure that such a function is defined!
    if (my $fn = $self->getFunctionName()) {
        unless (Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager::hasDataSourceFunction($fn)) {
            my @cc = caller(0);
            Koha::Exceptions::BadParameter->throw(error => $cc[3]."($dataSource) Parameter 'dataSource' is a function but such a function is not defined in the DataSource.pm ".$self->_exceptionId());
        }
    }
    elsif (my $isDbSelector = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceSelector::isSelectorValid($dataSource)) {
        #all is ok, for now...
    }
    else {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($dataSource) Parameter 'dataSource' is not a valid selector sentence ".$self->_exceptionId());
    }
}
sub getDataSource { return shift->{dataSource}; }
sub setDataFormat {
    my ($self, $dataFormat) = @_;
    unless ($dataFormat =~ /^.+$/) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."() Parameter 'dataFormat' is missing ".$self->_exceptionId());
    }
    $dataFormat =~ s/^\s+//; #Remove whitespace
    $dataFormat =~ s/\s+$//;
    $self->{dataFormat} = $dataFormat;

    unless (Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager::hasDataFormatFunction($dataFormat)) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($dataFormat) Parameter 'dataFormat' is a function but such a function is not defined in the DataSourceFormat.pm ".$self->_exceptionId());
    }
}
sub getDataFormat { return shift->{dataFormat}; }
sub getFunctionName {
    my ($self) = @_;
    if ($self->getDataSource() =~ /^(.+?)\(.*?\)$/) {
        return $1;
    }
    return undef;
}
sub isFunction {
    my ($self) = @_;
    if ($self->getFunctionName()) {
        return 1;
    }
    return undef;
}
sub setFontSize {
    my ($self, $fontSize) = @_;
    unless ($fontSize =~ /^\d+$/) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($fontSize) Parameter 'fontSize' is missing, or is not a number ".$self->_exceptionId());
    }
    $self->{fontSize} = $fontSize;
}
sub getFontSize { return shift->{fontSize}; }
sub setFont {
    my ($self, $font) = @_;
    unless ($font) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."() Parameter 'font' is missing ".$self->_exceptionId());
    }

    $self->{font} = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Fonts::getFont($font);
}
sub getFont { return shift->{font}; }
sub setColour {
    my ($self, $colour) = @_;
    unless (ref($colour) eq 'HASH') {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."() Parameter 'colour' is missing, or is not an object/hash ".$self->_exceptionId());
    }
    unless ($colour->{r} =~ /^\d+$/ && $colour->{g} =~ /^\d+$/ && $colour->{b} =~ /^\d+$/) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."() Parameter 'colour' has a bad 'r', 'g' and/or 'b' -attribute ".$self->_exceptionId());
    }
    $self->{colour} = $colour;
}
sub getColour { return shift->{colour}; }
sub setParent {
    my ($self, $region) = @_;
    unless (blessed($region) && $region->isa('Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region')) {
        my @cc = caller(0);
        Koha::Exceptions::BadParameter->throw(error => $cc[3]."($region) Parameter 'parent' is not a Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Sheet::Region-object ".$self->_exceptionId());
    }
    $self->{parent} = $region;
}
sub getParent { return shift->{parent}; }
sub getSheet {
    my ($self) = @_;
    return $self->getParent()->getParent()->getParent();
}
sub getItem {
    my ($self) = @_;
    return $self->getParent()->getParent();
}
sub getRegion {
    my ($self) = @_;
    return $self->getParent();
}
sub setCustomAttr {
    my ($self, $attr) = @_;

    my %attr;
    $self->{customAttr} = \%attr;

    return if(not($attr) || $attr =~ /^\s+$/);

    my @attr = split(/[,]/, $attr);
    if (@attr) {

        foreach my $a (@attr) {
            if ($a =~ /(\S+?)\s*=\s*(\S+)/) {
                $attr{$1} = $2;
            }
            else {
                my @cc = caller(0);
                Koha::Exceptions::BadParameter->throw(error => $cc[3]."($attr) Attribute '$a' doesn't look like 'key=value'".$self->_exceptionId());
            }
        }
        $self->{customAttr} = \%attr;
    }
}
sub flattenCustomAttr {
    my ($self) = @_;
    my $ca = $self->getCustomAttr();

    my @sb;
    while (my ($key, $value) = each(%$ca)) {
        push(@sb, "$key=$value");
    }
    return join(',', @sb);
}
sub getCustomAttr {
    return shift->{customAttr};
}

sub _exceptionId {
    my ($self) = @_;
    return '[element'.$self->getId().']';
}
return 1;
