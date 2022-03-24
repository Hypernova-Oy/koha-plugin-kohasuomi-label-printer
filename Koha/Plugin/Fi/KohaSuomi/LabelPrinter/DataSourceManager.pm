package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceManager;
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
use Class::Inspector;
use Scalar::Util qw(blessed);

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSource;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceSelector;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceFormatter;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator;
use C4::Items;
use C4::Biblio;
use Koha::Libraries;

=head SYNOPSIS

This class is a front-end for querying DataSources capabilities

=cut

=head getAvailableDataSourceFunctions

@RETURNS ARRAYRef of data source function names

=cut

sub getAvailableDataSourceFunctions {
    return _introspectDataSourceProcessingFunctions() || [];
}

sub hasDataSourceFunction {
    my ($functionName) = @_;

    my $fullName = _getFullDataSourceFunctionName($functionName);
    if (exists &{$fullName}) {
        return 1;
    }
}

sub getAvailableDataFormatFunctions {
    return _introspectDataFormatFunctions() || [];
}

sub hasDataFormatFunction {
    my ($functionName) = @_;

    my $fullName = _getFullDataFormatFunctionName($functionName);
    if (exists &{$fullName}) {
        return 1;
    }
}

sub _getFullDataSourceFunctionName {
    my ($functionName) = @_;
    return "Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSource::public_$functionName";
}

sub _getFullDataFormatFunctionName {
    my ($functionName) = @_;
    return "Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceFormatter::public_$functionName";
}

sub executeDataSource {
    my ($element, $itemId) = @_;

    my $params = _getDataSourceParams($element, $itemId);

    if ($element->isFunction()) {
        return _executeDataSourceFunction($element, $params);
    }
    else {
        return _executeDataSourceSelector($element, $params);
    }
}

sub executeDataFormat {
    my ($element, $text) = @_;
    if ($text) {
        my $funcName = _getFullDataFormatFunctionName($element->getDataFormat());
        no strict 'refs';
        my $s = \&{$funcName};
        return $s->( {text => $text}, $element );
    }
}

sub _executeDataSourceFunction {
    my ($element, $params) = @_;

    my $funcName = _getFullDataSourceFunctionName($element->getFunctionName());
    no strict 'refs';
    my $s = \&{$funcName};
    return $s->( $params );
}

sub _executeDataSourceSelector {
    my ($element, $params) = @_;

    return Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceSelector::select($element->getDataSource(), $params);
}

sub _getDataSourceParams {
    my ($element, $itemId) = @_;
    my $dbData = _getDatabaseData($itemId);
    my $record = C4::Biblio::GetMarcBiblio({ biblionumber => $dbData->{item}->{biblionumber} });
    my $dsParams = _getDataSourceSubroutineParams($element);
    return [
        $dbData,
        $record,
        $element,
        $dsParams,
    ];
}
sub _getDatabaseData {
    my ($item) = @_;

    if (blessed($item) && $item->isa('Koha::Item')) {
        $item = $item = C4::Items::GetItem(undef,$item->barcode,undef);
    }
    elsif (not(ref $item eq 'HASH')) {
        $item = Koha::Items->find({ barcode => $item });
        $item = $item->unblessed if $item;
    }
    my $biblio = Koha::Biblios->find($item->{biblionumber});
    my $biblioitem = $biblio->biblioitem->unblessed if $biblio;
    $biblio = $biblio->unblessed if $biblio;
    my $homebranch = Koha::Libraries->find($item->{homebranch})->unblessed;
    return {
        biblio     => $biblio,
        biblioitem => $biblioitem,
        item       => $item,
        homebranch => $homebranch,
    };
}

sub _getDataSourceSubroutineParams {
    my ($element) = @_;

    my $ds = $element->getDataSource();
    if ($ds =~ /\((.+?)\)/) {
        my $paramString = $1;
        my @params = split(/(\s+|,)/, $paramString);
        return \@params;
    }
    return [];
}

=head _introspectDataSourceProcessingFunctions

    my $subroutines = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSource::_introspectDataSourceProcessingFunctions();

Get the dataSource processing subroutines DataSources-package provides.
@RETURNS ARRAYRef of subroutine names.
=cut

sub _introspectDataSourceProcessingFunctions {
    my $funcs = Class::Inspector->functions("Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSource");
    my @funcs;
    foreach my $func (@$funcs) {
        if ($func =~ s/^public_//) { #Remove "unintended" subroutines
            push(@funcs, $func);
        }
    }
    return \@funcs;
}

=head _introspectDataFormatFunctions

    my $subroutines = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSource::_introspectDataFormatFunctions();

Get the dataSource formatting subroutines DataSourceFormatter-package provides.
@RETURNS ARRAYRef of subroutine names.
=cut

sub _introspectDataFormatFunctions {
    my $funcs = Class::Inspector->functions("Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceFormatter");
    my @funcs;
    foreach my $func (@$funcs) {
        if ($func =~ s/^public_//) { #Remove "unintended" subroutines
            push(@funcs, $func);
        }
    }
    return \@funcs;
}

1;
