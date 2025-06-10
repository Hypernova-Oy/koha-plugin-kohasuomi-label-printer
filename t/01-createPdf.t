#!/usr/bin/env perl

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

BEGIN {
  $ENV{KOHA_LOG_LEVEL} = 'TRACE';
  $ENV{LOG4PERL_VERBOSITY_CHANGE} = 6;
  $ENV{MOJO_OPENAPI_DEBUG} = 1;
  $ENV{MOJO_LOG_LEVEL} = 'debug';
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
}

use Modern::Perl;
use strict;
use warnings;
use utf8;
use version;

use JSON::XS;
use PDF::Reuse;

use Test::More tests => 3;
use Test::Deep;

use t::Lib;

use Koha::Plugin::Fi::KohaSuomi::LabelPrinter;
use Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade;

$Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator::log->level('TRACE');

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

my $testFile = '/tmp/test.pdf';

my $testBarcodes = [
  '26901',
  '26901',
];

subtest("Scenario: Upgrade plugin", sub {
  plan tests => 3;

  my $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install() and upgrade(), but those do nothing since there should be no upgrade as this is a new plugin.
  $plugin->store_data({'__INSTALLED_VERSION__' => '24.04.1'});
  my $installedVersion = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade::_getInstalledVersion($plugin);
  is($installedVersion, '0.0.1', "Plugin installed version is set from legacy versioning 24.04.1 to 0.0.1");
  Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade::upgrade($plugin, {});
  ok(version->parse(Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade::_getInstalledVersion($plugin))
     >= version->parse('0.0.4'),
     "Plugin installed version is set after upgrade");
  ok($Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Upgrade::upgradesDone{'0.0.4'}, "Upgrade 0.0.4 was done");
});

subtest("Scenario: Render the sheet #2.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  $barcodes = $testBarcodes;
  plan tests => 4;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  $margins = {
    top => 0,
    left => 0,
    right => 0,
    bottom => 0,
  };
  ok($margins, "Given margins");

  $sheet = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::SheetManager::getSheet(2);
  ok($sheet, "And a Sheet");

  ok($barcodes, "And some barcodes");

  subtest("When a PDF is created", sub {
    plan tests => 2;
    ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => $margins, sheet => $sheet, file => $testFile.'2'}), "A PDF creator is created");
    ok($filePath = $creator->create($barcodes), "A PDF is created");
  });
});

subtest("Scenario: Update a sheet.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  $barcodes = $testBarcodes;
  plan tests => 8;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  $sheet = t::Lib::mockSheet();
  ok($sheet, "Given a Sheet");

  my $sourceRegion = $sheet->getRegionById(43);
  ok($sourceRegion, "Which has a source region");
  is($sourceRegion->getCloneOfId(), 0, "Which has no cloneOfId");

  my $clonedRegion = $sheet->getRegionById(45);
  ok($clonedRegion, "Which has a cloned region");
  is($clonedRegion->getCloneOfId(), 43, "Which has a cloneOfId");

  ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => undef, sheet => $sheet, file => $testFile}), "A PDF creator is created");
  ok($filePath = $creator->create($barcodes), "A PDF is created");
  is($filePath, $testFile, "The PDF is created in the correct location");
});

subtest("Scenario: DataSourceFormatter.", sub {
  my ($plugin, $margins, $sheet, $barcodes, $creator, $filePath);
  $barcodes = $testBarcodes;
  plan tests => 6;

  $plugin = Koha::Plugin::Fi::KohaSuomi::LabelPrinter->new(); #This implicitly calls install()

  $sheet = t::Lib::mockSheet();
  ok($sheet, "Given a Sheet");

  ok($creator = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::PdfCreator->new({margins => undef, sheet => $sheet, file => $testFile}), "A PDF creator is created");
  ok($filePath = $creator->create($barcodes, 'no-end-pdf-creation'), "A PDF is created");
  is($filePath, $testFile, "The PDF is created in the correct location");

  subtest("DataSourceFormatter: oneLiner", sub {
    my ($element, $pdfPos, $lines, $fontSize, $font, $colour);
    plan tests => 6;

    ok($element = $sheet->getRegionById(43)->getElements()->[0], "Given an Element");
    ok(!%{$element->getCustomAttr()}, "With no custom attributes");

    ($pdfPos, $lines, $fontSize, $font, $colour) = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceFormatter::_formatLines(
      $element,
      $element->getDataSource(),
      "oneLiner",
    );
    ok(1, "When the lines are formatted");

    is($pdfPos->{x}, 15, "Then Position left");
    is($pdfPos->{y}, 398, "And Position top");
    is_deeply($lines, ['"TESTI1"'], "And Lines");
  });

  subtest("DataSourceFormatter: oneLiner center=1", sub {
    my ($element, $pdfPos, $lines, $fontSize, $font, $colour);
    plan tests => 6;

    ok($element = $sheet->getRegionById(43)->getElements()->[1], "Given an Element");
    ok($element->getCustomAttr->{center}, "With center custom attribute");
    ($pdfPos, $lines, $fontSize, $font, $colour) = Koha::Plugin::Fi::KohaSuomi::LabelPrinter::DataSourceFormatter::_formatLines(
      $element,
      $element->getDataSource(),
      "oneLiner",
    );
    ok(1, "When the lines are formatted");

    is($pdfPos->{x}, 19, "Then Position left");
    is($pdfPos->{y}, 398, "And Position top");
    is_deeply($lines, ['"TESTI2"'], "And Lines");
  });
});

$schema->storage->txn_rollback;

1;